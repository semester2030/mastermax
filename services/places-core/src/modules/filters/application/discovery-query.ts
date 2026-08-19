import { DiscoverySearchDto } from '../../../shared/api/dto/discovery-search.dto';
import { AppError } from '../../../shared/errors/app-error';
import { ErrorCodes } from '../../../shared/errors/error-codes';
import {
  stayDatesSqlSeries,
  stayDayOpenUnderRulesSql,
} from '../../../shared/time/stay-dates';
import {
  CursorV2Sort,
  distanceMetersSqlExpr,
  KeysetCursorV2Payload,
} from './discovery-cursor-v2';
import { ResolvedAnchor } from './discovery-anchor';
import { bestScoreSqlExpr } from './discovery-best-score';
import { buildCursorV2Keyset } from './discovery-keyset-v2';
import {
  assertLatLng,
  assertRadiusKm,
  boundsSql,
  normalizeBounds,
  radiusToBbox,
} from './discovery-geo';
import {
  buildSearchPredicate,
  flattenSearchParams,
  normalizeSearchText,
  PhraseMatchPlan,
  searchRankSql,
  TokenMatchPlan,
} from './discovery-search-contract';
import {
  APPROVED_VIDEO_EXISTS,
  DiscoverySurface,
  normalizeSurface,
  requiresApprovedVideo,
} from './discovery-surface';

/** Set-like string arrays: unique + sorted for stable queryHash. */
export function canonicalizeStringSet(values?: string[]): string[] | undefined {
  if (values == null) return undefined;
  const out = [
    ...new Set(
      values
        .map((v) => (typeof v === 'string' ? v.trim() : String(v)))
        .filter((v) => v.length > 0),
    ),
  ].sort((a, b) => a.localeCompare(b));
  return out.length ? out : undefined;
}

export type AvailabilityState = 'AVAILABLE' | 'NOT_AVAILABLE' | 'UNKNOWN';

export type PriceSemantics =
  | 'INDICATIVE_STARTING_PRICE'
  | 'AVAILABILITY_FILTERED_INDICATIVE_PRICE';

/** Approved media marketing hint (no dates) — denormalized on venues (Gate 7B.5.1). */
export const APPROVED_MEDIA_PRICE_HINT = `v.indicative_starting_price`;

/** Haversine km (legacy helper for radius filter comparisons in km). */
export function distanceExpr(latP: number, lngP: number): string {
  return `(
  CASE WHEN v.lat IS NULL OR v.lng IS NULL THEN NULL ELSE
  6371 * acos(LEAST(1, GREATEST(-1,
    cos(radians($${latP})) * cos(radians(v.lat)) *
    cos(radians(v.lng) - radians($${lngP})) +
    sin(radians($${latP})) * sin(radians(v.lat))
  ))) END
)`;
}

/** Proximity sort/select/keyset — identical meters expression (Gate 7B.0.1). */
export function distanceMetersExpr(latP: number, lngP: number): string {
  return distanceMetersSqlExpr(latP, lngP);
}

/**
 * Option A: MIN(base rate) among inventory types that pass occupancy+qty+all nights.
 * Placeholders must match the dated availability params already pushed.
 */
export function eligibleInventoryBasePriceExpr(
  checkInP: number,
  checkOutP: number,
  qtyP: number,
  guestsP: number | null,
): string {
  const guestsClause =
    guestsP != null ? `AND (it.max_occupancy * $${qtyP}::int) >= $${guestsP}` : '';
  return `(
    SELECT MIN(rr.amount)
    FROM inventory_types it
    JOIN rate_plans rp ON rp.inventory_type_id = it.id AND rp.status = 'active' AND rp.is_default = TRUE
    JOIN rate_rules rr ON rr.rate_plan_id = rp.id AND rr.kind = 'base'
    WHERE it.venue_id = v.id AND it.status = 'active'
      AND it.inventory_model = 'pooled'
      AND $${qtyP}::int <= it.quantity_total
      ${guestsClause}
      AND NOT EXISTS (
        SELECT 1
        FROM ${stayDatesSqlSeries(`$${checkInP}`, `$${checkOutP}`, 'v.booking_mode')} d(day)
        LEFT JOIN inventory_daily_capacity idc
          ON idc.inventory_type_id = it.id AND idc.date = d.day::date
        WHERE COALESCE(idc.available, it.quantity_total) < $${qtyP}
           OR NOT ${stayDayOpenUnderRulesSql('it', 'd.day')}
      )
  )`;
}

export interface BuiltDiscoveryQuery {
  whereSql: string;
  whereParams: unknown[];
  orderBySql: string;
  sortParams: unknown[];
  sort: CursorV2Sort;
  surface: DiscoverySurface;
  availabilityMode: AvailabilityState;
  priceSemantics: PriceSemantics;
  priceExpr: string;
  cursorSql: string | null;
  cursorParams: unknown[];
  selectExtras: string;
  originLatParam?: number;
  originLngParam?: number;
  rankingAsOfParam?: number;
  bestScoreExpr?: string;
  searchRankExpr?: string;
}

export interface BuildDiscoveryQueryOpts {
  scopedVenueTypes?: string[];
  anchor?: ResolvedAnchor;
  searchPlans?: TokenMatchPlan[];
  phrasePlans?: PhraseMatchPlan[];
  /** @deprecated prefer phrasePlans */
  phraseVenueTypes?: string[];
  rankingAsOf: string;
  decodedCursor?: KeysetCursorV2Payload | null;
  /** near_place default excludeAnchor=true */
  excludeAnchor?: boolean;
}

export const NEAR_PLACE_DEFAULT_RADIUS_KM = 50;

function boundsFieldCount(raw: DiscoverySearchDto): number {
  return [raw.minLat, raw.maxLat, raw.minLng, raw.maxLng].filter((v) => v != null).length;
}

/**
 * Apply contract defaults BEFORE queryHash (Gate 7B.3.3).
 * Equivalent requests (omitted vs explicit defaults) share one hash where applicable.
 * q is normalized with normalizeSearchText before sort selection.
 * quantity omitted ≠ quantity=1 (Gate 7A quantity filter semantics).
 */
export function applyDiscoveryDefaults(raw: DiscoverySearchDto): DiscoverySearchDto {
  const out: DiscoverySearchDto = { ...raw };
  out.surface = normalizeSurface(out.surface);
  const explicitSort = raw.sort;

  // Normalize q before sort / hash. Empty after diacritics/tatweel → missing.
  if (typeof out.q === 'string') {
    const normalized = normalizeSearchText(out.q);
    if (!normalized) {
      delete out.q;
      // Explicit search_rank with empty q is invalid (before SQL).
      if (explicitSort === 'search_rank') {
        throw new AppError(
          ErrorCodes.VALIDATION_ERROR,
          'q required for sort=search_rank after normalize',
        );
      }
    } else {
      out.q = normalized;
    }
  } else {
    delete out.q;
    if (explicitSort === 'search_rank') {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        'q required for sort=search_rank after normalize',
      );
    }
  }
  const qPresent = typeof out.q === 'string' && out.q.length > 0;

  if (qPresent && (out.sort == null || out.sort === undefined || out.sort === 'best')) {
    out.sort = 'search_rank';
  } else if (out.sort == null || out.sort === undefined) {
    out.sort = 'best';
  }
  // Empty q + missing/best → already sort=best above; never leave search_rank without q.

  if (out.sort === 'near_place') {
    if (out.radiusKm == null) out.radiusKm = NEAR_PLACE_DEFAULT_RADIUS_KM;
    if (out.sameTypeOnly == null) out.sameTypeOnly = true;
    delete out.lat;
    delete out.lng;
    delete out.minLat;
    delete out.maxLat;
    delete out.minLng;
    delete out.maxLng;
  }

  if (out.limit == null) out.limit = 20;
  // Do NOT default quantity — omitted means no quantity filter (Gate 7A / 7B.3.3).

  const amenities = canonicalizeStringSet(out.amenities);
  if (amenities) out.amenities = amenities;
  else delete out.amenities;

  // rankingAsOf is server-owned — never take client value into canonical defaults
  delete (out as Record<string, unknown>).rankingAsOf;
  delete out.cursor;
  return out;
}

export function assertDiscoveryLimits(raw: DiscoverySearchDto): void {
  if (
    Object.prototype.hasOwnProperty.call(raw, 'rankingAsOf') &&
    (raw as Record<string, unknown>).rankingAsOf != null
  ) {
    throw new AppError(
      ErrorCodes.VALIDATION_ERROR,
      'rankingAsOf is server-owned; do not send in request body',
    );
  }
  if (raw.amenities && raw.amenities.length > 40) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'amenities max 40');
  }
  if (raw.minPrice != null && raw.maxPrice != null && raw.minPrice > raw.maxPrice) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'minPrice > maxPrice');
  }
  if (raw.sizeSqmMin != null && raw.sizeSqmMax != null && raw.sizeSqmMin > raw.sizeSqmMax) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'sizeSqmMin > sizeSqmMax');
  }
  const nBounds = boundsFieldCount(raw);
  if (nBounds > 0 && nBounds < 4) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'partial bounds not allowed');
  }

  if (raw.sort === 'near_me') {
    if (raw.anchorVenueId) {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, 'sort=near_me forbids anchorVenueId');
    }
    if (raw.lat == null || raw.lng == null) {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, 'sort=near_me requires lat/lng');
    }
    assertLatLng(raw.lat, raw.lng);
  }

  if (raw.sort === 'near_place') {
    if (!raw.anchorVenueId) {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, 'sort=near_place requires anchorVenueId');
    }
    if (raw.lat != null || raw.lng != null) {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, 'sort=near_place forbids client lat/lng');
    }
    if (nBounds > 0) {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, 'sort=near_place forbids bounds');
    }
  }

  if (raw.radiusKm != null && nBounds === 4) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'radiusKm and bounds are mutually exclusive');
  }
  if (raw.radiusKm != null) {
    if (raw.sort === 'near_place' && raw.anchorVenueId) {
      // origin lat validated after anchor resolve
      assertFiniteRadiusOnly(raw.radiusKm);
    } else if (raw.lat == null || raw.lng == null) {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, 'radiusKm requires lat/lng');
    } else {
      assertLatLng(raw.lat, raw.lng);
      assertRadiusKm(raw.radiusKm, raw.lat);
    }
  }
  if (nBounds === 4) {
    normalizeBounds({
      minLat: raw.minLat!,
      maxLat: raw.maxLat!,
      minLng: raw.minLng!,
      maxLng: raw.maxLng!,
    });
  }
  // Date / slot composition — YYYY-MM-DD only; reject timestamps / inverted / partial (Gate 7B.3.5).
  // Same-day (checkIn == checkOut) allowed for daily discovery filter; nightly quote/hold still uses stayDates.
  const hasCheckIn = raw.checkIn != null && String(raw.checkIn).length > 0;
  const hasCheckOut = raw.checkOut != null && String(raw.checkOut).length > 0;
  const hasSlot = raw.slotCode != null && String(raw.slotCode).length > 0;
  if (hasCheckIn) assertIsoCalendarDate(String(raw.checkIn), 'checkIn');
  if (hasCheckOut) assertIsoCalendarDate(String(raw.checkOut), 'checkOut');
  if (hasSlot && !hasCheckIn) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'slotCode requires checkIn');
  }
  if (hasSlot && hasCheckOut) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'slotCode forbids checkOut');
  }
  if (hasCheckIn && !hasCheckOut && !hasSlot) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'checkIn requires checkOut or slotCode');
  }
  if (hasCheckOut && !hasCheckIn) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'checkOut requires checkIn');
  }
  if (hasSlot && raw.quantity != null) {
    throw new AppError(
      ErrorCodes.VALIDATION_ERROR,
      'explicit quantity forbidden with event slot until event booking gate',
    );
  }
  if (hasCheckIn && hasCheckOut && !hasSlot) {
    // Allow equal (daily same-day); reject only inverted checkIn > checkOut.
    if (raw.checkIn! > raw.checkOut!) {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        'checkIn must be on or before checkOut (inverted forbidden)',
      );
    }
  }
  if (raw.sort === 'search_rank' && !(raw.q && raw.q.trim())) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'sort=search_rank requires q');
  }
  if (raw.sameTypeOnly === true && !raw.anchorVenueId && raw.sort !== 'near_place') {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'sameTypeOnly requires anchorVenueId');
  }
  if (raw.surface && !['feed', 'map', 'circle', 'search'].includes(raw.surface)) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'invalid surface');
  }
}

function assertFiniteRadiusOnly(radiusKm: number): void {
  if (!Number.isFinite(radiusKm)) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'invalid radiusKm');
  }
  if (radiusKm < 0.1 || radiusKm > 200) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'radiusKm out of range');
  }
}

const ISO_DATE_ONLY_RE = /^\d{4}-\d{2}-\d{2}$/;

/** Reject timestamps and non-existent calendar days before SQL (Gate 7B.3.5). */
export function assertIsoCalendarDate(value: string, field: string): void {
  if (!ISO_DATE_ONLY_RE.test(value)) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, `${field} must be YYYY-MM-DD`);
  }
  const [y, m, d] = value.split('-').map(Number);
  const dt = new Date(Date.UTC(y, m - 1, d));
  if (
    dt.getUTCFullYear() !== y ||
    dt.getUTCMonth() !== m - 1 ||
    dt.getUTCDate() !== d
  ) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, `${field} is not a real calendar date`);
  }
}

export function buildDiscoveryQuery(
  resolved: DiscoverySearchDto,
  opts: BuildDiscoveryQueryOpts,
): BuiltDiscoveryQuery {
  const surface = normalizeSurface(resolved.surface);
  const whereParams: unknown[] = [];
  const where: string[] = [`v.status = 'published'`];
  where.push(`EXISTS (
    SELECT 1 FROM venue_type_capabilities c
    WHERE c.venue_type = v.venue_type AND c.enabled_for_discovery = TRUE
  )`);
  // F-V2-012 partial (Discovery boundary): suspended providers never surface.
  where.push(`EXISTS (
    SELECT 1 FROM providers p
    WHERE p.id = v.provider_id AND p.status = 'active'
  )`);

  if (requiresApprovedVideo(surface)) {
    where.push(APPROVED_VIDEO_EXISTS);
  }

  const push = (v: unknown) => {
    whereParams.push(v);
    return whereParams.length;
  };

  if (resolved.category) where.push(`v.venue_type = $${push(resolved.category)}`);
  else if (opts.scopedVenueTypes?.length) {
    const p = push(opts.scopedVenueTypes);
    where.push(`v.venue_type = ANY($${p}::text[])`);
  }

  if (resolved.city) where.push(`v.city = $${push(resolved.city)}`);
  if (resolved.district) where.push(`v.district = $${push(resolved.district)}`);
  if (resolved.verified === true) where.push(`v.verified = TRUE`);
  if (resolved.offers === true) where.push(`v.has_active_offer = TRUE`);
  if (resolved.starsMin != null) {
    where.push(`v.stars IS NOT NULL AND v.stars >= $${push(resolved.starsMin)}`);
  }
  if (resolved.minRating != null) {
    where.push(`v.reviews_count > 0 AND v.rating_average >= $${push(resolved.minRating)}`);
  }
  if (resolved.bedroomsMin != null) {
    where.push(`v.bedrooms IS NOT NULL AND v.bedrooms >= $${push(resolved.bedroomsMin)}`);
  }
  if (resolved.bathroomsMin != null) {
    where.push(`v.bathrooms IS NOT NULL AND v.bathrooms >= $${push(resolved.bathroomsMin)}`);
  }
  if (resolved.sizeSqmMin != null) {
    where.push(`v.size_sqm IS NOT NULL AND v.size_sqm >= $${push(resolved.sizeSqmMin)}`);
  }
  if (resolved.sizeSqmMax != null) {
    where.push(`v.size_sqm IS NOT NULL AND v.size_sqm <= $${push(resolved.sizeSqmMax)}`);
  }
  if (resolved.hallType) {
    where.push(`v.attributes_jsonb->>'hall_type' = $${push(resolved.hallType)}`);
  }
  if (resolved.inventoryKind) {
    where.push(`v.attributes_jsonb->>'inventory_kind' = $${push(resolved.inventoryKind)}`);
  }
  if (resolved.cancellation) {
    where.push(
      `COALESCE(v.cancellation_policy_json->>'tier', 'moderate') = $${push(resolved.cancellation)}`,
    );
  }

  for (const code of [...new Set(resolved.amenities ?? [])]) {
    where.push(`EXISTS (
      SELECT 1 FROM venue_amenity_links l
      WHERE l.venue_id = v.id AND l.amenity_code = $${push(code)} AND l.state = 'AVAILABLE'
    )`);
  }

  // Geo: near_place uses Anchor ONLY (no client hybrid origin).
  const isNearPlace = resolved.sort === 'near_place';
  const radiusLat = isNearPlace ? opts.anchor?.lat : resolved.lat;
  const radiusLng = isNearPlace ? opts.anchor?.lng : resolved.lng;

  if (radiusLat != null && radiusLng != null && resolved.radiusKm != null) {
    const r = resolved.radiusKm;
    assertRadiusKm(r, radiusLat);
    const norm = radiusToBbox(radiusLat, radiusLng, r);
    const startP = whereParams.length + 1;
    const { sql: boxSql, params: boxParams } = boundsSql(norm.boxes, startP);
    for (const p of boxParams) push(p);
    const pLat = push(radiusLat);
    const pLng = push(radiusLng);
    const pR = push(r);
    where.push(`v.lat IS NOT NULL AND v.lng IS NOT NULL`);
    where.push(boxSql);
    where.push(`${distanceExpr(pLat, pLng)} <= $${pR}`);
  } else if (
    !isNearPlace &&
    resolved.minLat != null &&
    resolved.maxLat != null &&
    resolved.minLng != null &&
    resolved.maxLng != null
  ) {
    const norm = normalizeBounds({
      minLat: resolved.minLat,
      maxLat: resolved.maxLat,
      minLng: resolved.minLng,
      maxLng: resolved.maxLng,
    });
    const startP = whereParams.length + 1;
    const { sql: boxSql, params: boxParams } = boundsSql(norm.boxes, startP);
    for (const p of boxParams) push(p);
    where.push(`v.lat IS NOT NULL AND v.lng IS NOT NULL`);
    where.push(boxSql);
  }

  if (opts.anchor) {
    const exclude = opts.excludeAnchor !== false;
    if (exclude) {
      where.push(`v.id <> $${push(opts.anchor.id)}`);
    }
    if (resolved.sameTypeOnly === true) {
      where.push(`v.venue_type = $${push(opts.anchor.venueType)}`);
    }
  }

  const plans = opts.searchPlans ?? [];
  const realPhrases = opts.phrasePlans ?? [];
  if (plans.length > 0 || realPhrases.length > 0) {
    const startP = whereParams.length + 1;
    const pred = buildSearchPredicate(plans.length, realPhrases.length, startP);
    for (const p of flattenSearchParams(plans, realPhrases)) push(p);
    where.push(pred.sql);
  }

  const guests = resolved.guests ?? null;
  const capacityMin = resolved.capacityMin ?? null;
  const capacityNeed =
    guests != null || capacityMin != null
      ? Math.max(guests ?? 0, capacityMin ?? 0)
      : null;
  const explicitQty = resolved.quantity != null ? Number(resolved.quantity) : null;

  let availabilityMode: AvailabilityState = 'UNKNOWN';
  let priceSemantics: PriceSemantics = 'INDICATIVE_STARTING_PRICE';
  let priceExpr = APPROVED_MEDIA_PRICE_HINT;
  let datedCheckInP: number | null = null;
  let datedCheckOutP: number | null = null;
  let datedQtyP: number | null = null;
  let datedNeedP: number | null = null;

  if (resolved.checkIn && resolved.slotCode) {
    // Event slot path — capacity on slot; explicit quantity already rejected in limits
    availabilityMode = 'AVAILABLE';
    const d = push(resolved.checkIn);
    const s = push(resolved.slotCode);
    let capClause = '';
    if (capacityNeed != null) {
      const capP = push(capacityNeed);
      capClause = `AND COALESCE(est.capacity, v.capacity, 0) >= $${capP}`;
    }
    where.push(`EXISTS (
      SELECT 1 FROM event_slot_inventory esi
      JOIN event_slot_templates est ON est.id = esi.slot_template_id
      WHERE esi.venue_id = v.id
        AND est.venue_id = v.id
        AND est.venue_id = esi.venue_id
        AND esi.slot_date = $${d}::date
        AND est.code = $${s}
        AND esi.status = 'open'
        AND est.status = 'active'
        ${capClause}
    )`);
    priceSemantics = 'INDICATIVE_STARTING_PRICE';
    priceExpr = APPROVED_MEDIA_PRICE_HINT;
  } else if (resolved.checkIn && resolved.checkOut) {
    // Nightly: one Active Inventory Type satisfies qty + capacity + all nights
    availabilityMode = 'AVAILABLE';
    const qty = explicitQty ?? 1;
    datedCheckInP = push(resolved.checkIn);
    datedCheckOutP = push(resolved.checkOut);
    datedQtyP = push(qty);
    let needClause = '';
    if (capacityNeed != null) {
      datedNeedP = push(capacityNeed);
      needClause = `AND (it.max_occupancy * $${datedQtyP}::int) >= $${datedNeedP}`;
    }
    where.push(`EXISTS (
      SELECT 1 FROM inventory_types it
      WHERE it.venue_id = v.id AND it.status = 'active'
        AND it.inventory_model = 'pooled'
        AND $${datedQtyP}::int <= it.quantity_total
        ${needClause}
        AND NOT EXISTS (
          SELECT 1
          FROM ${stayDatesSqlSeries(`$${datedCheckInP}`, `$${datedCheckOutP}`, 'v.booking_mode')} d(day)
          LEFT JOIN inventory_daily_capacity idc
            ON idc.inventory_type_id = it.id AND idc.date = d.day::date
          WHERE COALESCE(idc.available, it.quantity_total) < $${datedQtyP}
             OR NOT ${stayDayOpenUnderRulesSql('it', 'd.day')}
        )
    )`);
    // F-V2-007: a nightly stay requires at least one night (checkIn < checkOut).
    // Same-day (checkIn == checkOut) is valid only for daily; nightly venues must
    // not surface as AVAILABLE for a zero-night range.
    where.push(
      `(v.booking_mode <> 'nightly' OR $${datedCheckInP}::date < $${datedCheckOutP}::date)`,
    );
    priceSemantics = 'AVAILABILITY_FILTERED_INDICATIVE_PRICE';
    priceExpr = eligibleInventoryBasePriceExpr(
      datedCheckInP,
      datedCheckOutP,
      datedQtyP,
      datedNeedP,
    );
  } else if (explicitQty != null || capacityNeed != null) {
    // Undated composition (Gate 7B.3.4)
    if (explicitQty != null) {
      // Explicit quantity: same Active Inventory Type only — no v.capacity bypass
      const qtyP = push(explicitQty);
      let needClause = '';
      if (capacityNeed != null) {
        const nP = push(capacityNeed);
        needClause = `AND (it.max_occupancy * $${qtyP}::int) >= $${nP}`;
      }
      where.push(`EXISTS (
        SELECT 1 FROM inventory_types it
        WHERE it.venue_id = v.id AND it.status = 'active'
          AND it.quantity_total >= $${qtyP}::int
          ${needClause}
      )`);
    } else {
      // No quantity: max(guests, capacityMin) on venue capacity OR active inventory occupancy
      const nP = push(capacityNeed!);
      where.push(`(
        (v.capacity IS NOT NULL AND v.capacity >= $${nP})
        OR EXISTS (
          SELECT 1 FROM inventory_types it
          WHERE it.venue_id = v.id AND it.status = 'active'
            AND it.max_occupancy >= $${nP}
        )
      )`);
    }
  }

  if (resolved.minPrice != null) {
    const p = push(resolved.minPrice);
    where.push(`${priceExpr} IS NOT NULL AND ${priceExpr} >= $${p}`);
  }
  if (resolved.maxPrice != null) {
    const p = push(resolved.maxPrice);
    where.push(`${priceExpr} IS NOT NULL AND ${priceExpr} <= $${p}`);
  }

  const sort = (resolved.sort ?? 'best') as CursorV2Sort;
  // SELECT/ORDER binds only — never mixed into COUNT whereParams.
  const sortParams: unknown[] = [];
  sortParams.push(opts.rankingAsOf);
  const rankingAsOfParam = whereParams.length + 1;
  const bestScoreExpr = bestScoreSqlExpr(rankingAsOfParam);

  let orderBySql = `${bestScoreExpr} DESC NULLS LAST, v.weighted_rating DESC NULLS LAST, v.reviews_count DESC, v.id ASC`;
  let selectExtras = `${priceExpr} AS starting_price_hint, NULL::bigint AS distance_meters, ${bestScoreExpr} AS best_score, NULL::numeric AS text_rank`;
  let originLatParam: number | undefined;
  let originLngParam: number | undefined;
  let searchRankExpr: string | undefined;

  if (sort === 'cheapest') {
    orderBySql = `${priceExpr} ASC NULLS LAST, v.id ASC`;
  } else if (sort === 'most_expensive') {
    orderBySql = `${priceExpr} DESC NULLS LAST, v.id ASC`;
  } else if (sort === 'rating') {
    orderBySql = 'v.weighted_rating DESC NULLS LAST, v.reviews_count DESC, v.id ASC';
  } else if (sort === 'newest') {
    orderBySql = "date_trunc('milliseconds', v.created_at) DESC NULLS LAST, v.id ASC";
  } else if (sort === 'near_me' || sort === 'near_place') {
    const oLat = sort === 'near_place' ? opts.anchor!.lat : resolved.lat!;
    const oLng = sort === 'near_place' ? opts.anchor!.lng : resolved.lng!;
    sortParams.push(oLat, oLng);
    originLatParam = whereParams.length + 2;
    originLngParam = whereParams.length + 3;
    const distM = distanceMetersExpr(originLatParam, originLngParam);
    selectExtras = `${priceExpr} AS starting_price_hint, ${distM} AS distance_meters, ${bestScoreExpr} AS best_score, NULL::numeric AS text_rank`;
    orderBySql = `${distM} ASC NULLS LAST, v.id ASC`;
  } else if (sort === 'best') {
    orderBySql = `${bestScoreExpr} DESC NULLS LAST, v.weighted_rating DESC NULLS LAST, v.reviews_count DESC, v.id ASC`;
  } else if (sort === 'search_rank') {
    const rankTokens = [
      ...plans.map((p) => p.raw),
      ...(opts.phrasePlans ?? []).map((p) => p.raw),
    ];
    sortParams.push(rankTokens);
    const rawArrP = whereParams.length + sortParams.length;
    searchRankExpr = searchRankSql(rawArrP);
    selectExtras = `${priceExpr} AS starting_price_hint, NULL::bigint AS distance_meters, ${bestScoreExpr} AS best_score, ${searchRankExpr} AS text_rank`;
    orderBySql = `${searchRankExpr} DESC NULLS LAST, ${bestScoreExpr} DESC NULLS LAST, v.id ASC`;
  }

  let cursorSql: string | null = null;
  const cursorParams: unknown[] = [];
  if (opts.decodedCursor) {
    const built = buildCursorV2Keyset({
      sort,
      cur: opts.decodedCursor,
      priorCount: whereParams.length + sortParams.length,
      priceExpr,
      distLatParam: originLatParam,
      distLngParam: originLngParam,
      bestScoreExpr,
      searchRankExpr,
    });
    cursorSql = built.sql;
    cursorParams.push(...built.params);
  }

  return {
    whereSql: where.join(' AND '),
    whereParams,
    orderBySql,
    sortParams,
    sort,
    surface,
    availabilityMode,
    priceSemantics,
    priceExpr,
    cursorSql,
    cursorParams,
    selectExtras,
    originLatParam,
    originLngParam,
    rankingAsOfParam,
    bestScoreExpr,
    searchRankExpr,
  };
}


