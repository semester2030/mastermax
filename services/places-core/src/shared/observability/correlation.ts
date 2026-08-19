import { randomUUID } from 'crypto';
import { NextFunction, Request, Response } from 'express';

export type CorrelatedRequest = Request & { correlationId: string };

export function correlationMiddleware(req: Request, res: Response, next: NextFunction): void {
  const incoming = req.header('x-correlation-id');
  const id = incoming && incoming.length > 8 ? incoming : randomUUID();
  (req as CorrelatedRequest).correlationId = id;
  res.setHeader('x-correlation-id', id);
  next();
}
