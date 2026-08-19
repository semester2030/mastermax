import { Inject, Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { hostname } from 'os';
import { PgService } from '../shared/database/pg.service';
import {
  CLOUDFLARE_MEDIA_PORT,
  CloudflareMediaPort,
} from '../modules/media/domain/cloudflare-media.port';
import { newId } from '../shared/ids/ids';
import { shouldAutoStartWorkers } from './worker-runtime';
import { writeHeartbeat } from './worker-heartbeat';

const MAX_ATTEMPTS = 8;
const STALE_CLAIM_SECONDS = 90;

type OutboxRow = {
  id: string;
  kind: string;
  cloudflare_image_id: string | null;
  stream_uid: string | null;
  attempts: number;
  claim_token: string;
};

/**
 * Crash-safe Cloudflare Images/Stream delete worker.
 * Claims with FOR UPDATE SKIP LOCKED + claim_token; idempotent CF delete (404 = success).
 */
@Injectable()
export class MediaCfDeleteWorker implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(MediaCfDeleteWorker.name);
  private timer?: NodeJS.Timeout;
  /** Identity for ops logs (claim uses UUID claim_token). */
  private readonly workerId = `${hostname()}:${process.pid}:${newId().slice(0, 8)}`;


  constructor(
    private readonly pg: PgService,
    @Inject(CLOUDFLARE_MEDIA_PORT) private readonly cf: CloudflareMediaPort,
  ) {}

  onModuleInit(): void {
    if (!shouldAutoStartWorkers()) {
      return;
    }
    void writeHeartbeat(this.pg, 'media_cf_delete', this.workerId, null);
    this.timer = setInterval(() => {
      this.tick().catch((err) => this.logger.error(String(err)));
    }, 2500);
  }

  onModuleDestroy(): void {
    if (this.timer) {
      clearInterval(this.timer);
    }
  }

  /** Clear stale claims after worker crash. */
  async reapStale(staleSeconds = STALE_CLAIM_SECONDS): Promise<number> {
    const r = await this.pg.query(
      `UPDATE media_cf_delete_outbox
       SET claim_token = NULL, claimed_at = NULL
       WHERE status = 'pending'
         AND claim_token IS NOT NULL
         AND claimed_at < now() - ($1 || ' seconds')::interval`,
      [String(staleSeconds)],
    );
    return r.rowCount ?? 0;
  }

  async tick(limit = 20): Promise<{ claimed: string[]; done: string[]; failed: string[] }> {
    try {
      const r = await this.tickInner(limit);
      await writeHeartbeat(this.pg, 'media_cf_delete', this.workerId, null);
      return r;
    } catch (err) {
      await writeHeartbeat(this.pg, 'media_cf_delete', this.workerId, String(err));
      throw err;
    }
  }

  private async tickInner(
    limit = 20,
  ): Promise<{ claimed: string[]; done: string[]; failed: string[] }> {
    await this.reapStale();
    const claimed = await this.claimBatch(limit);
    const done: string[] = [];
    const failed: string[] = [];
    for (const row of claimed) {
      try {
        // Never delete a CF asset still referenced by non-deleted completed media.
        let stillLive = false;
        if (row.kind === 'video' && row.stream_uid) {
          const live = await this.pg.query(
            `SELECT 1 FROM venue_media
             WHERE stream_uid = $1 AND deleted_at IS NULL LIMIT 1`,
            [row.stream_uid],
          );
          stillLive = !!live.rowCount;
        } else if (row.cloudflare_image_id) {
          const live = await this.pg.query(
            `SELECT 1 FROM venue_media
             WHERE cloudflare_image_id = $1 AND deleted_at IS NULL LIMIT 1`,
            [row.cloudflare_image_id],
          );
          stillLive = !!live.rowCount;
        }
        if (stillLive) {
          await this.markDone(row.id, row.claim_token);
          done.push(row.id);
          this.logger.warn({
            workerId: this.workerId,
            id: row.id,
            skipped: 'live_cf_asset_still_referenced',
          });
          continue;
        }
        if (row.kind === 'video' && row.stream_uid) {
          await this.cf.deleteStream(row.stream_uid);
        } else if (row.cloudflare_image_id) {
          await this.cf.deleteImage(row.cloudflare_image_id);
        }
        await this.markDone(row.id, row.claim_token);
        done.push(row.id);
      } catch (err) {
        await this.markRetryOrFail(row, String(err));
        failed.push(row.id);
        this.logger.warn({
          workerId: this.workerId,
          id: row.id,
          err: String(err),
          attempts: row.attempts,
        });
      }
    }
    return { claimed: claimed.map((r) => r.id), done, failed };
  }

  async claimBatch(limit = 20): Promise<OutboxRow[]> {
    return this.pg.tx(async (c) => {
      const rows = await c.query<{
        id: string;
        kind: string;
        cloudflare_image_id: string | null;
        stream_uid: string | null;
        attempts: number;
      }>(
        `SELECT id, kind, cloudflare_image_id, stream_uid, attempts
         FROM media_cf_delete_outbox
         WHERE status = 'pending'
           AND claim_token IS NULL
           AND (next_attempt_at IS NULL OR next_attempt_at <= now())
         ORDER BY created_at ASC
         FOR UPDATE SKIP LOCKED
         LIMIT $1`,
        [limit],
      );
      const claimed: OutboxRow[] = [];
      for (const row of rows.rows) {
        const token = newId();
        const upd = await c.query(
          `UPDATE media_cf_delete_outbox
           SET claim_token = $2::uuid,
               claimed_at = now(),
               attempts = attempts + 1
           WHERE id = $1 AND status = 'pending' AND claim_token IS NULL`,
          [row.id, token],
        );
        if (upd.rowCount) {
          claimed.push({
            ...row,
            attempts: row.attempts + 1,
            claim_token: token,
          });
        }
      }
      return claimed;
    });
  }

  async markDone(id: string, claimToken: string): Promise<void> {
    await this.pg.query(
      `UPDATE media_cf_delete_outbox
       SET status = 'done',
           processed_at = now(),
           claim_token = NULL,
           claimed_at = NULL,
           last_error = NULL
       WHERE id = $1 AND claim_token = $2::uuid`,
      [id, claimToken],
    );
  }

  async markRetryOrFail(row: OutboxRow, error: string): Promise<void> {
    if (row.attempts >= MAX_ATTEMPTS) {
      await this.pg.query(
        `UPDATE media_cf_delete_outbox
         SET status = 'failed',
             last_error = $3,
             claim_token = NULL,
             claimed_at = NULL,
             processed_at = now(),
             alerted_at = COALESCE(alerted_at, now())
         WHERE id = $1 AND claim_token = $2::uuid`,
        [row.id, row.claim_token, error.slice(0, 500)],
      );
      this.logger.error({
        msg: 'media_cf_delete_exhausted',
        id: row.id,
        attempts: row.attempts,
        err: error.slice(0, 200),
      });
      return;
    }
    // Exponential backoff: 2^attempts seconds (capped).
    const delaySec = Math.min(300, Math.pow(2, Math.min(row.attempts, 8)));
    await this.pg.query(
      `UPDATE media_cf_delete_outbox
       SET status = 'pending',
           last_error = $3,
           claim_token = NULL,
           claimed_at = NULL,
           next_attempt_at = now() + ($4 || ' seconds')::interval
       WHERE id = $1 AND claim_token = $2::uuid`,
      [row.id, row.claim_token, error.slice(0, 500), String(delaySec)],
    );
  }
}
