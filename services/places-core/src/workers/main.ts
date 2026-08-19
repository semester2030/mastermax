import { NestFactory } from '@nestjs/core';
import { AppModule } from '../app.module';
import { JsonLogger } from '../shared/observability/logger';

/**
 * Worker process entrypoint (Phase 6 / F-V3-005).
 * Independent of the API HTTP process — timers start only when PLACES_RUN_MODE=worker.
 */
async function bootstrap(): Promise<void> {
  process.env.PLACES_RUN_MODE = 'worker';
  const app = await NestFactory.createApplicationContext(AppModule, {
    logger: new JsonLogger(),
  });
  await app.init();
}

bootstrap();
