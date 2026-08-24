import { Type } from "class-transformer";
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsDateString,
  IsIn,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Matches,
  Max,
  MaxLength,
  Min,
  MinLength,
} from "class-validator";

const MONEY = /^\d+(\.\d{1,2})?$/;

export class AvailabilitySearchDto {
  @IsUUID()
  venueId!: string;

  @IsUUID()
  inventoryTypeId!: string;

  @IsDateString()
  checkIn!: string;

  @IsDateString()
  checkOut!: string;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  quantity!: number;
}

export class CreateQuoteDto {
  @IsUUID()
  venueId!: string;

  @IsUUID()
  inventoryTypeId!: string;

  @IsDateString()
  checkIn!: string;

  @IsDateString()
  checkOut!: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  quantity?: number;

  @IsOptional()
  @IsUUID()
  inventoryUnitId?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(50)
  guestsAdults?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(50)
  guestsChildren?: number;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(20)
  @IsUUID("4", { each: true })
  extraIds?: string[];

  @IsOptional()
  @IsString()
  @MaxLength(64)
  promoCode?: string;

  /** Required when venue.booking_mode = event_slot; forbidden otherwise. */
  @IsOptional()
  @IsString()
  @MaxLength(64)
  @Matches(/^[a-zA-Z0-9_-]+$/)
  slotCode?: string;
}

export class CreateHoldDto {
  @IsUUID()
  quoteId!: string;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  quantity!: number;
}

export class CreatePaymentIntentDto {
  @IsUUID()
  holdId!: string;
}

export class ConfirmPayAtVenueDto {
  @IsUUID()
  holdId!: string;
}

export class CancelBookingDto {
  @IsString()
  @MinLength(1)
  @MaxLength(500)
  reason!: string;
}

export class PavCollectAtVenueDto {
  @IsString()
  @MinLength(1)
  amount!: string;

  @IsOptional()
  @IsString()
  @MaxLength(3)
  currency?: string;
}

export class PavBookingActionDto {
  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;
}

export class CreateReviewDto {
  @IsUUID()
  bookingId!: string;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(5)
  rating!: number;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  body?: string;
}

export class CreateVenueDto {
  @IsUUID()
  providerId!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(200)
  name!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(64)
  venueType!: string;

  @IsIn(["nightly", "daily", "event_slot"])
  bookingMode!: "nightly" | "daily" | "event_slot";

  @IsOptional()
  @IsString()
  @MaxLength(100)
  city?: string;
}

export class PatchVenueDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(200)
  name?: string;

  @IsOptional()
  @IsIn(["draft", "published", "suspended"])
  status?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  city?: string;

  @IsOptional()
  @IsUUID("all")
  cityId?: string;

  @IsOptional()
  @IsUUID("all")
  districtId?: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(200)
  street?: string;

  @IsOptional()
  @IsString()
  @MaxLength(32)
  buildingNo?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  landmark?: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  accessNotes?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  mapsUrl?: string;

  @IsOptional()
  @IsIn(["manual", "geolocation", "search", "pin"])
  locationSource?: "manual" | "geolocation" | "search" | "pin";

  @IsOptional()
  @Type(() => Number)
  lat?: number;

  @IsOptional()
  @Type(() => Number)
  lng?: number;
}

export class PutVenueAmenitiesDto {
  @IsUUID("all")
  venueId!: string;

  @IsOptional()
  @IsUUID("all")
  inventoryTypeId?: string;

  @IsArray()
  @ArrayMaxSize(80)
  @IsString({ each: true })
  codes!: string[];
}

export class ProviderAvailabilityDto {
  @IsUUID()
  inventoryTypeId!: string;

  @IsDateString()
  date!: string;

  @IsIn(["block", "open", "maintenance"])
  kind!: "block" | "open" | "maintenance";

  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;
}

export class ProviderPricingDto {
  @IsUUID()
  ratePlanId!: string;

  @IsString()
  @MaxLength(32)
  kind!: string;

  @Matches(MONEY)
  amount!: string;

  @IsOptional()
  @IsDateString()
  dateFrom?: string;

  @IsOptional()
  @IsDateString()
  dateTo?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(1000)
  priority?: number;
}

export class RegisterMediaDto {
  @IsUUID()
  venueId!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(200)
  streamUid!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(64)
  purpose!: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  coverUrl?: string;
}

/** Provider Web — image gallery metadata (max 30 enforced in DB). Requires CF id. */
export class RegisterImageMediaDto {
  @IsUUID()
  venueId!: string;

  @IsString()
  @MinLength(8)
  @MaxLength(2000)
  url!: string;

  @IsString()
  @MinLength(4)
  @MaxLength(200)
  cloudflareImageId!: string;

  @IsOptional()
  @IsUUID()
  inventoryTypeId?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(29)
  sortOrder?: number;

  @IsOptional()
  @IsBoolean()
  isCover?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  purpose?: string;
}

export class CreateImageUploadSessionDto {
  @IsUUID()
  venueId!: string;

  @IsOptional()
  @IsUUID()
  inventoryTypeId?: string;
}

export class CompleteImageUploadDto {
  @IsUUID()
  uploadSessionId!: string;

  @IsString()
  @MinLength(4)
  @MaxLength(200)
  cloudflareImageId!: string;

  @IsOptional()
  @IsUUID()
  inventoryTypeId?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(29)
  sortOrder?: number;

  @IsOptional()
  @IsBoolean()
  isCover?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  purpose?: string;
}

export class CreateStreamUploadSessionDto {
  @IsUUID()
  venueId!: string;

  @IsOptional()
  @IsUUID("all")
  inventoryTypeId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  title?: string;
}

export class CompleteStreamUploadDto {
  @IsUUID()
  uploadSessionId!: string;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  purpose?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  coverUrl?: string;
}

export class ModerateMediaDto {
  @IsIn(['approved', 'rejected'])
  moderationStatus!: 'approved' | 'rejected';

  /** Optimistic concurrency — must match venue_media.cas_version. */
  @IsInt()
  @Min(0)
  expectedCasVersion!: number;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  rejectionReason?: string;
}


export class ReorderMediaDto {
  @IsUUID()
  venueId!: string;

  @IsOptional()
  @IsUUID()
  inventoryTypeId?: string;

  @IsArray()
  @ArrayMaxSize(30)
  @IsUUID("all", { each: true })
  orderedMediaIds!: string[];

  /** Parallel CAS versions for each orderedMediaIds entry. */
  @IsArray()
  @ArrayMaxSize(30)
  @IsInt({ each: true })
  expectedCasVersions!: number[];
}

export class MediaCasDto {
  @IsInt()
  @Min(0)
  expectedCasVersion!: number;
}

export class CreateSettlementDto {
  @IsUUID()
  providerId!: string;

  @IsDateString()
  periodStart!: string;

  @IsDateString()
  periodEnd!: string;
}

export class CreateRefundDto {
  @IsUUID()
  bookingId!: string;

  @IsOptional()
  @Matches(MONEY)
  amount?: string;

  @IsString()
  @MinLength(1)
  @MaxLength(500)
  reason!: string;

  @IsOptional()
  @IsIn(["operational", "partial", "full"])
  kind?: "operational" | "partial" | "full";
}

export class AdminVenueStatusDto {
  @IsIn(["draft", "published", "suspended"])
  status!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(500)
  reason!: string;
}

export class AdminProviderStatusDto {
  @IsIn(["pending", "active", "suspended", "rejected"])
  status!: "pending" | "active" | "suspended" | "rejected";

  @IsString()
  @MinLength(1)
  @MaxLength(500)
  reason!: string;
}

export class PaginationQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(200)
  limit?: number;
}

export class FeedQueryDto {
  @IsOptional()
  @IsString()
  @MaxLength(64)
  category?: string;

  /** Must accept worst-case Cursor v2 with diversity state (DISCOVERY_CURSOR_MAX_LENGTH). */
  @IsOptional()
  @IsString()
  @MaxLength(4096)
  cursor?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  city?: string;
}

/** Webhook body is validated by PaymentPort.parseWebhook after signature check. */
export class StubWebhookDto {
  @IsString()
  @MinLength(1)
  @MaxLength(200)
  eventId!: string;

  @IsIn(["payment.succeeded", "payment.failed", "refund.completed"])
  type!: string;

  @IsString()
  @MinLength(1)
  @MaxLength(200)
  pspIntentId!: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  refundId?: string;

  @IsOptional()
  @IsNumber()
  ts?: number;
}
