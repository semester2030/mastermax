import {
  applyDiscoveryDefaults,
  assertDiscoveryLimits,
  buildDiscoveryQuery,
  NEAR_PLACE_DEFAULT_RADIUS_KM,
} from '../../src/modules/filters/application/discovery-query';
import { bestScoreSqlExpr } from '../../src/modules/filters/application/discovery-best-score';
import {
  assertCursorV2Context,
  buildQueryHash,
  canonicalizeResolvedDto,
  encodeCursorV2,
  parseCursorV2Structural,
  RANKING_EPOCH_CURRENT,
} from '../../src/modules/filters/application/discovery-cursor-v2';
import {
  normalizeSearchText,
  planSearchTokens,
  prepareSearchQuery,
  buildSearchPredicate,
  flattenSearchParams,
  tokenizeSearchQuery,
  escapeLikeLiteral,
} from '../../src/modules/filters/application/discovery-search-contract';
import { DiscoverySearchDto } from '../../src/shared/api/dto/discovery-search.dto';
import { newId } from '../../src/shared/ids/ids';

const AS_OF = new Date().toISOString().replace(/\.\d{3}Z$/, '.000Z');
const anchor = {
  id: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
  venueType: 'hotel',
  lat: 24.7,
  lng: 46.7,
};

describe('Gate 7B.3.1 — G7B31 contract unit matrix', () => {
  it('G7B31-GEO-01 near_me forbids anchorVenueId', () => {
    expect(() =>
      assertDiscoveryLimits({
        sort: 'near_me',
        lat: 1,
        lng: 2,
        anchorVenueId: anchor.id,
      } as DiscoverySearchDto),
    ).toThrow(/forbids anchorVenueId/);
  });

  it('G7B31-GEO-02 near_place forbids client lat/lng/bounds', () => {
    expect(() =>
      assertDiscoveryLimits({
        sort: 'near_place',
        anchorVenueId: anchor.id,
        lat: 1,
        lng: 2,
      } as DiscoverySearchDto),
    ).toThrow(/forbids client lat\/lng/);
    expect(() =>
      assertDiscoveryLimits({
        sort: 'near_place',
        anchorVenueId: anchor.id,
        minLat: 1,
        maxLat: 2,
        minLng: 3,
        maxLng: 4,
      } as DiscoverySearchDto),
    ).toThrow(/forbids bounds/);
  });

  it('G7B31-GEO-03 defaults radiusKm=50 sameTypeOnly excludeAnchor', () => {
    const d = applyDiscoveryDefaults({
      sort: 'near_place',
      anchorVenueId: anchor.id,
    } as DiscoverySearchDto);
    expect(d.radiusKm).toBe(NEAR_PLACE_DEFAULT_RADIUS_KM);
    expect(d.sameTypeOnly).toBe(true);
    const q = buildDiscoveryQuery(
      { ...d, sort: 'near_place' } as DiscoverySearchDto,
      { rankingAsOf: AS_OF, anchor, excludeAnchor: true },
    );
    expect(q.whereSql).toContain('v.id <>');
    expect(q.whereParams).toContain(50);
  });

  it('G7B31-CURSOR-01 structural parse before context hash', () => {
    const enc = encodeCursorV2(
      {
        v: 2,
        sort: 'best',
        queryHash: 'a'.repeat(32),
        rankingEpoch: RANKING_EPOCH_CURRENT,
        rankingAsOf: AS_OF,
        sv: '0.500000',
        sv2: '4.00',
        sv3: '1',
        id: newId(),
      },
      'forbidden',
    );
    const structural = parseCursorV2Structural(enc, 'forbidden');
    expect(structural.v).toBe(2);
    expect(() =>
      assertCursorV2Context(structural, 'best', '0'.repeat(32), RANKING_EPOCH_CURRENT, AS_OF),
    ).toThrow(/queryHash/);
  });

  it('G7B31-CURSOR-02 default-equivalence same queryHash', () => {
    const a = applyDiscoveryDefaults({
      sort: 'near_place',
      anchorVenueId: anchor.id,
    } as DiscoverySearchDto);
    const b = applyDiscoveryDefaults({
      sort: 'near_place',
      anchorVenueId: anchor.id,
      radiusKm: 50,
      sameTypeOnly: true,
      limit: 20,
      surface: 'search',
    } as DiscoverySearchDto);
    const hash = (dto: DiscoverySearchDto) =>
      buildQueryHash({
        resolvedCanonicalJson: canonicalizeResolvedDto(dto as unknown as Record<string, unknown>),
        surface: dto.surface ?? 'search',
        q: null,
        originLat: anchor.lat,
        originLng: anchor.lng,
        anchorVenueId: anchor.id,
        rankingVersion: RANKING_EPOCH_CURRENT,
        rankingEpoch: RANKING_EPOCH_CURRENT,
        rankingAsOf: AS_OF,
        diversityVersion: 0,
        diversityK: 0,
      });
    expect(hash(a)).toBe(hash(b));
  });

  it('G7B31-SEARCH-01 q + missing/best sort → search_rank', () => {
    expect(applyDiscoveryDefaults({ q: 'hotel' } as DiscoverySearchDto).sort).toBe('search_rank');
    expect(
      applyDiscoveryDefaults({ q: 'hotel', sort: 'best' } as DiscoverySearchDto).sort,
    ).toBe('search_rank');
    expect(
      applyDiscoveryDefaults({ q: 'hotel', sort: 'newest' } as DiscoverySearchDto).sort,
    ).toBe('newest');
  });

  it('G7B31-SEARCH-02 blank whitespace no search; single char 400', () => {
    expect(prepareSearchQuery('  \t ')).toBeNull();
    expect(applyDiscoveryDefaults({ q: '   ', sort: 'best' } as DiscoverySearchDto).q).toBeUndefined();
    expect(() => prepareSearchQuery('م')).toThrow(/too short/);
  });

  it('G7B31-SEARCH-03 percent underscore backslash literal escaped', () => {
    const tokens = tokenizeSearchQuery('100%_off');
    expect(tokens[0]).toContain('%');
    expect(escapeLikeLiteral(tokens[0])).toMatch(/\\%/);
  });

  it('G7B31-SEARCH-04 phrases are independent AND conjuncts', () => {
    const tokens = tokenizeSearchQuery('ملقا قصر أفراح');
    const { plans, phrasePlans } = planSearchTokens(tokens, [
      { phrase: 'قصر أفراح', venueTypes: ['hall'] },
      { phrase: 'قصر أفراح', venueTypes: ['wedding_palace'] },
    ]);
    expect(phrasePlans).toHaveLength(1);
    expect(phrasePlans[0].venueTypes.sort()).toEqual(['hall', 'wedding_palace']);
    const { sql } = buildSearchPredicate(plans.length, phrasePlans.length, 1);
    expect(sql.match(/ AND /g)?.length).toBeGreaterThanOrEqual(1);
    const params = flattenSearchParams(plans, phrasePlans);
    expect(params).toEqual(
      expect.arrayContaining([
        normalizeSearchText('ملقا'),
        normalizeSearchText('قصر أفراح'),
        expect.arrayContaining(['hall', 'wedding_palace']),
      ]),
    );
  });

  it('G7B31-RANK-01 locked formula via best_score_static + freshness NUMERIC(8,6)', () => {
    const expr = bestScoreSqlExpr(1);
    expect(expr).toContain('best_score_static');
    expect(expr).toContain('0.15');
    expect(expr).toContain('EXP');
    expect(expr).toContain('numeric(8,6)');
    expect(expr).not.toMatch(/availability/i);
    expect(expr).not.toMatch(/distance/i);
  });
});
