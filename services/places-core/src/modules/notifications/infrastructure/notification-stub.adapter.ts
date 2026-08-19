import { Injectable, Logger } from '@nestjs/common';
import { PgService } from '../../../shared/database/pg.service';
import { newId } from '../../../shared/ids/ids';
import { NotificationPort } from '../application/notification.port';

/** Documented stub. Real adapter later reads users/{uid}/fcm_registration/primary. */
@Injectable()
export class NotificationStubAdapter implements NotificationPort {
  private readonly logger = new Logger(NotificationStubAdapter.name);

  constructor(private readonly pg: PgService) {}

  /**
   * Idempotent by domain event id (F-REV4-18): payload.eventId is the outbox row id.
   * Concurrent / reclaim retries insert at most one notifications row per event.
   */
  async handle(eventName: string, payload: Record<string, unknown>): Promise<void> {
    try {
      const eventId =
        typeof payload.eventId === 'string' && payload.eventId.length > 0
          ? payload.eventId
          : null;
      const target = String(payload.uid ?? payload.consumerUid ?? '');
      const body = JSON.stringify(payload);
      if (eventId) {
        await this.pg.query(
          `INSERT INTO notifications (id, event_name, channel, target_uid, payload_json, status, source_event_id)
           VALUES ($1,$2,'stub',$3,$4::jsonb,'stubbed',$5::uuid)
           ON CONFLICT (source_event_id) WHERE (source_event_id IS NOT NULL) DO NOTHING`,
          [newId(), eventName, target, body, eventId],
        );
        return;
      }
      await this.pg.query(
        `INSERT INTO notifications (id, event_name, channel, target_uid, payload_json, status, source_event_id)
         VALUES ($1,$2,'stub',$3,$4::jsonb,'stubbed',NULL)`,
        [newId(), eventName, target, body],
      );
    } catch (err) {
      this.logger.warn({ eventName, err: String(err) }, 'notification stub failed; booking continues');
    }
  }
}
