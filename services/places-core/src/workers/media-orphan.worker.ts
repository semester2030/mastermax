import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { hostname } from 'os';
import { PgService } from '../shared/database/pg.service';
import { ProviderOpsService } from '../modules/venues/application/provider-ops.service';
import { newId } from '../shared/ids/ids';
import { shouldAutoStartWorkers } from './worker-runtime';
import { MEDIA_LIMITS } from '../modules/media/domain/media-contract';

/**
 * Scheduled orphan upload cleanup + rejected-media retention sweep (Phase 6).
 */
@Injectable()
export class MediaOrphanWorker implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(MediaOrphanWorker.name);
  private timer?: NodeJS.Timeout;
  private readonly instanceId = `${hostname()}:${process.pid}:${newId().slice(0, 8)}`;

  constructor(
    private readonly pg: PgService,
    private readonly ops: ProviderOpsService,
  ) {}

  onModuleInit(): void {
    if (!shouldAutoStartWorkers()) {
      return;
    }
    void this.heartbeat(null);
    this.timer = setInterval(() => {
      this.tick().catch((err) => this.logger.error(String(err)));
    }, 60_000);
  }

  onModuleDestroy(): void {
    if (this.timer) clearInterval(this.timer);
  }

  async tick(): Promise<{ orphans: number; rejectedSoftDeleted: number }> {
    let orphans = 0;
    let rejectedSoftDeleted = 0;
    try {
      const r = await this.ops.cleanupOrphanUploads(null, 50);
      orphans = r.cleaned ?? 0;
      rejectedSoftDeleted = await this.sweepRejectedRetention();
      await this.heartbeat(null);
    } catch (err) {
      await this.heartbeat(String(err));
      throw err;
    }
    return { orphans, rejectedSoftDeleted };
  }

  /** Soft-delete rejected media past retention; CF delete via outbox path (one TX). */
  async sweepRejectedRetention(): Promise<number> {
    const days = MEDIA_LIMITS.rejectedRetentionDays;
    return this.pg.tx(async (c) => {
      const rows = await c.query<{
        id: string;
        kind: string;
        cloudflare_image_id: string | null;
        stream_uid: string | null;
      }>(
        `UPDATE venue_media
         SET deleted_at = now(), updated_at = now()
         WHERE moderation_status = 'rejected'
           AND deleted_at IS NULL
           AND updated_at < now() - ($1 || ' days')::interval
         RETURNING id, kind, cloudflare_image_id, stream_uid`,
        [String(days)],
      );
      for (const row of rows.rows) {
        if (row.cloudflare_image_id || row.stream_uid) {
          await c.query(
            `INSERT INTO media_cf_delete_outbox
               (id, kind, cloudflare_image_id, stream_uid, venue_media_id, status, next_attempt_at)
             VALUES ($1,$2,$3,$4,$5,'pending',now())`,
            [
              newId(),
              row.kind === 'video' ? 'video' : 'image',
              row.cloudflare_image_id,
              row.stream_uid,
              row.id,
            ],
          );
        }
      }
      return rows.rowCount ?? 0;
    });
  }

  async heartbeat(lastError: string | null): Promise<void> {
    await this.pg.query(
      `INSERT INTO worker_heartbeats (worker_name, instance_id, last_tick_at, last_error)
       VALUES ('media_orphan', $1, now(), $2)
       ON CONFLICT (worker_name, instance_id) DO UPDATE
         SET last_tick_at = now(), last_error = EXCLUDED.last_error`,
      [this.instanceId, lastError],
    );
  }
}
