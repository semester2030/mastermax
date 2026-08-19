import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { json } from 'express';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { AppModule } from './app.module';
import { createAppConfig } from './shared/config/app-config';
import { JsonLogger } from './shared/observability/logger';
import { correlationMiddleware } from './shared/observability/correlation';

async function bootstrap(): Promise<void> {
  const env = createAppConfig();
  const app = await NestFactory.create(AppModule, { logger: new JsonLogger(), rawBody: false });
  app.use(
    json({
      verify: (req, _res, buf) => {
        (req as { rawBody?: string }).rawBody = buf.toString('utf8');
      },
    }),
  );
  app.use(correlationMiddleware);
  const corsOrigins = (process.env.PLACES_CORS_ORIGINS ?? '')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean);
  if (corsOrigins.length > 0) {
    app.enableCors({
      origin: corsOrigins,
      credentials: true,
      allowedHeaders: [
        'Authorization',
        'Content-Type',
        'Idempotency-Key',
        'X-Correlation-Id',
      ],
      methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    });
  }
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: { enableImplicitConversion: true },
    }),
  );
  const swagger = new DocumentBuilder()
    .setTitle('Places Core API')
    .setVersion('v1')
    .addBearerAuth()
    .build();
  SwaggerModule.setup('docs', app, SwaggerModule.createDocument(app, swagger));
  await app.listen(env.port, env.host);
}

bootstrap();
