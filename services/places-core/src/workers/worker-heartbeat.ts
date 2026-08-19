import { hostname } from 'os';
import { PgService } from '../shared/database/pg.service';
import { newId } from '../shared/ids/ids';

/** Stable per-process worker instance id for heartbeat rows. */
export function newWorkerInstanceId(): string {
  return `${hostname()}:${process.pid}:${newId().slice(0, 8)}`;
}

/**
 * Upsert a per-worker heartbeat (Phase 6 RC2). Each worker records last_tick_at
 * on every cycle; a null lastError clears a prior error, a non-null value marks
 * the worker unhealthy so /healthz/workers fails closed.
 */
export async function writeHeartbeat(
  pg: PgService,
  workerName: string,
  instanceId: string,
  lastError: string | null,
): Promise<void> {
  await pg.query(
    `INSERT INTO worker_heartbeats (worker_name, instance_id, last_tick_at, last_error)
     VALUES ($1, $2, now(), $3)
     ON CONFLICT (worker_name, instance_id) DO UPDATE
       SET last_tick_at = now(), last_error = EXCLUDED.last_error`,
    [workerName, instanceId, lastError],
  );
}
