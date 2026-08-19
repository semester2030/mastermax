import { LoggerService } from '@nestjs/common';

const REDACT = ['authorization', 'iban', 'token', 'secret', 'password'];

function redact(value: unknown): unknown {
  if (!value || typeof value !== 'object') {
    return value;
  }
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(value as Record<string, unknown>)) {
    out[k] = REDACT.some((p) => k.toLowerCase().includes(p)) ? '[redacted]' : v;
  }
  return out;
}

export class JsonLogger implements LoggerService {
  log(message: string, ...optional: unknown[]): void {
    this.write('info', message, optional[0]);
  }
  error(message: string, ...optional: unknown[]): void {
    this.write('error', message, optional[0]);
  }
  warn(message: string, ...optional: unknown[]): void {
    this.write('warn', message, optional[0]);
  }
  debug(message: string, ...optional: unknown[]): void {
    this.write('debug', message, optional[0]);
  }
  verbose(message: string, ...optional: unknown[]): void {
    this.write('debug', message, optional[0]);
  }

  private write(severity: string, message: string, extra?: unknown): void {
    const line = JSON.stringify({
      severity,
      message,
      time: new Date().toISOString(),
      ...(typeof extra === 'object' && extra ? (redact(extra) as object) : {}),
    });
    process.stdout.write(line + '\n');
  }
}
