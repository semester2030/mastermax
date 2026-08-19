import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';
import { AppError, ErrorEnvelope } from './app-error';
import { ErrorCodes } from './error-codes';

@Catch()
export class AppExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(AppExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const res = ctx.getResponse<Response>();
    const req = ctx.getRequest<Request & { correlationId?: string }>();
    const correlationId = req.correlationId ?? 'unknown';

    let body: ErrorEnvelope;
    let status = 500;

    if (exception instanceof AppError) {
      status = exception.httpStatus;
      body = {
        code: exception.code,
        message: exception.message,
        correlationId,
        details: exception.details,
        retryable: exception.retryable,
      };
    } else if (exception instanceof HttpException) {
      status = exception.getStatus();
      const raw = exception.getResponse();
      const message =
        typeof raw === 'string' ? raw : (raw as { message?: string }).message ?? exception.message;
      body = {
        code: status === 401 ? ErrorCodes.UNAUTHENTICATED : ErrorCodes.VALIDATION_ERROR,
        message: Array.isArray(message) ? message.join(', ') : String(message),
        correlationId,
        retryable: false,
      };
    } else {
      this.logger.error({ correlationId, err: String(exception) }, 'unhandled');
      body = {
        code: ErrorCodes.INTERNAL,
        message: 'Internal error',
        correlationId,
        retryable: true,
      };
    }
    res.status(status).json(body);
  }
}
