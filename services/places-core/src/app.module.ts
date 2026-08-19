import { Module } from "@nestjs/common";
import { APP_FILTER, APP_GUARD } from "@nestjs/core";
import { APP_CONFIG, createAppConfig } from "./shared/config/app-config";
import { PgService } from "./shared/database/pg.service";
import { AppExceptionFilter } from "./shared/errors/http-exception.filter";
import { AuthGuard } from "./shared/auth/auth.guard";
import { TOKEN_VERIFIER } from "./shared/auth/token-verifier.port";
import { StubTokenVerifier } from "./shared/auth/stub-token.verifier";
import { FirebaseTokenVerifier } from "./shared/auth/firebase-token.verifier";
import { OperatorAuthController } from "./modules/auth/api/operator-auth.controller";
import { OperatorAuthService } from "./modules/auth/application/operator-auth.service";
import {
  BASE_TOKEN_VERIFIER,
  CompositeTokenVerifier,
} from "./modules/auth/infrastructure/composite-token.verifier";
import { ProviderInventoryService } from "./modules/venues/application/provider-inventory.service";
import { ProviderRatePlansService } from "./modules/venues/application/provider-rate-plans.service";
import { IdempotencyService } from "./shared/idempotency/idempotency.service";
import { OutboxService } from "./shared/events/outbox.service";
import { AuditService } from "./modules/audit/application/audit.service";
import { CapacityService } from "./modules/inventory/application/capacity.service";
import { AvailabilityService } from "./modules/availability/application/availability.service";
import { PricingEngine } from "./modules/pricing/application/pricing.engine";
import { QuoteService } from "./modules/pricing/application/quote.service";
import { BookingStateMachine } from "./modules/booking/domain/booking-state.machine";
import { HoldService } from "./modules/booking/application/hold.service";
import { PayAtVenueService } from "./modules/booking/application/pay-at-venue.service";
import { BookingCancelService } from "./modules/booking/application/booking-cancel.service";
import { BookingQuery } from "./modules/booking/application/booking.query";
import { RefundService } from "./modules/booking/application/refund.service";
import { LedgerService } from "./modules/ledger/application/ledger.service";
import { PAYMENT_PORT } from "./modules/payments/domain/payment.port";
import { PaymentStubAdapter } from "./modules/payments/infrastructure/payment-stub.adapter";
import { PavOnlyPaymentAdapter } from "./modules/payments/infrastructure/payment-pav-only.adapter";
import { PaymentService } from "./modules/payments/application/payment.service";
import { PavOpsService } from "./modules/booking/application/pav-ops.service";
import { DarCommissionService } from "./modules/settlements/application/dar-commission.service";
import { CLOUDFLARE_MEDIA_PORT } from "./modules/media/domain/cloudflare-media.port";
import { CloudflareMediaAdapter } from "./modules/media/infrastructure/cloudflare-media.adapter";
import { CloudflareMediaStubAdapter } from "./modules/media/infrastructure/cloudflare-media.stub.adapter";
import { SettlementService } from "./modules/settlements/application/settlement.service";
import { ReceivableEligibilityService } from "./modules/settlements/application/receivable-eligibility.service";
import { ReviewService } from "./modules/reviews/application/review.service";
import { CatalogService } from "./modules/catalog/application/catalog.service";
import { FilterEngineService } from "./modules/filters/application/filter-engine.service";
import { VenueTypeCapabilityPolicy } from "./modules/filters/application/venue-type-capability.policy";
import { TenancyService } from "./modules/providers/application/tenancy.service";
import { ProviderStatusService } from "./modules/providers/application/provider-status.service";
import { ProviderOpsService } from "./modules/venues/application/provider-ops.service";
import { NOTIFICATION_PORT } from "./modules/notifications/application/notification.port";
import { NotificationStubAdapter } from "./modules/notifications/infrastructure/notification-stub.adapter";
import { SMS_PORT } from "./modules/notifications/domain/sms.port";
import { SmsStubAdapter } from "./modules/notifications/infrastructure/sms-stub.adapter";
import { SmsHttpAdapter } from "./modules/notifications/infrastructure/sms-http.adapter";
import { VenuePublicationService } from "./modules/venues/application/venue-publication.service";
import { MediaModerationService } from "./modules/venues/application/media-moderation.service";
import { LocationCatalogService } from "./modules/venues/application/location-catalog.service";
import { ConsumerController } from "./modules/consumer/api/consumer.controller";
import { ProviderController } from "./modules/venues/api/provider.controller";
import { AdminController } from "./modules/admin/api/admin.controller";
import { WebhookController } from "./modules/webhooks/api/webhook.controller";
import { HealthController } from "./modules/health/health.controller";
import { OutboxWorker } from "./workers/outbox.worker";
import { HoldExpiryWorker } from "./workers/hold-expiry.worker";
import { EligibilityWorker } from "./workers/eligibility.worker";
import { RefundWorker } from "./workers/refund.worker";
import { MediaCfDeleteWorker } from "./workers/media-cf-delete.worker";
import { MediaOrphanWorker } from "./workers/media-orphan.worker";
import { EventSlotOpsService } from "./modules/venues/application/event-slot-ops.service";

const env = createAppConfig();

/**
 * Phase 4: Production boots with PAYMENT_PROVIDER=pav_only (PavOnlyPaymentAdapter).
 * stub remains test/dev only and is refused in production.
 */
function paymentPortProvider(): {
  provide: typeof PAYMENT_PORT;
  useClass: typeof PaymentStubAdapter | typeof PavOnlyPaymentAdapter;
} {
  if (env.paymentProvider === "pav_only") {
    return { provide: PAYMENT_PORT, useClass: PavOnlyPaymentAdapter };
  }
  if (env.nodeEnv === "production") {
    throw new Error(
      "FATAL: production requires PAYMENT_PROVIDER=pav_only (stub forbidden; real PSP is Gate 12)",
    );
  }
  return { provide: PAYMENT_PORT, useClass: PaymentStubAdapter };
}

function smsPortProvider(): {
  provide: typeof SMS_PORT;
  useClass: typeof SmsStubAdapter | typeof SmsHttpAdapter;
} {
  if (env.nodeEnv === "production") {
    if (env.otpFixedCodeEnabled) {
      throw new Error(
        "FATAL: PLACES_OTP_FIXED_CODE_ENABLED forbidden when NODE_ENV=production",
      );
    }
    return { provide: SMS_PORT, useClass: SmsHttpAdapter };
  }
  return { provide: SMS_PORT, useClass: SmsStubAdapter };
}

function cloudflareMediaPortProvider(): {
  provide: typeof CLOUDFLARE_MEDIA_PORT;
  useClass: typeof CloudflareMediaAdapter | typeof CloudflareMediaStubAdapter;
} {
  if (env.nodeEnv === "production") {
    if (!env.cloudflareMediaEnabled) {
      throw new Error(
        "FATAL: Cloudflare media stub forbidden when NODE_ENV=production",
      );
    }
    return { provide: CLOUDFLARE_MEDIA_PORT, useClass: CloudflareMediaAdapter };
  }
  return {
    provide: CLOUDFLARE_MEDIA_PORT,
    useClass: env.cloudflareMediaEnabled
      ? CloudflareMediaAdapter
      : CloudflareMediaStubAdapter,
  };
}

@Module({
  controllers: [
    ConsumerController,
    ProviderController,
    AdminController,
    WebhookController,
    HealthController,
    OperatorAuthController,
  ],
  providers: [
    { provide: APP_CONFIG, useValue: env },
    {
      provide: BASE_TOKEN_VERIFIER,
      useClass:
        env.authMode === "firebase" ? FirebaseTokenVerifier : StubTokenVerifier,
    },
    OperatorAuthService,
    { provide: TOKEN_VERIFIER, useClass: CompositeTokenVerifier },
    paymentPortProvider(),
    smsPortProvider(),
    { provide: NOTIFICATION_PORT, useClass: NotificationStubAdapter },
    cloudflareMediaPortProvider(),
    { provide: APP_GUARD, useClass: AuthGuard },
    { provide: APP_FILTER, useClass: AppExceptionFilter },
    PgService,
    IdempotencyService,
    OutboxService,
    AuditService,
    CapacityService,
    AvailabilityService,
    PricingEngine,
    QuoteService,
    BookingStateMachine,
    HoldService,
    PayAtVenueService,
    PavOpsService,
    BookingCancelService,
    BookingQuery,
    RefundService,
    LedgerService,
    PaymentService,
    SettlementService,
    ReceivableEligibilityService,
    DarCommissionService,
    ReviewService,
    CatalogService,
    FilterEngineService,
    VenueTypeCapabilityPolicy,
    TenancyService,
    ProviderStatusService,
    VenuePublicationService,
    MediaModerationService,
    LocationCatalogService,
    EventSlotOpsService,
    ProviderOpsService,
    ProviderInventoryService,
    ProviderRatePlansService,
    OutboxWorker,
    HoldExpiryWorker,
    EligibilityWorker,
    RefundWorker,
    MediaCfDeleteWorker,
    MediaOrphanWorker,
  ],
})
export class AppModule {}
