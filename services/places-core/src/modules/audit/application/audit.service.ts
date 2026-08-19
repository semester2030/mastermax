import { Injectable } from '@nestjs/common';
import { PoolClient } from 'pg';
import { PgService } from '../../../shared/database/pg.service';
import { newId } from '../../../shared/ids/ids';

export interface AuditWrite {
  actorUid: string;
  actorRole: string;
  entityType: string;
  entityId: string;
  before?: unknown;
  after?: unknown;
  reason?: string;
  correlationId: string;
}

@Injectable()
export class AuditService {
  constructor(private readonly pg: PgService) {}

  async write(entry: AuditWrite, client?: PoolClient): Promise<void> {
    const sql = `INSERT INTO audit_logs
        (id, actor_uid, actor_role, entity_type, entity_id, before_json, after_json, reason, correlation_id)
       VALUES ($1,$2,$3,$4,$5,$6::jsonb,$7::jsonb,$8,$9)`;
    const params = [
      newId(),
      entry.actorUid,
      entry.actorRole,
      entry.entityType,
      entry.entityId,
      JSON.stringify(entry.before ?? null),
      JSON.stringify(entry.after ?? null),
      entry.reason ?? null,
      entry.correlationId,
    ];
    if (client) {
      await client.query(sql, params);
      return;
    }
    await this.pg.query(sql, params);
  }
}
