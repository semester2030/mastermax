import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { RefundService } from '../modules/booking/application/refund.service';
import { PgService } from '../shared/database/pg.service';
import { shouldAutoStartWorkers } from './worker-runtime';
import { newWorkerInstanceId, writeHeartbeat } from './worker-heartbeat';

@Injectable()
export class RefundWorker implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(RefundWorker.name);
  private timer?: NodeJS.Timeout;
  private readonly instanceId = newWorkerInstanceId();

  constructor(
    private readonly refunds: RefundService,
    private readonly pg: PgService,
  ) {}

  onModuleInit(): void {
    if (!shouldAutoStartWorkers()) {
      return;
    }
    void writeHeartbeat(this.pg, 'refund', this.instanceId, null);
    this.timer = setInterval(() => {
      this.tick().catch((err) => this.logger.error(String(err)));
    }, 3000);
  }

  onModuleDestroy(): void {
    if (this.timer) {
      clearInterval(this.timer);
    }
  }

  async tick(): Promise<void> {
    try {
      await this.refunds.dispatchPending();
      await writeHeartbeat(this.pg, 'refund', this.instanceId, null);
    } catch (err) {
      await writeHeartbeat(this.pg, 'refund', this.instanceId, String(err));
      throw err;
    }
  }
}
