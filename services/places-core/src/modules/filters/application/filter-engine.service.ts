import { Injectable } from '@nestjs/common';
import { PgService } from '../../../shared/database/pg.service';
import { DiscoverySearchDto } from '../../../shared/api/dto/discovery-search.dto';
import { AppError } from '../../../shared/errors/app-error';
import { ErrorCodes } from '../../../shared/errors/error-codes';
import { resolveNearPlaceAnchor, ResolvedAnchor } from './discovery-anchor';
import {
  assertCursorV2Context,
  assertCursorV2PreflightSortEpoch,
  assertRankingAsOfFresh,
  buildQueryHash,
  canonicalizeResolvedDto,
  CursorV2Sort,
  DIVERSITY_K_DEFAULT,
  DIVERSITY_VERSION_CURRENT,
  KeysetCursorV2Payload,
  parseCursorV2Structural,
  RANKING_EPOCH_CURRENT,
} from './discovery-cursor-v2';
import {
  cursorV2FromRow,
  normalizeRankingAsOf,
} from './discovery-cursor-encode';
import {
  resolveStreamUrl,
} from './discovery-surface';
import {
  applyDiscoveryDefaults,
  assertDiscoveryLimits,
  buildDiscoveryQuery,
} from './discovery-query';
import { assertRadiusKm } from './discovery-geo';
import {
  LabelPhrase,
  PhraseMatchPlan,
  planSearchTokens,
  prepareSearchQuery,
  TokenMatchPlan,
} from './discovery-search-contract';
import { isHandlerRegistered } from './filter-handler-registry';
import { resolveIntent } from './intent-resolver';
import { VenueTypeCapabilityPolicy } from './venue-type-capability.policy';
import {
  diversityAppliedMeta,
  resolveAppliedProfile,
  resolveDiversityPolicy,
} from './discovery-diversity-policy';
import {
  runMixedFeedDiversityPage,
  typeAfterAsCursorPayload,
} from './discovery-diversity-runtime';
import { emptyDiversityState } from './discovery-diversity';
import { discoveryPageSql } from './discovery-page-sql';
import {
  getPgRequestProbe,
  withPgRequestProbe,
} from '../../../shared/database/pg-request-probe';

export type AvailabilityState = 'AVAILABLE' | 'NOT_AVAILABLE' | 'UNKNOWN';

export interface DiscoverySearchResult {
  items: Record<string, unknown>[];
  nextCursor: string | null;
  total: number;
  applied: Record<string, unknown>;
  sort: string;
  capabilities: {
    facetCounts: 'supported' | 'deferred';
    geo: 'partial';
    weddingEventBooking: 'BOOKING_NOT_READY';
  };
}

@Injectable()
export class FilterEngineService {
  constructor(
    private readonly pg: PgService,
    private readonly caps: VenueTypeCapabilityPolicy,
  ) {}

  async listVenueTypes(): Promise<unknown[]> {
    const res = await this.pg.query(
      `SELECT venue_type, label_ar, label_en, enabled_for_discovery, enabled_for_booking,
              enabled_for_provider, enabled_for_admin, booking_semantics, sort_order
       FROM venue_type_capabilities
       ORDER BY sort_order`,
    );
    return res.rows.map((r) => ({
      ...r,
      discoveryStatus: r.enabled_for_discovery ? 'DISCOVERY_READY' : 'DISCOVERY_DISABLED',
      bookingStatus: r.enabled_for_booking ? 'BOOKING_READY' : 'BOOKING_NOT_READY',
    }));
  }

  async listAmenities(venueType?: string): Promise<unknown[]> {
    const res = await this.pg.query(
      `SELECT code, label_ar, label_en, icon_key, applicable_venue_types, filterable,
              display_only, availability_mode, parent_code, sort_order, status
       FROM amenity_catalog
       WHERE status = 'active'
         AND (
           $1::text IS NULL
           OR applicable_venue_types @> ARRAY['*']::text[]
           OR applicable_venue_types @> ARRAY[$1]::text[]
         )
       ORDER BY sort_order, code`,
      [venueType ?? null],
    );
    return res.rows;
  }

  async listIntents(venueType?: string): Promise<unknown[]> {
    const res = await this.pg.query(
      `SELECT code, label_ar, label_en, applicable_venue_types, expands_to_jsonb, sort_order
       FROM intent_presets
       WHERE status = 'active'
         AND (
           $1::text IS NULL
           OR applicable_venue_types @> ARRAY['*']::text[]
           OR applicable_venue_types @> ARRAY[$1]::text[]
         )
       ORDER BY sort_order`,
      [venueType ?? null],
    );
    return res.rows;
  }

  async listCities(limit = 100): Promise<{ cities: string[] }> {
    const res = await this.pg.query<{ city: string }>(
      `SELECT DISTINCT v.city
       FROM venues v
       JOIN venue_type_capabilities c ON c.venue_type = v.venue_type AND c.enabled_for_discovery
       WHERE v.status = 'published' AND v.city IS NOT NULL AND trim(v.city) <> ''
       ORDER BY v.city
       LIMIT $1`,
      [Math.min(Math.max(limit, 1), 200)],
    );
    return { cities: res.rows.map((r) => r.city) };
  }

  async listDistricts(city: string, limit = 100): Promise<{ districts: string[] }> {
    const res = await this.pg.query<{ district: string }>(
      `SELECT DISTINCT v.district
       FROM venues v
       JOIN venue_type_capabilities c ON c.venue_type = v.venue_type AND c.enabled_for_discovery
       WHERE v.status = 'published' AND v.city = $1
         AND v.district IS NOT NULL AND trim(v.district) <> ''
       ORDER BY v.district
       LIMIT $2`,
      [city, Math.min(Math.max(limit, 1), 200)],
    );
    return { districts: res.rows.map((r) => r.district) };
  }

  async filterDefinitions(venueType?: string): Promise<unknown[]> {
    const res = await this.pg.query(
      `SELECT key, venue_type, label_ar, label_en, value_type, operator, indexed,
              options_json, options_source, section, parent_key, source_field, availability_mode,
              priority, sort_order, status
       FROM filter_definitions
       WHERE status = 'active'
         AND (venue_type IS NULL OR venue_type = $1)
       ORDER BY section, sort_order, key`,
      [venueType ?? null],
    );
    return res.rows
      .filter((r) => isHandlerRegistered(String(r.key)))
      .map((r) => ({
        key: r.key,
        venueType: r.venue_type,
        labelAr: r.label_ar,
        labelEn: r.label_en,
        valueType: r.value_type,
        operator: r.operator,
        indexed: r.indexed,
        options: r.options_source === 'dynamic' ? [] : r.options_json,
        optionsSource: r.options_source,
        section: r.section,
        parentKey: r.parent_key,
        availabilityMode: r.availability_mode,
        priority: r.priority,
        sortOrder: r.sort_order,
        status: r.status,
        sourceFieldDoc: r.source_field,
      }));
  }

  async assertActiveDefinitionsHaveHandlers(): Promise<string[]> {
    const res = await this.pg.query<{ key: string }>(
      `SELECT DISTINCT key FROM filter_definitions WHERE status = 'active'`,
    );
    return res.rows.map((r) => r.key).filter((k) => !isHandlerRegistered(k));
  }

  /**
   * Discovery search (Gate 7B.4 Mixed Feed Diversity + prior cursor pipeline):
   * 1) assertDiscoveryLimits (no SQL)
   * 2) defaults → diversity mode → structural cursor (no SQL)
   * 3) resolvers (intent / caps / anchor / labels) — SQL allowed
   * 4) queryHash + context validation — before COUNT/page SQL
   * 5) COUNT + (diversity peeks | global keyset page)
   *
   * Every call runs under a request-local Pg probe so diversity metrics can report
   * an honest totalRequestQueryCount (all PgService.query invocations).
   */
  async search(raw: DiscoverySearchDto): Promise<DiscoverySearchResult> {
    const { value } = await withPgRequestProbe(() => this.executeSearch(raw));
    return value;
  }

  private async executeSearch(raw: DiscoverySearchDto): Promise<DiscoverySearchResult> {
    assertDiscoveryLimits(raw);

    // Effective sort/q/defaults BEFORE cursor mode + any SQL (Gate 7B.3.3 / 7B.4)
    const preflight = applyDiscoveryDefaults(raw);
    const preflightSort = (preflight.sort ?? 'best') as CursorV2Sort;
    if (preflightSort === 'search_rank' && !preflight.q) {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        'q required for sort=search_rank after normalize',
      );
    }
    const preflightDiversity = resolveDiversityPolicy(preflight);

    let structuralCursor: KeysetCursorV2Payload | null = null;
    if (raw.cursor) {
      structuralCursor = parseCursorV2Structural(raw.cursor, preflightDiversity.mode);
      assertCursorV2PreflightSortEpoch(structuralCursor, preflightSort, RANKING_EPOCH_CURRENT);
      if (preflightDiversity.applied) {
        if (structuralCursor.diversityVersion !== DIVERSITY_VERSION_CURRENT) {
          throw new AppError(ErrorCodes.VALIDATION_ERROR, 'cursor diversityVersion mismatch');
        }
        if (structuralCursor.diversityK !== DIVERSITY_K_DEFAULT) {
          throw new AppError(ErrorCodes.VALIDATION_ERROR, 'cursor diversityK mismatch');
        }
      }
    }

    const intent = await resolveIntent(this.pg, raw);
    const afterIntent = intent.dto;
    const category = afterIntent.category;

    if (category) {
      await this.caps.requireDiscoveryEnabled(category);
    }

    const canonical = applyDiscoveryDefaults(afterIntent);
    const sort = (canonical.sort ?? 'best') as CursorV2Sort;
    if (sort === 'search_rank' && !canonical.q) {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        'q required for sort=search_rank after normalize',
      );
    }

    const diversity = resolveDiversityPolicy(canonical);
    if (diversity.mode !== preflightDiversity.mode) {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, 'cursor diversity mode mismatch');
    }

    let anchor: ResolvedAnchor | undefined;
    if (sort === 'near_place') {
      if (!canonical.anchorVenueId) {
        throw new AppError(ErrorCodes.VALIDATION_ERROR, 'sort=near_place requires anchorVenueId');
      }
      anchor = await resolveNearPlaceAnchor(this.pg, canonical.anchorVenueId);
      assertRadiusKm(canonical.radiusKm ?? 50, anchor.lat);
    } else if (canonical.anchorVenueId && sort !== 'near_me') {
      anchor = await resolveNearPlaceAnchor(this.pg, canonical.anchorVenueId);
    }

    let searchPlans: TokenMatchPlan[] = [];
    let phrasePlans: PhraseMatchPlan[] = [];
    if (canonical.q) {
      const tokens = prepareSearchQuery(canonical.q);
      if (tokens) {
        const labels = await this.loadCapabilityLabels();
        const planned = planSearchTokens(tokens, labels);
        searchPlans = planned.plans;
        phrasePlans = planned.phrasePlans;
      }
    }

    const rankingAsOf = structuralCursor
      ? structuralCursor.rankingAsOf
      : normalizeRankingAsOf(null);
    assertRankingAsOfFresh(rankingAsOf);

    const originLat = sort === 'near_place' ? (anchor?.lat ?? null) : (canonical.lat ?? null);
    const originLng = sort === 'near_place' ? (anchor?.lng ?? null) : (canonical.lng ?? null);

    const queryHash = buildQueryHash({
      resolvedCanonicalJson: canonicalizeResolvedDto(
        canonical as unknown as Record<string, unknown>,
      ),
      surface: canonical.surface ?? 'search',
      q: canonical.q?.trim() ? canonical.q : null,
      originLat,
      originLng,
      anchorVenueId: canonical.anchorVenueId ?? null,
      rankingVersion: RANKING_EPOCH_CURRENT,
      rankingEpoch: RANKING_EPOCH_CURRENT,
      rankingAsOf,
      diversityVersion: diversity.version,
      diversityK: diversity.k,
    });

    let decodedCursor: KeysetCursorV2Payload | null = null;
    if (structuralCursor) {
      assertCursorV2Context(
        structuralCursor,
        sort,
        queryHash,
        RANKING_EPOCH_CURRENT,
        rankingAsOf,
      );
      decodedCursor = structuralCursor;
    }

    const buildOptsBase = {
      scopedVenueTypes: intent.scopedVenueTypes ?? undefined,
      anchor,
      searchPlans,
      phrasePlans,
      rankingAsOf,
      excludeAnchor: true as const,
    };

    // Mixed path: never apply global cursorSql — resume via perTypeAfter only.
    const built = buildDiscoveryQuery(canonical, {
      ...buildOptsBase,
      decodedCursor: diversity.applied ? null : decodedCursor,
    });

    const countSql = `SELECT COUNT(*)::int AS n FROM venues v WHERE ${built.whereSql}`;
    const limit = Math.min(canonical.limit ?? 20, 50);
    let pageRows: Record<string, unknown>[];
    let nextCursor: string | null = null;
    let total: number;

    if (diversity.applied) {
      const countRes = await this.pg.query<{ n: number }>(countSql, built.whereParams);
      total = countRes.rows[0]?.n ?? 0;
      const priorState = decodedCursor?.diversity ?? emptyDiversityState();
      const divPage = await runMixedFeedDiversityPage(
        this.pg,
        built,
        (venueType, after) =>
          buildDiscoveryQuery(
            { ...canonical, category: venueType },
            {
              ...buildOptsBase,
              decodedCursor: after
                ? typeAfterAsCursorPayload(sort, after, rankingAsOf)
                : null,
            },
          ),
        limit,
        priorState,
      );
      pageRows = divPage.rows;
      // Test/evidence hook: last diversity page metrics (not part of public API contract).
      // totalRequestQueryCount = observed PgService.query count for this request (honest).
      // resolverQueryCount = observed − COUNT − DISTINCT − candidate (intent/caps/anchor/labels/…).
      const observed = getPgRequestProbe()?.total ?? 0;
      const countQueryCount = 1;
      const distinctQueryCount = divPage.metrics.distinctQueryCount;
      const candidateQueryCount = divPage.metrics.candidateQueryCount;
      const accounted =
        countQueryCount + distinctQueryCount + candidateQueryCount;
      const resolverQueryCount = Math.max(0, observed - accounted);
      const withOuter = {
        ...divPage.metrics,
        countQueryCount,
        resolverQueryCount,
        observedPgQueryCount: observed,
        totalRequestQueryCount: observed,
        queryCount: distinctQueryCount + candidateQueryCount,
      };
      (this as { lastDiversityMetrics?: typeof withOuter }).lastDiversityMetrics = withOuter;
      if (!divPage.exhausted && pageRows.length > 0) {
        nextCursor = cursorV2FromRow(
          built.sort,
          pageRows[pageRows.length - 1],
          {
            queryHash,
            rankingAsOf,
            diversityVersion: DIVERSITY_VERSION_CURRENT,
            diversityK: DIVERSITY_K_DEFAULT,
            diversity: divPage.nextState,
          },
          'required',
        );
      } else {
        nextCursor = null;
      }
    } else {
      const pageWhere = built.cursorSql
        ? `${built.whereSql} AND (${built.cursorSql})`
        : built.whereSql;
      const pageParams = [
        ...built.whereParams,
        ...built.sortParams,
        ...built.cursorParams,
        limit + 1,
      ];
      const sql = discoveryPageSql(built, pageWhere, pageParams.length);
      // Sequential COUNT then PAGE: under c=20, parallelizing both doubles seq-scan
      // pressure and inflates p95 more than it helps single-request wall time.
      const countRes = await this.pg.query<{ n: number }>(countSql, built.whereParams);
      const res = await this.pg.query(sql, pageParams);
      total = countRes.rows[0]?.n ?? 0;
      const hasMore = res.rows.length > limit;
      pageRows = hasMore ? res.rows.slice(0, limit) : res.rows;
      nextCursor = hasMore
        ? cursorV2FromRow(
            built.sort,
            pageRows[pageRows.length - 1] as Record<string, unknown>,
            { queryHash, rankingAsOf },
            'forbidden',
          )
        : null;
    }

    const items = pageRows.map((r) =>
      this.mapDiscoveryItem(r, built.availabilityMode, built.priceSemantics, built.surface),
    );

    return {
      items,
      nextCursor,
      total,
      applied: {
        category: category ?? null,
        city: canonical.city ?? null,
        district: canonical.district ?? null,
        surface: built.surface,
        dates:
          canonical.checkIn && canonical.checkOut
            ? { checkIn: canonical.checkIn, checkOut: canonical.checkOut }
            : null,
        guests: canonical.guests ?? null,
        quantity: canonical.quantity ?? null,
        amenities: [...new Set(canonical.amenities ?? [])],
        intent: intent.appliedIntent,
        intentNotes: intent.intentNotes,
        appliedConstraints: intent.appliedConstraints,
        availabilityMode: built.availabilityMode,
        priceSemantics: built.priceSemantics,
        rankingAsOf,
        queryHash,
        rankingEpoch: RANKING_EPOCH_CURRENT,
        q: canonical.q ?? null,
        anchorVenueId: canonical.anchorVenueId ?? null,
        sameTypeOnly: canonical.sameTypeOnly === true,
        radiusKm: canonical.radiusKm ?? null,
        excludeAnchor: sort === 'near_place' ? true : null,
        diversity: diversityAppliedMeta(diversity),
        profile: resolveAppliedProfile(canonical),
      },
      sort: built.sort,
      capabilities: {
        facetCounts: 'deferred',
        geo: 'partial',
        weddingEventBooking: 'BOOKING_NOT_READY',
      },
    };
  }

  /** Legacy GET /v1/feed — thin adapter over the same discovery engine. */
  async feedAdapter(query: {
    category?: string;
    city?: string;
    cursor?: string;
  }): Promise<{ items: unknown[]; nextCursor: string | null; total: number }> {
    const result = await this.search({
      category: query.category,
      city: query.city,
      cursor: query.cursor,
      limit: 20,
      sort: 'newest',
      surface: 'feed',
    });
    return {
      total: result.total,
      nextCursor: result.nextCursor,
      items: result.items.map((i) => ({
        videoId: i.primaryMediaId,
        venueId: i.venueId,
        coverUrl: i.coverUrl,
        streamUid: i.streamUid,
        streamUrl: i.streamUrl,
        headline: i.name,
        startingPriceHint: i.startingPriceHint,
        city: i.city,
        category: i.categoryFallbackKey ?? i.category,
        ratingAverage: i.ratingAverage,
        weightedRating: i.weightedRating,
        bookingMode: i.bookingMode,
        bookingStatus: i.bookingStatus,
        enabledForBooking: i.enabledForBooking,
      })),
    };
  }

  private async loadCapabilityLabels(): Promise<LabelPhrase[]> {
    const res = await this.pg.query<{
      venue_type: string;
      label_ar: string | null;
      label_en: string | null;
    }>(
      `SELECT venue_type, label_ar, label_en
       FROM venue_type_capabilities
       WHERE enabled_for_discovery = TRUE`,
    );
    const out: LabelPhrase[] = [];
    for (const row of res.rows) {
      if (row.label_ar) out.push({ phrase: row.label_ar, venueTypes: [row.venue_type] });
      if (row.label_en) out.push({ phrase: row.label_en, venueTypes: [row.venue_type] });
    }
    return out;
  }

  private mapDiscoveryItem(
    r: Record<string, unknown>,
    availabilityMode: AvailabilityState,
    priceSemantics: string,
    surface: string,
  ): Record<string, unknown> {
    const eventSlotKill =
      r.booking_mode === 'event_slot' &&
      process.env.PLACES_EVENT_SLOT_ENABLED !== 'true';
    const bookingEnabled =
      !eventSlotKill && r.enabled_for_booking === true;
    return {
      venueId: r.id,
      name: r.name,
      category: r.venue_type,
      categoryFallbackKey: r.media_category ?? r.venue_type,
      bookingMode: r.booking_mode,
      booking_mode: r.booking_mode,
      enabledForBooking: bookingEnabled,
      enabled_for_booking: bookingEnabled,
      bookingStatus: bookingEnabled ? 'BOOKING_READY' : 'BOOKING_NOT_READY',
      city: r.city,
      district: r.district,
      lat: r.lat,
      lng: r.lng,
      verified: r.verified,
      stars: r.stars,
      bedrooms: r.bedrooms,
      bathrooms: r.bathrooms,
      beds: r.beds,
      capacity: r.capacity,
      sizeSqm: r.size_sqm,
      ratingAverage: Number(r.rating_average),
      reviewsCount: r.reviews_count,
      weightedRating: Number(r.weighted_rating),
      bestScore: r.best_score != null ? Number(r.best_score) : null,
      textRank: r.text_rank != null ? Number(r.text_rank) : null,
      hasActiveOffer: r.has_active_offer,
      filterDataCompleteness: Number(r.filter_data_completeness),
      startingPriceHint: r.starting_price_hint != null ? Number(r.starting_price_hint) : null,
      amenities: r.amenities ?? [],
      attributes: r.attributes_jsonb ?? {},
      availabilityState: availabilityMode,
      priceSemantics,
      surface,
      distanceKm:
        r.distance_meters != null
          ? Number(r.distance_meters) / 1000
          : r.distance_km != null
            ? Number(r.distance_km)
            : null,
      distanceMeters: r.distance_meters != null ? Number(r.distance_meters) : null,
      primaryMediaId: r.media_id ?? null,
      mediaKind: r.media_kind ?? null,
      streamUid:
        typeof r.stream_uid === 'string' && r.stream_uid.trim() !== ''
          ? r.stream_uid.trim()
          : null,
      streamUrl: resolveStreamUrl(r.stream_url),
      coverUrl: r.cover_url ?? null,
    };
  }
}
