import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { hostname } from 'os';
import { PgService } from '../shared/database/pg.service';
import { Inject } from '@nestjs/common';
import { NOTIFICATION_PORT, NotificationPort } from '../modules/notifications/application/notification.port';
import { newId } from '../shared/ids/ids';
import { shouldAutoStartWorkers } from './worker-runtime';
import { writeHeartbeat } from './worker-heartbeat';

/** Only reclaim processing rows whose claim is older than this (crash safety). */
const STALE_CLAIM_SECONDS = 5 * 60;
const MAX_ATTEMPTS = 5;

type ClaimedEvent = {
  id: string;
  name: string;
  payload_json: Record<string, unknown>;
  attempts: number;
  claim_token: string;
};

/**
 * At-least-once outbox delivery with claim_token + FOR UPDATE SKIP LOCKED.
 * Reclaim only when claimed_at is older than STALE_CLAIM_SECONDS while still processing.
 * markSent / retry require matching claim_token so a reclaimed peer cannot race-complete.
 * Consumers must be idempotent by eventId (payload.eventId === domain_events.id).
 */
@Injectable()
export class OutboxWorker implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(OutboxWorker.name);
  private timer?: NodeJS.Timeout;
  private readonly workerId = `${hostname()}:${process.pid}:${newId().slice(0, 8)}`;

  constructor(
    private readonly pg: PgService,
    @Inject(NOTIFICATION_PORT) private readonly notifications: NotificationPort,
  ) {}

  onModuleInit(): void {
    if (!shouldAutoStartWorkers()) {
      return;
    }
    void writeHeartbeat(this.pg, 'outbox', this.workerId, null);
    this.timer = setInterval(() => {
      this.tick().catch((err) => this.logger.error(String(err)));
    }, 2000);
  }

  onModuleDestroy(): void {
    if (this.timer) {
      clearInterval(this.timer);
    }
  }

  /**
   * Reap stale processing locks (worker crash).
   * Only rows still `processing` with claimed_at older than staleSeconds.
   */
  async reapStale(staleSeconds = STALE_CLAIM_SECONDS): Promise<number> {
    const r = await this.pg.query(
      `UPDATE domain_events
       SET status = 'pending',
           claim_token = NULL,
           claimed_at = NULL,
           locked_at = NULL,
           locked_by = NULL
       WHERE status = 'processing'
         AND claim_token IS NOT NULL
         AND claimed_at < now() - ($1 || ' seconds')::interval`,
      [String(staleSeconds)],
    );
    return r.rowCount ?? 0;
  }

  /** Extend lease while actively handling (prevents reclaim mid-handler). */
  async heartbeat(id: string, claimToken: string): Promise<boolean> {
    const r = await this.pg.query(
      `UPDATE domain_events
       SET claimed_at = now(), locked_at = now()
       WHERE id = $1 AND claim_token = $2::uuid AND status = 'processing'`,
      [id, claimToken],
    );
    return (r.rowCount ?? 0) === 1;
  }

  async tick(limit = 20): Promise<{ claimed: string[] }> {
    try {
      await this.reapStale();
      const claimed = await this.claimBatch(limit);
      const claimedIds: string[] = [];
      for (const row of claimed) {
        claimedIds.push(row.id);
        try {
          const stillMine = await this.heartbeat(row.id, row.claim_token);
          if (!stillMine) {
            this.logger.warn({ id: row.id, workerId: this.workerId }, 'lost claim before notify');
            continue;
          }
          const payload = { ...row.payload_json, eventId: row.id };
          await this.notifications.handle(row.name, payload);
          await this.markSent(row.id, row.claim_token);
        } catch (err) {
          await this.markRetryOrFail(row);
          this.logger.warn({ id: row.id, err: String(err), attempts: row.attempts });
        }
      }
      await writeHeartbeat(this.pg, 'outbox', this.workerId, null);
      return { claimed: claimedIds };
    } catch (err) {
      await writeHeartbeat(this.pg, 'outbox', this.workerId, String(err));
      throw err;
    }
  }

  async claimBatch(limit = 20): Promise<ClaimedEvent[]> {
    return this.pg.tx(async (c) => {
      const rows = await c.query<{
        id: string;
        name: string;
        payload_json: Record<string, unknown>;
        attempts: number;
      }>(
        `SELECT id, name, payload_json, attempts FROM domain_events
         WHERE status = 'pending'
           AND claim_token IS NULL
         ORDER BY created_at ASC
         FOR UPDATE SKIP LOCKED
         LIMIT $1`,
        [limit],
      );
      const claimed: ClaimedEvent[] = [];
      for (const row of rows.rows) {
        const token = newId();
        const upd = await c.query(
          `UPDATE domain_events
           SET status = 'processing',
               claim_token = $2::uuid,
               claimed_at = now(),
               locked_at = now(),
               locked_by = $3,
               attempts = attempts + 1
           WHERE id = $1 AND status = 'pending' AND claim_token IS NULL`,
          [row.id, token, this.workerId],
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

  async markSent(id: string, claimToken: string): Promise<boolean> {
    const r = await this.pg.query(
      `UPDATE domain_events
       SET status = 'sent',
           claim_token = NULL,
           claimed_at = NULL,
           locked_at = NULL,
           locked_by = NULL
       WHERE id = $1 AND claim_token = $2::uuid AND status = 'processing'`,
      [id, claimToken],
    );
    return (r.rowCount ?? 0) === 1;
  }

  async markRetryOrFail(row: ClaimedEvent): Promise<void> {
    const status = row.attempts >= MAX_ATTEMPTS ? 'failed' : 'pending';
    await this.pg.query(
      `UPDATE domain_events
       SET status = $3,
           claim_token = NULL,
           claimed_at = NULL,
           locked_at = NULL,
           locked_by = NULL
       WHERE id = $1 AND claim_token = $2::uuid AND status = 'processing'`,
      [row.id, row.claim_token, status],
    );
  }
}
