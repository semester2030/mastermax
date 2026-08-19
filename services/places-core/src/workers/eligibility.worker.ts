import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { ReceivableEligibilityService } from '../modules/settlements/application/receivable-eligibility.service';
import { PgService } from '../shared/database/pg.service';
import { shouldAutoStartWorkers } from './worker-runtime';
import { newWorkerInstanceId, writeHeartbeat } from './worker-heartbeat';

@Injectable()
export class EligibilityWorker implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(EligibilityWorker.name);
  private timer?: NodeJS.Timeout;
  private readonly instanceId = newWorkerInstanceId();

  constructor(
    private readonly eligibility: ReceivableEligibilityService,
    private readonly pg: PgService,
  ) {}

  onModuleInit(): void {
    if (!shouldAutoStartWorkers()) {
      return;
    }
    void writeHeartbeat(this.pg, 'eligibility', this.instanceId, null);
    this.timer = setInterval(() => {
      this.tick().catch((err) => this.logger.error(String(err)));
    }, 30_000);
  }

  onModuleDestroy(): void {
    if (this.timer) {
      clearInterval(this.timer);
    }
  }

  async tick(): Promise<void> {
    try {
      await this.eligibility.promoteDue();
      await writeHeartbeat(this.pg, 'eligibility', this.instanceId, null);
    } catch (err) {
      await writeHeartbeat(this.pg, 'eligibility', this.instanceId, String(err));
      throw err;
    }
  }
}
