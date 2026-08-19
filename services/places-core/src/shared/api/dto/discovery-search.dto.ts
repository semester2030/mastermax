import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsIn,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

/** Strict calendar date only — rejects timestamps (Gate 7B.3.5). */
const ISO_DATE_ONLY = /^\d{4}-\d{2}-\d{2}$/;

/** Unified discovery filter request — Feed / Map / Circle Rail / Search. */
export class DiscoverySearchDto {
  @IsOptional()
  @IsIn(['feed', 'map', 'circle', 'search'])
  surface?: 'feed' | 'map' | 'circle' | 'search';

  @IsOptional()
  @IsString()
  @MaxLength(64)
  category?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  city?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  district?: string;

  @IsOptional()
  @IsString()
  @Matches(ISO_DATE_ONLY, { message: 'checkIn must be YYYY-MM-DD' })
  checkIn?: string;

  @IsOptional()
  @IsString()
  @Matches(ISO_DATE_ONLY, { message: 'checkOut must be YYYY-MM-DD' })
  checkOut?: string;

  @IsOptional()
  @IsString()
  @MaxLength(32)
  slotCode?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(200)
  guests?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  quantity?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  @Max(1_000_000)
  minPrice?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  @Max(1_000_000)
  maxPrice?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(1)
  @Max(5)
  minRating?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(5)
  starsMin?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(50)
  bedroomsMin?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(50)
  bathroomsMin?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(5000)
  capacityMin?: number;

  @IsOptional()
  @IsBoolean()
  verified?: boolean;

  @IsOptional()
  @IsBoolean()
  offers?: boolean;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(40)
  @IsString({ each: true })
  @MaxLength(64, { each: true })
  amenities?: string[];

  @IsOptional()
  @IsString()
  @MaxLength(64)
  intent?: string;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  hallType?: string;

  @IsOptional()
  @IsString()
  @MaxLength(64)
  inventoryKind?: string;

  @IsOptional()
  @IsString()
  @MaxLength(32)
  cancellation?: string;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(-90)
  @Max(90)
  lat?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(-180)
  @Max(180)
  lng?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0.1)
  @Max(200)
  radiusKm?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(-90)
  @Max(90)
  minLat?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(-90)
  @Max(90)
  maxLat?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(-180)
  @Max(180)
  minLng?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(-180)
  @Max(180)
  maxLng?: number;

  @IsOptional()
  @IsIn([
    'best',
    'rating',
    'cheapest',
    'most_expensive',
    'newest',
    'near_me',
    'near_place',
    'search_rank',
  ])
  sort?: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  q?: string;

  @IsOptional()
  @IsString()
  @MaxLength(36)
  anchorVenueId?: string;

  @IsOptional()
  @IsBoolean()
  sameTypeOnly?: boolean;

  @IsOptional()
  @IsString()
  /** Gate 7B.0.1: must fit worst server-issued Cursor v2 (best + diversity state). */
  @MaxLength(4096)
  cursor?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  @Max(1_000_000)
  sizeSqmMin?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  @Max(1_000_000)
  sizeSqmMax?: number;

  @IsOptional()
  @IsBoolean()
  includeFacets?: boolean;
}
