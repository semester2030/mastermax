import { Injectable } from '@nestjs/common';
import { PoolClient } from 'pg';
import { PgService } from '../../../shared/database/pg.service';
import { AppError } from '../../../shared/errors/app-error';
import { ErrorCodes } from '../../../shared/errors/error-codes';
import { AuditService } from '../../audit/application/audit.service';
import { BookingLockOrder } from '../../booking/application/booking-lock-order';

export type ProviderStatus = 'pending' | 'active' | 'suspended' | 'rejected';

const ALLOWED: ProviderStatus[] = ['pending', 'active', 'suspended', 'rejected'];

export interface SetProviderStatusInput {
  actorUid: string;
  actorRole: string;
  providerId: string;
  status: ProviderStatus;
  reason: string;
  correlationId: string;
}

/**
 * Real application-level provider status command (F-V3-010 / F-V2-012 boundary).
 *
 * Suspend/reactivate is NOT a bare UPDATE: it runs in one atomic transaction and
 * takes locks in the canonical Gate-9A order — every venue row of the provider
 * FOR UPDATE (venue-first, ORDER BY id) BEFORE the providers row — so it
 * serializes against HoldService.create, which locks the venue then re-reads
 * providers.status inside the same transaction. That shared venue lock is what
 * makes the suspend-vs-hold race deterministic (no lock inversion, no window in
 * which a hold reads a stale "active" status). Every transition is audited.
 */
@Injectable()
export class ProviderStatusService {
  constructor(
    private readonly pg: PgService,
    private readonly audit: AuditService,
  ) {}

  async setStatus(
    input: SetProviderStatusInput,
  ): Promise<{ id: string; status: ProviderStatus; previousStatus: ProviderStatus }> {
    if (!ALLOWED.includes(input.status)) {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, 'Invalid provider status');
    }
    return this.pg.tx(async (c: PoolClient) => {
      // 1) Canonical venue-first locks: lock all provider venues FOR UPDATE in id
      //    order. This is the exact row a concurrent hold locks via
      //    BookingLockOrder.lockVenue, so the two commands can never interleave.
      await c.query(
        `SELECT id FROM venues WHERE provider_id = $1 ORDER BY id FOR UPDATE`,
        [input.providerId],
      );
      // 2) Lock the provider row itself and read the current status.
      const cur = await c.query<{ status: ProviderStatus }>(
        `SELECT status FROM providers WHERE id = $1 FOR UPDATE`,
        [input.providerId],
      );
      if (!cur.rowCount) {
        throw new AppError(ErrorCodes.NOT_FOUND, 'Provider not found');
      }
      const previousStatus = cur.rows[0].status;
      await c.query(
        `UPDATE providers SET status = $2, updated_at = now() WHERE id = $1`,
        [input.providerId, input.status],
      );
      await this.audit.write(
        {
          actorUid: input.actorUid,
          actorRole: input.actorRole,
          entityType: 'provider',
          entityId: input.providerId,
          before: { status: previousStatus },
          after: { status: input.status },
          reason: input.reason,
          correlationId: input.correlationId,
        },
        c,
      );
      return { id: input.providerId, status: input.status, previousStatus };
    });
  }

  // Kept alongside BookingLockOrder to document the shared parent-row contract.
  static readonly lockOrder = BookingLockOrder;
}
