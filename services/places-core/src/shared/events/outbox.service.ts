import { Injectable } from '@nestjs/common';
import { PoolClient } from 'pg';
import { newId } from '../ids/ids';
import { PgService } from '../database/pg.service';

@Injectable()
export class OutboxService {
  constructor(private readonly pg: PgService) {}

  async enqueue(
    name: string,
    payload: Record<string, unknown>,
    client?: PoolClient,
  ): Promise<void> {
    const sql = `INSERT INTO domain_events (id, name, payload_json, status, attempts)
       VALUES ($1, $2, $3::jsonb, 'pending', 0)`;
    const params = [newId(), name, JSON.stringify(payload)];
    if (client) {
      await client.query(sql, params);
      return;
    }
    await this.pg.query(sql, params);
  }
}
