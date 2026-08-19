/**
 * Gate 7B.3.2 — cursor canonicalization + preflight query-count contracts.
 */
import { AppError } from '../../src/shared/errors/app-error';
import { DiscoverySearchDto } from '../../src/shared/api/dto/discovery-search.dto';
import { newId } from '../../src/shared/ids/ids';
import {
  applyDiscoveryDefaults,
  assertDiscoveryLimits,
  canonicalizeStringSet,
} from '../../src/modules/filters/application/discovery-query';
import {
  assertCursorV2Context,
  assertCursorV2PreflightSortEpoch,
  buildQueryHash,
  canonicalizeResolvedDto,
  encodeCursorV2,
  parseCursorV2Structural,
  RANKING_EPOCH_CURRENT,
} from '../../src/modules/filters/application/discovery-cursor-v2';
import { normalizeSearchText } from '../../src/modules/filters/application/discovery-search-contract';
import { FilterEngineService } from '../../src/modules/filters/application/filter-engine.service';
import { VenueTypeCapabilityPolicy } from '../../src/modules/filters/application/venue-type-capability.policy';
import { PgService } from '../../src/shared/database/pg.service';

const AS_OF = new Date().toISOString().replace(/\.\d{3}Z$/, '.000Z');

function hashFor(dto: DiscoverySearchDto, extras?: { lat?: number; lng?: number; asOf?: string }) {
  const canonical = applyDiscoveryDefaults(dto);
  return buildQueryHash({
    resolvedCanonicalJson: canonicalizeResolvedDto(
      canonical as unknown as Record<string, unknown>,
    ),
    surface: canonical.surface ?? 'search',
    q: canonical.q ?? null,
    originLat: extras?.lat ?? canonical.lat ?? null,
    originLng: extras?.lng ?? canonical.lng ?? null,
    anchorVenueId: canonical.anchorVenueId ?? null,
    rankingVersion: RANKING_EPOCH_CURRENT,
    rankingEpoch: RANKING_EPOCH_CURRENT,
    rankingAsOf: extras?.asOf ?? AS_OF,
    diversityVersion: 0,
    diversityK: 0,
  });
}

function makeCursor(overrides: Record<string, unknown> = {}): string {
  return encodeCursorV2(
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
      ...overrides,
    } as never,
    'forbidden',
  );
}

describe('Gate 7B.3.2 — G7B32 canonical hash + preflight', () => {
  it('G7B32-CURSOR-01 q normalize before sort/hash; diacritics-only → missing', () => {
    const a = applyDiscoveryDefaults({ q: '  Hotel  ' } as DiscoverySearchDto);
    expect(a.q).toBe('hotel');
    expect(a.sort).toBe('search_rank');
    expect(hashFor({ q: 'Hotel' } as DiscoverySearchDto)).toBe(
      hashFor({ q: 'hotel' } as DiscoverySearchDto),
    );
    expect(hashFor({ q: '  hotel  ' } as DiscoverySearchDto)).toBe(
      hashFor({ q: 'hotel' } as DiscoverySearchDto),
    );
    const nfd = 'cafe\u0301'; // café NFD
    const nfc = 'café';
    expect(normalizeSearchText(nfd)).toBe(normalizeSearchText(nfc));
    expect(hashFor({ q: nfd } as DiscoverySearchDto)).toBe(hashFor({ q: nfc } as DiscoverySearchDto));

    const empty = applyDiscoveryDefaults({ q: 'ًٌَ' } as DiscoverySearchDto); // diacritics only
    expect(empty.q).toBeUndefined();
    expect(empty.sort).toBe('best');
  });

  it('G7B32-CURSOR-02 quantity omitted ≠ 1; amenities order/dupes; surface/limit defaults', () => {
    expect(hashFor({} as DiscoverySearchDto)).toBe(
      hashFor({ limit: 20, surface: 'search' } as DiscoverySearchDto),
    );
    expect(hashFor({} as DiscoverySearchDto)).not.toBe(
      hashFor({ quantity: 1, limit: 20, surface: 'search' } as DiscoverySearchDto),
    );
    expect(
      hashFor({ amenities: ['wifi', 'pool', 'wifi'] } as DiscoverySearchDto),
    ).toBe(hashFor({ amenities: ['pool', 'wifi'] } as DiscoverySearchDto));
    expect(canonicalizeStringSet(['b', 'a', 'b'])).toEqual(['a', 'b']);
    const np = applyDiscoveryDefaults({
      sort: 'near_place',
      anchorVenueId: newId(),
    } as DiscoverySearchDto);
    expect(np.radiusKm).toBe(50);
    expect(np.sameTypeOnly).toBe(true);
    expect(np.quantity).toBeUndefined();
    expect(np.limit).toBe(20);
    expect(np.surface).toBe('search');
  });

  it('G7B32-CURSOR-03 rankingAsOf in body rejected (not silently ignored)', () => {
    expect(() =>
      assertDiscoveryLimits({
        sort: 'best',
        rankingAsOf: AS_OF,
      } as DiscoverySearchDto),
    ).toThrow(/server-owned/);
  });

  it('G7B32-CURSOR-04 structural TTL/epoch/sort preflight; hash after only', () => {
    const expired = new Date(Date.now() - 20 * 60 * 1000).toISOString().replace(/\.\d{3}Z$/, '.000Z');
    expect(() => parseCursorV2Structural(makeCursor({ rankingAsOf: expired }))).toThrow(
      /expired|invalid/,
    );
    const v1 = Buffer.from(
      JSON.stringify({
        v: 1,
        sort: 'best',
        queryHash: 'a'.repeat(32),
        rankingEpoch: 1,
        rankingAsOf: AS_OF,
        sv: '0.500000',
        id: newId(),
      }),
    ).toString('base64url');
    expect(() => parseCursorV2Structural(v1)).toThrow(/version/);
    expect(() => parseCursorV2Structural('%%%not-b64%%%')).toThrow(/malformed/);

    const structural = parseCursorV2Structural(makeCursor({ sort: 'best' }));
    expect(() => assertCursorV2PreflightSortEpoch(structural, 'newest')).toThrow(/sort/);
    expect(() => assertCursorV2PreflightSortEpoch(structural, 'best', 99)).toThrow(/rankingEpoch/);
    assertCursorV2PreflightSortEpoch(structural, 'best', RANKING_EPOCH_CURRENT);

    expect(() =>
      assertCursorV2Context(structural, 'best', '0'.repeat(32), RANKING_EPOCH_CURRENT, AS_OF),
    ).toThrow(/queryHash/);
  });

  it('G7B32-CURSOR-05 query-count: malformed/v1/expired/sort/epoch → zero SQL', async () => {
    const calls: string[] = [];
    const pg = {
      query: async (sql: string) => {
        calls.push(sql);
        return { rows: [], rowCount: 0 };
      },
    } as unknown as PgService;
    const caps = new VenueTypeCapabilityPolicy(pg);
    const engine = new FilterEngineService(pg, caps);

    const expectZero = async (body: DiscoverySearchDto) => {
      calls.length = 0;
      await expect(engine.search(body)).rejects.toBeInstanceOf(AppError);
      expect(calls).toEqual([]);
    };

    await expectZero({ cursor: '%%%bad%%%' } as DiscoverySearchDto);
    const v1 = Buffer.from(
      JSON.stringify({
        v: 1,
        sort: 'best',
        queryHash: 'a'.repeat(32),
        rankingEpoch: 1,
        rankingAsOf: AS_OF,
        sv: '0.500000',
        id: newId(),
      }),
    ).toString('base64url');
    await expectZero({ cursor: v1 } as DiscoverySearchDto);
    const expired = new Date(Date.now() - 20 * 60 * 1000).toISOString().replace(/\.\d{3}Z$/, '.000Z');
    await expectZero({ cursor: makeCursor({ rankingAsOf: expired }) } as DiscoverySearchDto);
    await expectZero({
      sort: 'newest',
      cursor: makeCursor({ sort: 'best' }),
    } as DiscoverySearchDto);
    await expectZero({
      sort: 'best',
      cursor: makeCursor({ rankingEpoch: 99 }),
    } as DiscoverySearchDto);
  });

  it('G7B32-CURSOR-06 query-count: hash mismatch never reaches COUNT/page', async () => {
    const calls: string[] = [];
    const pg = {
      query: async (sql: string) => {
        calls.push(sql);
        if (/intent_presets/i.test(sql)) {
          return { rows: [], rowCount: 0 };
        }
        if (/venue_type_capabilities/i.test(sql) && /label_/i.test(sql)) {
          return { rows: [], rowCount: 0 };
        }
        if (/enabled_for_discovery/i.test(sql)) {
          return {
            rows: [{ enabled_for_discovery: true, enabled_for_booking: true, enabled_for_provider: true }],
            rowCount: 1,
          };
        }
        return { rows: [], rowCount: 0 };
      },
    } as unknown as PgService;
    const caps = new VenueTypeCapabilityPolicy(pg);
    const engine = new FilterEngineService(pg, caps);

    const badHash = makeCursor({
      sort: 'best',
      queryHash: 'f'.repeat(32),
    });
    calls.length = 0;
    await expect(engine.search({ sort: 'best', cursor: badHash } as DiscoverySearchDto)).rejects.toThrow(
      /queryHash/,
    );
    expect(calls.some((s) => /COUNT\(\*\)/i.test(s))).toBe(false);
    expect(calls.some((s) => /ORDER BY/i.test(s) && /LIMIT/i.test(s))).toBe(false);
  });
});
