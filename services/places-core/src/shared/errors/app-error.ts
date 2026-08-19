import { ErrorCode, ErrorCodes, HttpByCode } from './error-codes';

export class AppError extends Error {
  readonly code: ErrorCode;
  readonly httpStatus: number;
  readonly retryable: boolean;
  readonly details?: Record<string, unknown>;

  constructor(
    code: ErrorCode,
    message: string,
    details?: Record<string, unknown>,
    retryable?: boolean,
  ) {
    super(message);
    this.code = code;
    this.httpStatus = HttpByCode[code];
    this.details = details;
    this.retryable = retryable ?? code === ErrorCodes.INTERNAL;
  }
}

export interface ErrorEnvelope {
  code: string;
  message: string;
  correlationId: string;
  details?: Record<string, unknown>;
  retryable: boolean;
}
