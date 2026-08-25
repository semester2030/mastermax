import {
  Body,
  Controller,
  Get,
  Headers,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Query,
  Req,
  StreamableFile,
} from '@nestjs/common';
import { AuthUser } from '../../../shared/auth/auth-user';
import { CurrentUser } from '../../../shared/auth/auth.decorators';
import { CorrelatedRequest } from '../../../shared/observability/correlation';
import { IdempotencyService } from '../../../shared/idempotency/idempotency.service';
import {
  AvailabilitySearchDto,
  CancelBookingDto,
  ConfirmPayAtVenueDto,
  CreateHoldDto,
  CreatePaymentIntentDto,
  CreateQuoteDto,
  CreateReviewDto,
  FeedQueryDto,
} from '../../../shared/api/dto/common.dto';
import { DiscoverySearchDto } from '../../../shared/api/dto/discovery-search.dto';
import { AvailabilityService } from '../../availability/application/availability.service';
import { QuoteService } from '../../pricing/application/quote.service';
import { HoldService } from '../../booking/application/hold.service';
import { PayAtVenueService } from '../../booking/application/pay-at-venue.service';
import { BookingCancelService } from '../../booking/application/booking-cancel.service';
import { BookingQuery } from '../../booking/application/booking.query';
import { PaymentService } from '../../payments/application/payment.service';
import { ReviewService } from '../../reviews/application/review.service';
import { CatalogService } from '../../catalog/application/catalog.service';
import { FilterEngineService } from '../../filters/application/filter-engine.service';
import { LocationCatalogService } from '../../venues/application/location-catalog.service';
import { AppError } from '../../../shared/errors/app-error';
import { ErrorCodes } from '../../../shared/errors/error-codes';

@Controller('v1')
export class ConsumerController {
  constructor(
    private readonly catalog: CatalogService,
    private readonly filters: FilterEngineService,
    private readonly locations: LocationCatalogService,
    private readonly availability: AvailabilityService,
    private readonly quotes: QuoteService,
    private readonly holds: HoldService,
    private readonly payAtVenue: PayAtVenueService,
    private readonly payments: PaymentService,
    private readonly bookings: BookingQuery,
    private readonly cancels: BookingCancelService,
    private readonly reviews: ReviewService,
    private readonly idem: IdempotencyService,
  ) {}

  @Get('feed')
  feed(@Query() query: FeedQueryDto) {
    return this.catalog.feed({ category: query.category, cursor: query.cursor, city: query.city });
  }

  @Get('venues/:id')
  venue(@Param('id') id: string) {
    return this.catalog.venue(id);
  }

  @Get('venues/:id/gallery')
  gallery(@Param('id') id: string, @Query('inventoryTypeId') inventoryTypeId?: string) {
    return this.catalog.gallery(id, inventoryTypeId);
  }

  /** Canonical filter definitions SSOT (Gate 7A). */
  @Get('filter-definitions')
  filterDefinitions(@Query('venueType') venueType?: string) {
    return this.filters.filterDefinitions(venueType);
  }

  /**
   * Backward-compatible alias for historical Flutter path `/v1/filters/definitions`.
   * Same payload as `GET /v1/filter-definitions`. Prefer the canonical path.
   */
  @Get('filters/definitions')
  filterDefinitionsAlias(@Query('venueType') venueType?: string) {
    return this.filters.filterDefinitions(venueType);
  }

  @Get('amenities')
  amenities(@Query('venueType') venueType?: string) {
    return this.filters.listAmenities(venueType);
  }

  @Get('location/cities')
  locationCities() {
    return this.locations.listCities();
  }

  @Get('location/districts')
  locationDistricts(@Query('cityId') cityId?: string) {
    if (!cityId) {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, 'cityId required');
    }
    return this.locations.listDistricts(cityId);
  }

  @Get('intents')
  intents(@Query('venueType') venueType?: string) {
    return this.filters.listIntents(venueType);
  }

  @Get('venue-types')
  venueTypes() {
    return this.filters.listVenueTypes();
  }

  @Get('discovery/cities')
  discoveryCities(@Query('limit') limit?: string) {
    return this.filters.listCities(limit ? Number(limit) : 100);
  }

  @Get('discovery/districts')
  discoveryDistricts(@Query('city') city: string, @Query('limit') limit?: string) {
    return this.filters.listDistricts(city, limit ? Number(limit) : 100);
  }

  /**
   * Unified discovery search — same FilterRequest for Feed / Map / Circle Rail.
   * Does not replace SKU `POST /v1/availability/search` (booking path).
   */
  @Post('discovery/search')
  discoverySearch(@Body() body: DiscoverySearchDto) {
    return this.filters.search(body);
  }

  @Post('availability/search')
  search(@Body() body: AvailabilitySearchDto) {
    return this.availability.search(body);
  }

  @Post('quotes')
  createQuote(@CurrentUser() user: AuthUser, @Body() body: CreateQuoteDto) {
    return this.quotes.create(user.uid, {
      venueId: body.venueId,
      inventoryTypeId: body.inventoryTypeId,
      checkIn: body.checkIn,
      checkOut: body.checkOut,
      quantity: body.quantity ?? 1,
      guestsAdults: body.guestsAdults ?? 1,
      guestsChildren: body.guestsChildren ?? 0,
      extraIds: body.extraIds ?? [],
      promoCode: body.promoCode,
      slotCode: body.slotCode,
      inventoryUnitId: body.inventoryUnitId,
    });
  }

  @Post('holds')
  async createHold(
    @CurrentUser() user: AuthUser,
    @Req() req: CorrelatedRequest,
    @Headers('idempotency-key') key: string | undefined,
    @Body() body: CreateHoldDto,
  ) {
    const scope = { actorUid: user.uid, httpMethod: 'POST', routePath: '/v1/holds' };
    // F-REV3-05: begin + hold create + save share one transaction.
    return this.idem.runScoped(key, body, true, scope, 24, async (c) => {
      const result = await this.holds.create(
        {
          uid: user.uid,
          quoteId: body.quoteId,
          quantity: body.quantity,
          guestSnapshot: body.guestSnapshot,
          idempotencyKey: key as string,
          correlationId: req.correlationId,
        },
        c,
      );
      return { responseCode: 201, responseBody: result };
    });
  }

  @Post('payments/intents')
  async intent(
    @CurrentUser() user: AuthUser,
    @Req() req: CorrelatedRequest,
    @Headers('idempotency-key') key: string | undefined,
    @Body() body: CreatePaymentIntentDto,
  ) {
    const scope = { actorUid: user.uid, httpMethod: 'POST', routePath: '/v1/payments/intents' };
    // F-REV4-03: claim idempotency row in TX first; createIntent runs its own TXs + PSP
    // outside that claim; response saved in the same scoped TX so concurrent same-key
    // callers serialize and share one paymentId.
    return this.idem.runScoped(key, body, true, scope, 24, async () => {
      const result = await this.payments.createIntent({
        uid: user.uid,
        holdId: body.holdId,
        correlationId: req.correlationId,
      });
      return { responseCode: 201, responseBody: result };
    });
  }

  @Get('payments/:id')
  paymentStatus(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.payments.getForConsumer(user.uid, id);
  }

  @Post('bookings/confirm-pay-at-venue')
  async confirmPayAtVenue(
    @CurrentUser() user: AuthUser,
    @Req() req: CorrelatedRequest,
    @Headers('idempotency-key') key: string | undefined,
    @Body() body: ConfirmPayAtVenueDto,
  ) {
    const scope = {
      actorUid: user.uid,
      httpMethod: 'POST',
      routePath: '/v1/bookings/confirm-pay-at-venue',
    };
    return this.idem.runScoped(key, body, true, scope, 24, async (c) => {
      const result = await this.payAtVenue.confirmInTx(c, {
        uid: user.uid,
        holdId: body.holdId,
        correlationId: req.correlationId,
      });
      return { responseCode: 201, responseBody: result };
    });
  }

  @Get('bookings')
  list(@CurrentUser() user: AuthUser) {
    return this.bookings.listForConsumer(user.uid);
  }

  @Get('bookings/:id')
  one(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.bookings.getForConsumer(user.uid, id);
  }

  @Get('bookings/:id/document')
  async document(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    const booking = (await this.bookings.getForConsumer(user.uid, id)) as {
      document?: unknown;
    };
    if (!booking.document) {
      throw new AppError(ErrorCodes.NOT_FOUND, 'Booking document not issued');
    }
    return booking.document;
  }

  @Get('bookings/:id/document.pdf')
  async documentPdf(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    const pdf = await this.bookings.pdfForConsumer(user.uid, id);
    return new StreamableFile(pdf.bytes, {
      type: 'application/pdf',
      disposition: `attachment; filename="${pdf.fileName}"`,
    });
  }

  @Post('bookings/:id/cancel')
  @HttpCode(HttpStatus.OK)
  async cancel(
    @CurrentUser() user: AuthUser,
    @Req() req: CorrelatedRequest,
    @Param('id') id: string,
    @Headers('idempotency-key') key: string | undefined,
    @Body() body: CancelBookingDto,
  ) {
    const scope = {
      actorUid: user.uid,
      httpMethod: 'POST',
      routePath: '/v1/bookings/:id/cancel',
    };
    return this.idem.runScoped(key, { id, ...body }, true, scope, 24, async (c) => {
      const result = await this.cancels.cancel({
        bookingId: id,
        actorUid: user.uid,
        actorRole: 'consumer',
        reason: body.reason,
        correlationId: req.correlationId,
        client: c,
      });
      return { responseCode: 200, responseBody: result };
    });
  }

  @Post('reviews')
  review(@CurrentUser() user: AuthUser, @Body() body: CreateReviewDto) {
    return this.reviews.create(user.uid, body.bookingId, body.rating, body.body);
  }
}
