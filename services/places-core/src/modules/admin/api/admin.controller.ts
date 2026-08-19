import { Body, Controller, Get, Headers, HttpCode, HttpStatus, Param, Patch, Post, Query, Req } from '@nestjs/common';
import { AuthUser, hasClaim } from '../../../shared/auth/auth-user';
import { CurrentUser, RequireClaim } from '../../../shared/auth/auth.decorators';
import { AppError } from '../../../shared/errors/app-error';
import { ErrorCodes } from '../../../shared/errors/error-codes';
import { PgService } from '../../../shared/database/pg.service';
import { CorrelatedRequest } from '../../../shared/observability/correlation';
import { IdempotencyService } from '../../../shared/idempotency/idempotency.service';
import {
  AdminProviderStatusDto,
  AdminVenueStatusDto,
  CancelBookingDto,
  CreateRefundDto,
  CreateSettlementDto,
  ModerateMediaDto,
  PaginationQueryDto,
} from '../../../shared/api/dto/common.dto';
import { RefundService } from '../../booking/application/refund.service';
import { BookingCancelService } from '../../booking/application/booking-cancel.service';
import { SettlementService } from '../../settlements/application/settlement.service';
import { AuditService } from '../../audit/application/audit.service';
import { ProviderOpsService } from '../../venues/application/provider-ops.service';
import { ProviderStatusService } from '../../providers/application/provider-status.service';
import { MediaModerationService } from '../../venues/application/media-moderation.service';
import { VenuePublicationService } from '../../venues/application/venue-publication.service';
import { OperatorAuthService } from '../../auth/application/operator-auth.service';

@Controller('v1/admin')
@RequireClaim('placesAdmin')
export class AdminController {
  constructor(
    private readonly pg: PgService,
    private readonly refunds: RefundService,
    private readonly cancels: BookingCancelService,
    private readonly settlements: SettlementService,
    private readonly audit: AuditService,
    private readonly ops: ProviderOpsService,
    private readonly idem: IdempotencyService,
    private readonly providerStatus: ProviderStatusService,
    private readonly moderation: MediaModerationService,
    private readonly publication: VenuePublicationService,
    private readonly operatorAuth: OperatorAuthService,
  ) {}

  private pageLimit(raw?: number, fallback = 50, max = 100): number {
    const n = raw ?? fallback;
    if (!Number.isFinite(n) || n < 1) {
      return fallback;
    }
    return Math.min(Math.floor(n), max);
  }

  @Get('providers')
  providers(@Query() query: PaginationQueryDto) {
    return this.pg
      .query('SELECT id, display_name, status FROM providers ORDER BY created_at DESC LIMIT $1', [
        this.pageLimit(query.limit),
      ])
      .then((r) => r.rows);
  }

  @Get('venues')
  venues(@Query() query: PaginationQueryDto) {
    return this.pg
      .query('SELECT id, name, status, provider_id FROM venues ORDER BY created_at DESC LIMIT $1', [
        this.pageLimit(query.limit),
      ])
      .then((r) => r.rows);
  }

  @Get('bookings')
  bookings(@Query() query: PaginationQueryDto) {
    return this.pg
      .query('SELECT id, human_code, status, provider_id FROM bookings ORDER BY created_at DESC LIMIT $1', [
        this.pageLimit(query.limit),
      ])
      .then((r) => r.rows);
  }

  /** Admin cancel — PAV path is atomic CANCELLED+VOIDED (zero financial mutations). */
  @Post('bookings/:id/cancel')
  @HttpCode(HttpStatus.OK)
  async cancelBooking(
    @CurrentUser() user: AuthUser,
    @Req() req: CorrelatedRequest,
    @Param('id') id: string,
    @Headers('idempotency-key') key: string | undefined,
    @Body() body: CancelBookingDto,
  ) {
    const scope = {
      actorUid: user.uid,
      httpMethod: 'POST',
      routePath: '/v1/admin/bookings/:id/cancel',
    };
    return this.idem.runScoped(key, { id, ...body }, true, scope, 24, async (c) => {
      const result = await this.cancels.cancel({
        bookingId: id,
        actorUid: user.uid,
        actorRole: 'admin',
        reason: body.reason,
        correlationId: req.correlationId,
        client: c,
      });
      return { responseCode: 200, responseBody: result };
    });
  }

  @Get('payments')
  payments(@Query() query: PaginationQueryDto) {
    return this.pg
      .query('SELECT id, status, amount, psp_name FROM payments ORDER BY created_at DESC LIMIT $1', [
        this.pageLimit(query.limit),
      ])
      .then((r) => r.rows);
  }

  @Get('refunds')
  refundsList(@Query() query: PaginationQueryDto) {
    return this.pg
      .query('SELECT id, amount, status, kind FROM refunds ORDER BY created_at DESC LIMIT $1', [
        this.pageLimit(query.limit),
      ])
      .then((r) => r.rows);
  }

  @Get('settlements')
  settlementsList(@Query() query: PaginationQueryDto) {
    return this.pg
      .query('SELECT id, provider_id, net, status FROM settlements ORDER BY created_at DESC LIMIT $1', [
        this.pageLimit(query.limit),
      ])
      .then((r) => r.rows);
  }

  @Get('audit')
  auditList(@Query() query: PaginationQueryDto) {
    return this.pg
      .query(
        'SELECT id, actor_uid, entity_type, entity_id, created_at FROM audit_logs ORDER BY created_at DESC LIMIT $1',
        [this.pageLimit(query.limit, 100, 200)],
      )
      .then((r) => r.rows);
  }

  @Patch('venues/:id')
  async patchVenueStatus(
    @CurrentUser() user: AuthUser,
    @Req() req: CorrelatedRequest,
    @Param('id') id: string,
    @Body() body: AdminVenueStatusDto,
  ) {
    if (body.status === 'published') {
      return this.publication.publishVenue({
        venueId: id,
        actorUid: user.uid,
        actorRole: 'admin',
        correlationId: req.correlationId,
      });
    }
    const before = await this.pg.query('SELECT status FROM venues WHERE id = $1', [id]);
    if (!before.rowCount) {
      throw new AppError(ErrorCodes.NOT_FOUND, 'Venue not found');
    }
    await this.pg.query('UPDATE venues SET status = $2, updated_at = now() WHERE id = $1', [
      id,
      body.status,
    ]);
    await this.audit.write({
      actorUid: user.uid,
      actorRole: 'placesAdmin',
      entityType: 'venue',
      entityId: id,
      before: before.rows[0],
      after: body,
      reason: body.reason,
      correlationId: req.correlationId,
    });
    return { ok: true };
  }

  /** Production admin moderation queue — image/video preview URLs included. */
  @Get('media/pending')
  pendingMedia(@Query('limit') limit?: string) {
    return this.moderation.listPending(limit ? Number(limit) : 50);
  }

  /** Bind phone ↔ provider for multi-provider OTP onboarding (F-V3-003). */
  @Post('auth/provider-identities')
  bindIdentity(
    @CurrentUser() user: AuthUser,
    @Req() req: CorrelatedRequest,
    @Body()
    body: { phoneE164: string; providerId: string; displayLabel?: string },
  ) {
    return this.operatorAuth.bindProviderIdentity({
      phoneE164: body.phoneE164,
      providerId: body.providerId,
      displayLabel: body.displayLabel,
      actorUid: user.uid,
      correlationId: req.correlationId,
    });
  }

  /**
   * Provider status command (suspend / reactivate). Thin controller: it only
   * parses and delegates to ProviderStatusService, which runs the atomic
   * transaction (canonical venue-first locks) and writes the audit row.
   */
  @Patch('providers/:id/status')
  async setProviderStatus(
    @CurrentUser() user: AuthUser,
    @Req() req: CorrelatedRequest,
    @Param('id') id: string,
    @Body() body: AdminProviderStatusDto,
  ) {
    return this.providerStatus.setStatus({
      actorUid: user.uid,
      actorRole: 'placesAdmin',
      providerId: id,
      status: body.status,
      reason: body.reason,
      correlationId: req.correlationId,
    });
  }

  /** Admin moderation — thin delegate to MediaModerationService (shared path). */
  @Patch('media/:id/moderation')
  async moderateMedia(
    @CurrentUser() user: AuthUser,
    @Req() req: CorrelatedRequest,
    @Param('id') id: string,
    @Body() body: ModerateMediaDto,
  ) {
    return this.moderation.moderate({
      mediaId: id,
      decision: body.moderationStatus,
      expectedCasVersion: body.expectedCasVersion,
      actorUid: user.uid,
      actorRole: 'placesAdmin',
      correlationId: req.correlationId,
      reason: body.reason,
      rejectionReason: body.rejectionReason,
    });
  }

  /** Admin orphan upload cleanup (optionally scoped to a provider). */
  @Post('media/orphans/cleanup')
  cleanupOrphans(
    @Query('providerId') providerId?: string,
    @Query('limit') limit?: string,
  ) {
    return this.ops.cleanupOrphanUploads(
      providerId ?? null,
      limit ? Number(limit) : 50,
    );
  }

  @Post('refunds')
  async adminRefund(
    @CurrentUser() user: AuthUser,
    @Req() req: CorrelatedRequest,
    @Headers('idempotency-key') key: string | undefined,
    @Body() body: CreateRefundDto,
  ) {
    // F-REV4-04: Idempotency-Key required; runScoped serializes retries.
    const scope = {
      actorUid: user.uid,
      httpMethod: 'POST',
      routePath: '/v1/admin/refunds',
    };
    return this.idem.runScoped(key, body, true, scope, 24, async (c) => {
      // RC6: PAY_AT_VENUE → cancel VOIDED path (never PSP refund).
      const peek = await c.query<{
        payment_method: string | null;
        payment_status: string | null;
      }>(
        `SELECT payment_method, payment_status FROM bookings WHERE id = $1`,
        [body.bookingId],
      );
      if (
        peek.rowCount &&
        peek.rows[0].payment_method === 'PAY_AT_VENUE'
      ) {
        const result = await this.cancels.cancel({
          bookingId: body.bookingId,
          actorUid: user.uid,
          actorRole: 'admin',
          reason: body.reason,
          correlationId: req.correlationId,
          client: c,
        });
        return {
          responseCode: 201,
          responseBody: {
            refundId: 'none',
            amount: '0.00',
            status: 'voided_pay_at_venue',
            cancel: result,
          },
        };
      }
      const result = await this.refunds.refund({
        bookingId: body.bookingId,
        actorUid: user.uid,
        actorRole: 'placesAdmin',
        kind: body.kind ?? 'operational',
        amount: body.amount,
        reason: body.reason,
        correlationId: req.correlationId,
        idempotencyKey: key,
      });
      return { responseCode: 201, responseBody: result };
    });
  }

  @Post('settlements')
  async createSettlement(
    @CurrentUser() user: AuthUser,
    @Req() req: CorrelatedRequest,
    @Body() body: CreateSettlementDto,
  ) {
    if (!hasClaim(user, 'placesFinance') && !hasClaim(user, 'placesAdmin')) {
      throw new AppError(ErrorCodes.FORBIDDEN_PROVIDER_SCOPE, 'Finance role required');
    }
    return this.settlements.createDraft({ ...body, actorUid: user.uid, correlationId: req.correlationId });
  }

  @Post('settlements/:id/pay')
  async pay(
    @CurrentUser() user: AuthUser,
    @Req() req: CorrelatedRequest,
    @Param('id') id: string,
  ) {
    if (!hasClaim(user, 'placesFinance') && !hasClaim(user, 'placesAdmin')) {
      throw new AppError(ErrorCodes.FORBIDDEN_PROVIDER_SCOPE, 'Finance role required');
    }
    await this.settlements.approveAndStubPayout(id, user.uid, req.correlationId);
    return { ok: true };
  }
}
