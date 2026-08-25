import {
  Body,
  Controller,
  Get,
  Headers,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  Put,
  Query,
  Req,
} from "@nestjs/common";
import { AuthUser } from "../../../shared/auth/auth-user";
import {
  CurrentUser,
  RequireAnyClaim,
} from "../../../shared/auth/auth.decorators";
import { ProviderInventoryService, CreateInventoryTypeDto, CreateInventoryUnitDto, PatchInventoryTypeDto } from "../application/provider-inventory.service";
import {
  ProviderRatePlansService,
  CreateRatePlanDto,
  PatchRatePlanDto,
} from "../application/provider-rate-plans.service";
import { CorrelatedRequest } from "../../../shared/observability/correlation";
import { AppError } from "../../../shared/errors/app-error";
import { ErrorCodes } from "../../../shared/errors/error-codes";
import {
  CancelBookingDto,
  CreateVenueDto,
  PatchVenueDto,
  PutVenueAmenitiesDto,
  ProviderAvailabilityDto,
  ProviderPricingDto,
  CompleteImageUploadDto,
  CreateImageUploadSessionDto,
  CompleteStreamUploadDto,
  CreateStreamUploadSessionDto,
  RegisterImageMediaDto,
  RegisterMediaDto,
  ReorderMediaDto,
  MediaCasDto,
  ModerateMediaDto,
  PavCollectAtVenueDto,
  PavBookingActionDto,
} from "../../../shared/api/dto/common.dto";
import { TenancyService } from "../../providers/application/tenancy.service";
import { BookingQuery } from "../../booking/application/booking.query";
import { BookingCancelService } from "../../booking/application/booking-cancel.service";
import { PavOpsService } from "../../booking/application/pav-ops.service";
import { ProviderOpsService } from "../application/provider-ops.service";
import { EventSlotOpsService } from "../application/event-slot-ops.service";
import { LocationCatalogService } from "../application/location-catalog.service";
import { FilterEngineService } from "../../filters/application/filter-engine.service";
import { IdempotencyService } from "../../../shared/idempotency/idempotency.service";
import { PgService } from "../../../shared/database/pg.service";

@Controller("v1/provider")
@RequireAnyClaim("placesProvider", "placesInternalOperator")
export class ProviderController {
  constructor(
    private readonly ops: ProviderOpsService,
    private readonly inventory: ProviderInventoryService,
    private readonly ratePlans: ProviderRatePlansService,
    private readonly tenancy: TenancyService,
    private readonly bookings: BookingQuery,
    private readonly cancels: BookingCancelService,
    private readonly pavOps: PavOpsService,
    private readonly eventSlots: EventSlotOpsService,
    private readonly idem: IdempotencyService,
    private readonly pg: PgService,
    private readonly locations: LocationCatalogService,
    private readonly filters: FilterEngineService,
  ) {}

  private requireIdempotencyKey(key: string | undefined): string {
    if (!key?.trim()) {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        "Idempotency-Key required",
      );
    }
    return key.trim();
  }

  @Post("venues")
  createVenue(
    @CurrentUser() user: AuthUser,
    @Req() req: CorrelatedRequest,
    @Body() body: CreateVenueDto,
  ) {
    return this.ops.createVenue(user, body, req.correlationId);
  }

  /** Phase 7 — event_slot template upsert (pricing + schedule). */
  @Post("event-slots/templates")
  upsertSlotTemplate(
    @CurrentUser() user: AuthUser,
    @Req() req: CorrelatedRequest,
    @Body()
    body: {
      venueId: string;
      inventoryTypeId: string;
      code: string;
      labelAr?: string;
      startTime: string;
      endTime: string;
      capacity?: number;
      basePrice: string;
      status?: "active" | "inactive";
    },
  ) {
    return this.eventSlots.upsertTemplate(user, body, req.correlationId);
  }

  /** Phase 7 — generate open inventory for a date range (idempotent). */
  @Post("event-slots/generate")
  generateSlots(
    @CurrentUser() user: AuthUser,
    @Req() req: CorrelatedRequest,
    @Body()
    body: {
      venueId: string;
      templateId: string;
      dateFrom: string;
      dateTo: string;
    },
  ) {
    return this.eventSlots.generateInventory(user, body, req.correlationId);
  }

  @Get("event-slots/inventory")
  listSlotInventory(
    @CurrentUser() user: AuthUser,
    @Query("venueId") venueId: string,
    @Query("dateFrom") dateFrom?: string,
    @Query("dateTo") dateTo?: string,
  ) {
    if (!venueId) {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, "venueId required");
    }
    return this.eventSlots.listInventory(user, venueId, dateFrom, dateTo);
  }

  @Patch("event-slots/inventory/:id")
  setSlotStatus(
    @CurrentUser() user: AuthUser,
    @Req() req: CorrelatedRequest,
    @Param("id") id: string,
    @Body() body: { venueId: string; status: "open" | "blocked"; reason: string },
  ) {
    return this.eventSlots.setInventoryStatus(
      user,
      { venueId: body.venueId, inventoryId: id, status: body.status, reason: body.reason },
      req.correlationId,
    );
  }

  @Get("location/cities")
  listCities() {
    return this.locations.listCities();
  }

  @Get("location/districts")
  listDistricts(@Query("cityId") cityId?: string) {
    if (!cityId) {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, "cityId required");
    }
    return this.locations.listDistricts(cityId);
  }

  @Get("amenities/catalog")
  listAmenityCatalog(@Query("venueType") venueType?: string) {
    return this.filters.listAmenities(venueType);
  }

  @Get("venues/:id/amenities")
  listVenueAmenities(@CurrentUser() user: AuthUser, @Param("id") id: string) {
    return this.ops.listVenueAmenities(user, id);
  }

  @Put("amenities")
  putAmenities(
    @CurrentUser() user: AuthUser,
    @Req() req: CorrelatedRequest,
    @Body() body: PutVenueAmenitiesDto,
  ) {
    return this.ops.putAmenities(user, body, req.correlationId);
  }

  @Get("venues")
  async listVenues(
    @CurrentUser() user: AuthUser,
    @Query("providerId") providerId?: string,
  ) {
    if (!providerId) {
      if (user.claims.placesInternalOperator) {
        throw new AppError(ErrorCodes.VALIDATION_ERROR, "providerId required");
      }
      const m = await this.tenancy.requireAny(user.uid, "venue.crud");
      return this.ops.listVenues(user, m.providerId);
    }
    const m = await this.tenancy.require(user, providerId, "venue.crud");
    return this.ops.listVenues(user, m.providerId);
  }

  @Get("venues/:id")
  async getVenue(@CurrentUser() user: AuthUser, @Param("id") id: string) {
    return this.ops.getVenue(user, id);
  }

  @Patch("venues/:id")
  patchVenue(
    @CurrentUser() user: AuthUser,
    @Req() req: CorrelatedRequest,
    @Param("id") id: string,
    @Body() body: PatchVenueDto,
  ) {
    return this.ops.patchVenue(
      user,
      id,
      body as Record<string, unknown>,
      req.correlationId,
    );
  }

  @Get("calendar")
  async calendar(
    @CurrentUser() user: AuthUser,
    @Query("from") from: string,
    @Query("to") to: string,
    @Query("providerId") providerId?: string,
  ) {
    if (!providerId) {
      if (user.claims.placesInternalOperator) {
        throw new AppError(ErrorCodes.VALIDATION_ERROR, 'providerId required');
      }
      const m = await this.tenancy.requireAny(user.uid, "bookings.view");
      return this.ops.calendar(user, m.providerId, from, to);
    }
    const m = await this.tenancy.require(user, providerId, "bookings.view");
    return this.ops.calendar(user, m.providerId, from, to);
  }

  @Post("inventory-types")
  async createInventoryType(
    @CurrentUser() user: AuthUser,
    @Req() req: CorrelatedRequest,
    @Headers("idempotency-key") idempotencyKey: string | undefined,
    @Body() body: CreateInventoryTypeDto,
  ) {
    const key = this.requireIdempotencyKey(idempotencyKey);
    const scope = {
      actorUid: user.uid,
      httpMethod: "POST",
      routePath: "/v1/provider/inventory-types",
    };
    return this.idem.runScoped(
      key,
      body,
      true,
      scope,
      24,
      async () => {
        const result = await this.inventory.create(
          user,
          body,
          req.correlationId,
        );
        return { responseCode: 201, responseBody: result };
      },
    );
  }

  @Get("inventory-types")
  listInventoryTypes(
    @CurrentUser() user: AuthUser,
    @Query("providerId") providerId: string,
    @Query("venueId") venueId: string,
  ) {
    return this.inventory.list(user, providerId, venueId);
  }

  @Get("inventory-types/:id/units")
  listInventoryUnits(
    @CurrentUser() user: AuthUser,
    @Param("id") id: string,
    @Query("providerId") providerId: string,
  ) {
    return this.inventory.listUnits(user, providerId, id);
  }

  @Post("inventory-types/:id/units")
  async createInventoryUnit(
    @CurrentUser() user: AuthUser,
    @Req() req: CorrelatedRequest,
    @Headers("idempotency-key") idempotencyKey: string | undefined,
    @Param("id") id: string,
    @Body() body: CreateInventoryUnitDto,
  ) {
    const key = this.requireIdempotencyKey(idempotencyKey);
    const scope = {
      actorUid: user.uid,
      httpMethod: "POST",
      routePath: "/v1/provider/inventory-types/:id/units",
    };
    return this.idem.runScoped(
      key,
      body,
      true,
      scope,
      24,
      async () => {
        const result = await this.inventory.createUnit(
          user,
          id,
          body,
          req.correlationId,
        );
        return { responseCode: 201, responseBody: result };
      },
    );
  }

  @Patch("inventory-types/:id")
  patchInventoryType(
    @CurrentUser() user: AuthUser,
    @Req() req: CorrelatedRequest,
    @Param("id") id: string,
    @Body() body: PatchInventoryTypeDto,
  ) {
    return this.inventory.patch(user, id, body, req.correlationId);
  }

  @Post("rate-plans")
  async createRatePlan(
    @CurrentUser() user: AuthUser,
    @Req() req: CorrelatedRequest,
    @Headers("idempotency-key") idempotencyKey: string | undefined,
    @Body() body: CreateRatePlanDto,
  ) {
    const key = this.requireIdempotencyKey(idempotencyKey);
    const scope = {
      actorUid: user.uid,
      httpMethod: "POST",
      routePath: "/v1/provider/rate-plans",
    };
    return this.idem.runScoped(
      key,
      body,
      true,
      scope,
      24,
      async () => {
        const result = await this.ratePlans.create(
          user,
          body,
          req.correlationId,
        );
        return { responseCode: 201, responseBody: result };
      },
    );
  }

  @Get("rate-plans")
  listRatePlans(
    @CurrentUser() user: AuthUser,
    @Query("providerId") providerId: string,
    @Query("venueId") venueId?: string,
  ) {
    return this.ratePlans.list(user, providerId, venueId);
  }

  @Patch("rate-plans/:id")
  patchRatePlan(
    @CurrentUser() user: AuthUser,
    @Req() req: CorrelatedRequest,
    @Param("id") id: string,
    @Body() body: PatchRatePlanDto,
  ) {
    return this.ratePlans.patch(user, id, body, req.correlationId);
  }

  @Put("availability")
  async availability(
    @CurrentUser() user: AuthUser,
    @Req() req: CorrelatedRequest,
    @Headers("idempotency-key") idempotencyKey: string | undefined,
    @Body() body: ProviderAvailabilityDto,
  ) {
    const key = this.requireIdempotencyKey(idempotencyKey);
    const scope = {
      actorUid: user.uid,
      httpMethod: "PUT",
      routePath: "/v1/provider/availability",
    };
    return this.idem.runScoped(key, body, true, scope, 24, async () => {
      await this.ops.putAvailability(user, body, req.correlationId);
      return { responseCode: 200, responseBody: { ok: true } };
    });
  }

  @Put("pricing")
  async pricing(
    @CurrentUser() user: AuthUser,
    @Req() req: CorrelatedRequest,
    @Headers("idempotency-key") idempotencyKey: string | undefined,
    @Body() body: ProviderPricingDto,
  ) {
    const key = this.requireIdempotencyKey(idempotencyKey);
    const scope = {
      actorUid: user.uid,
      httpMethod: "PUT",
      routePath: "/v1/provider/pricing",
    };
    return this.idem.runScoped(key, body, true, scope, 24, async () => {
      await this.ops.putPricing(user, body, req.correlationId);
      return { responseCode: 200, responseBody: { ok: true } };
    });
  }

  @Get("bookings")
  async providerBookings(
    @CurrentUser() user: AuthUser,
    @Query("providerId") providerId?: string,
  ) {
    if (!providerId) {
      if (user.claims.placesInternalOperator) {
        throw new AppError(ErrorCodes.VALIDATION_ERROR, 'providerId required');
      }
      const m = await this.tenancy.requireAny(user.uid, "bookings.view");
      return this.bookings.listForProvider(m.providerId);
    }
    const m = await this.tenancy.require(user, providerId, "bookings.view");
    return this.bookings.listForProvider(m.providerId);
  }

  @Get("bookings/:id")
  async providerBooking(
    @CurrentUser() user: AuthUser,
    @Param("id") id: string,
    @Query("providerId") providerId?: string,
  ) {
    const peek = await this.pg.query<{ provider_id: string }>(
      `SELECT provider_id FROM bookings WHERE id = $1`,
      [id],
    );
    if (!peek.rowCount) {
      throw new AppError(ErrorCodes.NOT_FOUND, "Booking not found");
    }
    const pid = providerId ?? peek.rows[0].provider_id;
    const m = await this.tenancy.require(user, pid, "bookings.view");
    return this.bookings.getForProvider(m.providerId, id);
  }

  @Post("bookings/:id/cancel")
  @HttpCode(HttpStatus.OK)
  async cancelBooking(
    @CurrentUser() user: AuthUser,
    @Req() req: CorrelatedRequest,
    @Param("id") id: string,
    @Headers("idempotency-key") idempotencyKey: string | undefined,
    @Body() body: CancelBookingDto,
  ) {
    const key = this.requireIdempotencyKey(idempotencyKey);
    const peek = await this.pg.query<{ provider_id: string }>(
      `SELECT provider_id FROM bookings WHERE id = $1`,
      [id],
    );
    if (!peek.rowCount) {
      throw new AppError(ErrorCodes.NOT_FOUND, "Booking not found");
    }
    const m = await this.tenancy.require(
      user,
      peek.rows[0].provider_id,
      "bookings.cancel",
    );
    const scope = {
      actorUid: user.uid,
      httpMethod: "POST",
      routePath: "/v1/provider/bookings/:id/cancel",
    };
    return this.idem.runScoped(
      key,
      { id, ...body },
      true,
      scope,
      24,
      async (c) => {
        const result = await this.cancels.cancel({
          bookingId: id,
          actorUid: user.uid,
          actorRole: "provider",
          providerId: m.providerId,
          reason: body.reason,
          correlationId: req.correlationId,
          client: c,
        });
        return { responseCode: 200, responseBody: result };
      },
    );
  }

  @Post("bookings/:id/collect-at-venue")
  @HttpCode(HttpStatus.OK)
  async collectAtVenue(
    @CurrentUser() user: AuthUser,
    @Req() req: CorrelatedRequest,
    @Param("id") id: string,
    @Headers("idempotency-key") idempotencyKey: string | undefined,
    @Body() body: PavCollectAtVenueDto,
  ) {
    const key = this.requireIdempotencyKey(idempotencyKey);
    const peek = await this.pg.query<{ provider_id: string }>(
      `SELECT provider_id FROM bookings WHERE id = $1`,
      [id],
    );
    if (!peek.rowCount) {
      throw new AppError(ErrorCodes.NOT_FOUND, "Booking not found");
    }
    const m = await this.tenancy.require(
      user,
      peek.rows[0].provider_id,
      "bookings.checkin",
    );
    const scope = {
      actorUid: user.uid,
      httpMethod: "POST",
      routePath: "/v1/provider/bookings/:id/collect-at-venue",
    };
    return this.idem.runScoped(key, { id, ...body }, true, scope, 24, async (c) => {
      const result = await this.pavOps.collectAtVenue(
        {
          bookingId: id,
          providerId: m.providerId,
          actorUid: user.uid,
          amount: body.amount,
          currency: body.currency ?? "SAR",
          correlationId: req.correlationId,
        },
        c,
      );
      return { responseCode: 200, responseBody: result };
    });
  }

  @Post("bookings/:id/check-in")
  @HttpCode(HttpStatus.OK)
  async checkIn(
    @CurrentUser() user: AuthUser,
    @Req() req: CorrelatedRequest,
    @Param("id") id: string,
    @Headers("idempotency-key") idempotencyKey: string | undefined,
    @Body() body: PavBookingActionDto,
  ) {
    const key = this.requireIdempotencyKey(idempotencyKey);
    const peek = await this.pg.query<{ provider_id: string }>(
      `SELECT provider_id FROM bookings WHERE id = $1`,
      [id],
    );
    if (!peek.rowCount) {
      throw new AppError(ErrorCodes.NOT_FOUND, "Booking not found");
    }
    const m = await this.tenancy.require(
      user,
      peek.rows[0].provider_id,
      "bookings.checkin",
    );
    const scope = {
      actorUid: user.uid,
      httpMethod: "POST",
      routePath: "/v1/provider/bookings/:id/check-in",
    };
    return this.idem.runScoped(key, { id, ...body }, true, scope, 24, async (c) => {
      const result = await this.pavOps.checkIn(
        {
          bookingId: id,
          providerId: m.providerId,
          actorUid: user.uid,
          correlationId: req.correlationId,
        },
        c,
      );
      return { responseCode: 200, responseBody: result };
    });
  }

  @Post("bookings/:id/complete")
  @HttpCode(HttpStatus.OK)
  async complete(
    @CurrentUser() user: AuthUser,
    @Req() req: CorrelatedRequest,
    @Param("id") id: string,
    @Headers("idempotency-key") idempotencyKey: string | undefined,
    @Body() body: PavBookingActionDto,
  ) {
    const key = this.requireIdempotencyKey(idempotencyKey);
    const peek = await this.pg.query<{ provider_id: string }>(
      `SELECT provider_id FROM bookings WHERE id = $1`,
      [id],
    );
    if (!peek.rowCount) {
      throw new AppError(ErrorCodes.NOT_FOUND, "Booking not found");
    }
    const m = await this.tenancy.require(
      user,
      peek.rows[0].provider_id,
      "bookings.checkin",
    );
    const scope = {
      actorUid: user.uid,
      httpMethod: "POST",
      routePath: "/v1/provider/bookings/:id/complete",
    };
    return this.idem.runScoped(key, { id, ...body }, true, scope, 24, async (c) => {
      const result = await this.pavOps.complete(
        {
          bookingId: id,
          providerId: m.providerId,
          actorUid: user.uid,
          correlationId: req.correlationId,
        },
        c,
      );
      return { responseCode: 200, responseBody: result };
    });
  }

  @Post("bookings/:id/no-show")
  @HttpCode(HttpStatus.OK)
  async noShow(
    @CurrentUser() user: AuthUser,
    @Req() req: CorrelatedRequest,
    @Param("id") id: string,
    @Headers("idempotency-key") idempotencyKey: string | undefined,
    @Body() body: PavBookingActionDto,
  ) {
    const key = this.requireIdempotencyKey(idempotencyKey);
    const peek = await this.pg.query<{ provider_id: string }>(
      `SELECT provider_id FROM bookings WHERE id = $1`,
      [id],
    );
    if (!peek.rowCount) {
      throw new AppError(ErrorCodes.NOT_FOUND, "Booking not found");
    }
    const m = await this.tenancy.require(
      user,
      peek.rows[0].provider_id,
      "bookings.checkin",
    );
    const scope = {
      actorUid: user.uid,
      httpMethod: "POST",
      routePath: "/v1/provider/bookings/:id/no-show",
    };
    return this.idem.runScoped(key, { id, ...body }, true, scope, 24, async (c) => {
      const result = await this.pavOps.noShow(
        {
          bookingId: id,
          providerId: m.providerId,
          actorUid: user.uid,
          correlationId: req.correlationId,
        },
        c,
      );
      return { responseCode: 200, responseBody: result };
    });
  }

  @Get("finance")
  async finance(
    @CurrentUser() user: AuthUser,
    @Query("providerId") providerId?: string,
  ) {
    if (!providerId) {
      if (user.claims.placesInternalOperator) {
        throw new AppError(ErrorCodes.VALIDATION_ERROR, 'providerId required');
      }
      const m = await this.tenancy.requireAny(user.uid, "finance.view");
      return this.ops.finance(user, m.providerId);
    }
    const m = await this.tenancy.require(user, providerId, "finance.view");
    return this.ops.finance(user, m.providerId);
  }

  @Get("media")
  async listMedia(
    @CurrentUser() user: AuthUser,
    @Query("venueId") venueId: string,
  ) {
    if (!venueId) {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, "venueId required");
    }
    return this.ops.listMedia(user, venueId);
  }

  /**
   * Internal operator only. Lists pending media for the bound provider.
   */
  @Get("media/pending-moderation")
  listPendingModeration(
    @CurrentUser() user: AuthUser,
    @Query("providerId") providerId?: string,
  ) {
    return this.ops.listPendingModerationForOperator(user, providerId);
  }

  /**
   * Internal operator media approve/reject for the bound provider.
   */
  @Patch("media/:id/moderation")
  moderateMediaAsOperator(
    @CurrentUser() user: AuthUser,
    @Req() req: CorrelatedRequest,
    @Param("id") id: string,
    @Body() body: ModerateMediaDto,
  ) {
    return this.ops.moderateMediaAsOperator(user, id, body, req.correlationId);
  }

  @Post("media")
  media(
    @CurrentUser() user: AuthUser,
    @Req() req: CorrelatedRequest,
    @Body() body: RegisterMediaDto,
  ) {
    return this.ops.registerMedia(user, body, req.correlationId);
  }

  /** Image gallery metadata for Provider Web (Gate 10A) — max 30. */
  @Post("media/images")
  registerImage(
    @CurrentUser() user: AuthUser,
    @Req() req: CorrelatedRequest,
    @Body() body: RegisterImageMediaDto,
  ) {
    return this.ops.registerImageMedia(user, body, req.correlationId);
  }

  /** Step 1: signed Cloudflare Images upload URL (direct upload; no Nest bytes). */
  @Post("media/images/upload-session")
  async createImageUploadSession(
    @CurrentUser() user: AuthUser,
    @Req() req: CorrelatedRequest,
    @Headers("idempotency-key") idempotencyKey: string | undefined,
    @Body() body: CreateImageUploadSessionDto,
  ) {
    const key = this.requireIdempotencyKey(idempotencyKey);
    const scope = {
      actorUid: user.uid,
      httpMethod: "POST",
      routePath: "/v1/provider/media/images/upload-session",
    };
    // CF network outside business TX — runScoped claims key; ops uses its own TXs.
    return this.idem.runScoped(key, body, true, scope, 24, async () => {
      const result = await this.ops.createImageUploadSession(
        user,
        body,
        req.correlationId,
      );
      return { responseCode: 201, responseBody: result };
    });
  }

  /** Step 2: after CF upload — store cloudflareImageId + delivery URL (pending moderation). */
  @Post("media/images/complete")
  completeImageUpload(
    @CurrentUser() user: AuthUser,
    @Req() req: CorrelatedRequest,
    @Body() body: CompleteImageUploadDto,
  ) {
    return this.ops.completeImageUpload(user, body, req.correlationId);
  }

  /** Step 1: signed Cloudflare Stream upload URL (direct upload; no Nest bytes). */
  @Post("media/videos/upload-session")
  async createStreamUploadSession(
    @CurrentUser() user: AuthUser,
    @Req() req: CorrelatedRequest,
    @Headers("idempotency-key") idempotencyKey: string | undefined,
    @Body() body: CreateStreamUploadSessionDto,
  ) {
    const key = this.requireIdempotencyKey(idempotencyKey);
    const scope = {
      actorUid: user.uid,
      httpMethod: "POST",
      routePath: "/v1/provider/media/videos/upload-session",
    };
    return this.idem.runScoped(key, body, true, scope, 24, async () => {
      const result = await this.ops.createStreamUploadSession(
        user,
        body,
        req.correlationId,
      );
      return { responseCode: 201, responseBody: result };
    });
  }

  /** Step 2: after Stream upload — store streamUid + HLS URL (pending moderation). */
  @Post("media/videos/complete")
  completeStreamUpload(
    @CurrentUser() user: AuthUser,
    @Req() req: CorrelatedRequest,
    @Body() body: CompleteStreamUploadDto,
  ) {
    return this.ops.completeStreamUpload(user, body, req.correlationId);
  }

  @Post("media/orphans/cleanup")
  async cleanupOrphans(
    @CurrentUser() user: AuthUser,
    @Query("providerId") providerId?: string,
  ) {
    if (!providerId) {
      if (user.claims.placesInternalOperator) {
        throw new AppError(ErrorCodes.VALIDATION_ERROR, 'providerId required');
      }
      const m = await this.tenancy.requireAny(user.uid, "media.upload");
      return this.ops.cleanupOrphanUploads(m.providerId);
    }
    const m = await this.tenancy.require(user, providerId, "media.upload");
    return this.ops.cleanupOrphanUploads(m.providerId);
  }

  @Put("media/reorder")
  async reorderMedia(
    @CurrentUser() user: AuthUser,
    @Req() req: CorrelatedRequest,
    @Headers("idempotency-key") idempotencyKey: string | undefined,
    @Body() body: ReorderMediaDto,
  ) {
    const key = this.requireIdempotencyKey(idempotencyKey);
    const scope = {
      actorUid: user.uid,
      httpMethod: "PUT",
      routePath: "/v1/provider/media/reorder",
    };
    return this.idem.runScoped(key, body, true, scope, 24, async () => {
      const result = await this.ops.reorderMedia(user, body, req.correlationId);
      return { responseCode: 200, responseBody: result };
    });
  }

  @Put("media/:id/cover")
  async setCover(
    @CurrentUser() user: AuthUser,
    @Req() req: CorrelatedRequest,
    @Param("id") id: string,
    @Headers("idempotency-key") idempotencyKey: string | undefined,
    @Body() body: MediaCasDto,
  ) {
    const key = this.requireIdempotencyKey(idempotencyKey);
    const scope = {
      actorUid: user.uid,
      httpMethod: "PUT",
      routePath: "/v1/provider/media/:id/cover",
    };
    return this.idem.runScoped(
      key,
      { id, ...body },
      true,
      scope,
      24,
      async () => {
        const result = await this.ops.setMediaCover(
          user,
          id,
          req.correlationId,
          body.expectedCasVersion,
        );
        return { responseCode: 200, responseBody: result };
      },
    );
  }

  @Post("media/:id/delete")
  async deleteMedia(
    @CurrentUser() user: AuthUser,
    @Req() req: CorrelatedRequest,
    @Param("id") id: string,
    @Headers("idempotency-key") idempotencyKey: string | undefined,
    @Body() body: MediaCasDto,
  ) {
    const key = this.requireIdempotencyKey(idempotencyKey);
    const scope = {
      actorUid: user.uid,
      httpMethod: "POST",
      routePath: "/v1/provider/media/:id/delete",
    };
    return this.idem.runScoped(
      key,
      { id, ...body },
      true,
      scope,
      24,
      async () => {
        const result = await this.ops.deleteMedia(
          user,
          id,
          req.correlationId,
          body.expectedCasVersion,
        );
        return { responseCode: 200, responseBody: result };
      },
    );
  }

  @Get("team")
  async team(
    @CurrentUser() user: AuthUser,
    @Query("providerId") providerId?: string,
  ) {
    if (!providerId) {
      if (user.claims.placesInternalOperator) {
        throw new AppError(ErrorCodes.VALIDATION_ERROR, 'providerId required');
      }
      const m = await this.tenancy.requireAny(user.uid, "bookings.view");
      return this.ops.team(user, m.providerId);
    }
    const m = await this.tenancy.require(user, providerId, "bookings.view");
    return this.ops.team(user, m.providerId);
  }
}
