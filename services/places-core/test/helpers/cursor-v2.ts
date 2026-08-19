/**
 * Build Cursor v2 for acceptance tests matching FilterEngine queryHash rules (7B.3.1).
 */
import {
  buildQueryHash,
  canonicalizeResolvedDto,
  CursorV2Sort,
  encodeCursorV2,
  RANKING_EPOCH_CURRENT,
} from '../../src/modules/filters/application/discovery-cursor-v2';
import { applyDiscoveryDefaults } from '../../src/modules/filters/application/discovery-query';
import { DiscoverySearchDto } from '../../src/shared/api/dto/discovery-search.dto';

export function rankingAsOfNow(): string {
  return new Date().toISOString().replace(/\.\d{3}Z$/, '.000Z');
}

export function encodeTestCursorV2(
  body: Record<string, unknown>,
  keyset: {
    sv: string | null;
    sv2?: string | null;
    sv3?: string | null;
    id: string;
  },
  rankingAsOf = rankingAsOfNow(),
  origin?: { lat: number | null; lng: number | null },
): string {
  const canonical = applyDiscoveryDefaults(body as DiscoverySearchDto);
  const sort = (canonical.sort ?? 'best') as CursorV2Sort;
  const originLat =
    origin?.lat !== undefined
      ? origin.lat
      : sort === 'near_place'
        ? null
        : canonical.lat != null
          ? Number(canonical.lat)
          : null;
  const originLng =
    origin?.lng !== undefined
      ? origin.lng
      : sort === 'near_place'
        ? null
        : canonical.lng != null
          ? Number(canonical.lng)
          : null;
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
    diversityVersion: 0,
    diversityK: 0,
  });
  return encodeCursorV2(
    {
      v: 2,
      sort,
      queryHash,
      rankingEpoch: RANKING_EPOCH_CURRENT,
      rankingAsOf,
      sv: keyset.sv,
      ...(keyset.sv2 !== undefined ? { sv2: keyset.sv2 } : {}),
      ...(keyset.sv3 !== undefined ? { sv3: keyset.sv3 } : {}),
      id: keyset.id,
    },
    'forbidden',
  );
}
