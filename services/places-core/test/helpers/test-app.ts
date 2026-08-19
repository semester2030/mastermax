import 'reflect-metadata';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { json } from 'express';
import { Pool } from 'pg';
import { execSync } from 'child_process';
import path from 'path';
import { AppModule } from '../../src/app.module';
import { correlationMiddleware } from '../../src/shared/observability/correlation';
import { assertCiDatabaseUrl, dropPublicSchemaForCi } from './db-safety';

export function testEnv(): void {
  process.env.NODE_ENV = 'test';
  // Default Jest DB is places_core_ci — never places_core_test (Wave1 staging).
  process.env.DATABASE_URL =
    process.env.DATABASE_URL ?? 'postgresql://127.0.0.1:5432/places_core_ci';
  assertCiDatabaseUrl(process.env.DATABASE_URL);
  process.env.AUTH_MODE = 'stub';
  process.env.STUB_WEBHOOK_SECRET = 'test-stub-secret';
  process.env.HOLD_TTL_SECONDS = '720';
  process.env.QUOTE_TTL_SECONDS = '900';
  process.env.DEFAULT_COMMISSION_BPS = '1000';
  process.env.PORT = '0';
  if (!process.env.PG_WORK_MEM) process.env.PG_WORK_MEM = '16MB';
}

export async function resetDb(): Promise<void> {
  testEnv();
  const url = assertCiDatabaseUrl(process.env.DATABASE_URL);
  const pool = new Pool({ connectionString: url });
  await dropPublicSchemaForCi(pool, url);
  await pool.end();
  execSync('npx ts-node src/shared/database/migrate.ts', {
    cwd: path.resolve(__dirname, '../..'),
    env: process.env,
    stdio: 'inherit',
  });
}

export async function createTestApp(): Promise<INestApplication> {
  testEnv();
  const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
  const app = moduleRef.createNestApplication();
  app.use(
    json({
      verify: (req, _res, buf) => {
        (req as { rawBody?: string }).rawBody = buf.toString('utf8');
      },
    }),
  );
  app.use(correlationMiddleware);
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: { enableImplicitConversion: true },
    }),
  );
  // Bind a real ephemeral listener. app.init()-only servers flake with
  // concurrent SuperTest (ECONNRESET) under Jest — ah.spec 100-way hold race.
  await app.listen(0);
  return app;
}

export function auth(uid: string, claims = ''): string {
  return `Bearer stub.${uid}.${claims}`;
}
