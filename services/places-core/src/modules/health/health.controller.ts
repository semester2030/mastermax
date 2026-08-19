import { Controller, Get, Query, Res } from '@nestjs/common';
import { Response } from 'express';
import { Public } from '../../shared/auth/auth.decorators';
import { PgService } from '../../shared/database/pg.service';
import { metrics } from '../../shared/observability/metrics';
import { placesRunMode } from '../../workers/worker-runtime';
import { CANONICAL_WORKERS } from '../../workers/canonical-workers';

/** A heartbeat older than this (ms) is considered stale (workers tick every 30s). */
const WORKER_HEARTBEAT_STALE_MS = 90_000;

@Controller()
export class HealthController {
  constructor(private readonly pg: PgService) {}

  @Public()
  @Get('healthz')
  live() {
    return { status: 'ok', runMode: placesRunMode() };
  }

  @Public()
  @Get('readyz')
  async ready() {
    await this.pg.ping();
    const mig = await this.pg.query<{ c: string }>(
      `SELECT count(*)::text AS c FROM schema_migrations`,
    );
    if (Number(mig.rows[0].c) < 1) {
      return { status: 'not_ready', reason: 'migrations_missing' };
    }
    return {
      status: 'ready',
      migrations: Number(mig.rows[0].c),
      runMode: placesRunMode(),
    };
  }

  /**
   * Worker lease/health — used by independent worker process probes (Phase 6 RC2).
   * FAILS CLOSED (HTTP 503) when any known worker heartbeat is stale or carries a
   * last_error, or when there is an un-cleared failed-CF-delete alert.
   */
  @Public()
  @Get('healthz/workers')
  async workers(@Res({ passthrough: true }) res: Response) {
    const now = Date.now();
    let rows: Array<{
      worker_name: string;
      instance_id: string;
      last_tick_at: Date;
      last_error: string | null;
    }> = [];
    try {
      const hb = await this.pg.query<{
        worker_name: string;
        instance_id: string;
        last_tick_at: Date;
        last_error: string | null;
      }>(
        `SELECT worker_name, instance_id, last_tick_at, last_error
         FROM worker_heartbeats
         ORDER BY last_tick_at DESC
         LIMIT 50`,
      );
      rows = hb.rows;
    } catch (err) {
      res.status(503);
      return {
        status: 'degraded',
        reason: 'db_error',
        runMode: placesRunMode(),
        heartbeats: [],
        failedDeletesAlerted: 0,
        error: String(err).slice(0, 200),
      };
    }
    // Restart-safe: only the newest instance per worker_name is evaluated so a
    // replaced process does not poison health with its predecessor's stale row.
    const latestByName = new Map<string, (typeof rows)[number]>();
    for (const r of rows) {
      const prev = latestByName.get(r.worker_name);
      if (!prev || new Date(r.last_tick_at).getTime() > new Date(prev.last_tick_at).getTime()) {
        latestByName.set(r.worker_name, r);
      }
    }
    const missing = CANONICAL_WORKERS.filter((name) => !latestByName.has(name));
    if (latestByName.size === 0) {
      res.status(503);
      return {
        status: 'degraded',
        reason: 'no_heartbeat',
        missingWorkers: [...CANONICAL_WORKERS],
        runMode: placesRunMode(),
        heartbeats: [],
        failedDeletesAlerted: 0,
      };
    }
    if (missing.length > 0) {
      res.status(503);
      return {
        status: 'degraded',
        reason: 'missing_worker',
        missingWorkers: missing,
        runMode: placesRunMode(),
        heartbeats: CANONICAL_WORKERS.map((name) => {
          const r = latestByName.get(name);
          if (!r) {
            return {
              workerName: name,
              instanceId: null,
              lastTickAt: null,
              lastError: null,
              ageMs: null,
              stale: true,
              healthy: false,
              missing: true,
            };
          }
          const ageMs = now - new Date(r.last_tick_at).getTime();
          const stale = ageMs > WORKER_HEARTBEAT_STALE_MS;
          return {
            workerName: name,
            instanceId: r.instance_id,
            lastTickAt: r.last_tick_at,
            lastError: r.last_error,
            ageMs,
            stale,
            healthy: !stale && !r.last_error,
            missing: false,
          };
        }),
        failedDeletesAlerted: 0,
      };
    }
    const heartbeats = CANONICAL_WORKERS.map((name) => {
      const r = latestByName.get(name)!;
      const ageMs = now - new Date(r.last_tick_at).getTime();
      const stale = ageMs > WORKER_HEARTBEAT_STALE_MS;
      return {
        workerName: name,
        instanceId: r.instance_id,
        lastTickAt: r.last_tick_at,
        lastError: r.last_error,
        ageMs,
        stale,
        healthy: !stale && !r.last_error,
        missing: false,
      };
    });
    let failedDeletesAlerted = 0;
    try {
      const failed = await this.pg.query<{ c: string }>(
        `SELECT count(*)::text AS c FROM media_cf_delete_outbox
         WHERE status = 'failed' AND alerted_at IS NOT NULL`,
      );
      failedDeletesAlerted = Number(failed.rows[0]?.c ?? 0);
    } catch {
      res.status(503);
      return {
        status: 'degraded',
        reason: 'db_error',
        runMode: placesRunMode(),
        heartbeats,
        failedDeletesAlerted: 0,
      };
    }
    const degraded =
      heartbeats.some((h) => !h.healthy) || failedDeletesAlerted > 0;
    if (degraded) {
      res.status(503);
    }
    return {
      status: degraded ? 'degraded' : 'ok',
      runMode: placesRunMode(),
      heartbeats,
      failedDeletesAlerted,
    };
  }

  @Public()
  @Get('metrics')
  snapshot(@Query('format') _format?: string) {
    return metrics.snapshot();
  }
}
