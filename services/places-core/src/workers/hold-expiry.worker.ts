import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { HoldService } from '../modules/booking/application/hold.service';
import { PgService } from '../shared/database/pg.service';
import { shouldAutoStartWorkers } from './worker-runtime';
import { newWorkerInstanceId, writeHeartbeat } from './worker-heartbeat';

@Injectable()
export class HoldExpiryWorker implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(HoldExpiryWorker.name);
  private timer?: NodeJS.Timeout;
  private readonly instanceId = newWorkerInstanceId();

  constructor(
    private readonly holds: HoldService,
    private readonly pg: PgService,
  ) {}

  onModuleInit(): void {
    if (!shouldAutoStartWorkers()) {
      return;
    }
    void writeHeartbeat(this.pg, 'hold_expiry', this.instanceId, null);
    this.timer = setInterval(() => {
      this.tick().catch((err) => this.logger.error(String(err)));
    }, 30_000);
  }

  onModuleDestroy(): void {
    if (this.timer) {
      clearInterval(this.timer);
    }
  }

  async tick(): Promise<number> {
    try {
      const n = await this.holds.expireDue();
      await writeHeartbeat(this.pg, 'hold_expiry', this.instanceId, null);
      return n;
    } catch (err) {
      await writeHeartbeat(this.pg, 'hold_expiry', this.instanceId, String(err));
      throw err;
    }
  }
}
