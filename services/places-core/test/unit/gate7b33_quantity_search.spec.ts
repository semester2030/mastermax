/**
 * Gate 7B.3.3 — quantity semantics + empty-q search invariant (unit).
 */
import {
  applyDiscoveryDefaults,
  buildDiscoveryQuery,
} from '../../src/modules/filters/application/discovery-query';
import {
  buildQueryHash,
  canonicalizeResolvedDto,
  RANKING_EPOCH_CURRENT,
} from '../../src/modules/filters/application/discovery-cursor-v2';
import { normalizeSearchText } from '../../src/modules/filters/application/discovery-search-contract';
import { DiscoverySearchDto } from '../../src/shared/api/dto/discovery-search.dto';

const AS_OF = new Date().toISOString().replace(/\.\d{3}Z$/, '.000Z');

function hashFor(dto: DiscoverySearchDto) {
  const canonical = applyDiscoveryDefaults(dto);
  return buildQueryHash({
    resolvedCanonicalJson: canonicalizeResolvedDto(
      canonical as unknown as Record<string, unknown>,
    ),
    surface: canonical.surface ?? 'search',
    q: canonical.q ?? null,
    originLat: null,
    originLng: null,
    anchorVenueId: null,
    rankingVersion: RANKING_EPOCH_CURRENT,
    rankingEpoch: RANKING_EPOCH_CURRENT,
    rankingAsOf: AS_OF,
    diversityVersion: 0,
    diversityK: 0,
  });
}

describe('Gate 7B.3.3 — G7B33 quantity + search invariant unit', () => {
  it('G7B33-QTY-01 omitted ≠ quantity=1 in hash and SQL filter', () => {
    const omitted = applyDiscoveryDefaults({ sort: 'best' } as DiscoverySearchDto);
    const one = applyDiscoveryDefaults({ sort: 'best', quantity: 1 } as DiscoverySearchDto);
    expect(omitted.quantity).toBeUndefined();
    expect(one.quantity).toBe(1);
    expect(hashFor({ sort: 'best' } as DiscoverySearchDto)).not.toBe(
      hashFor({ sort: 'best', quantity: 1 } as DiscoverySearchDto),
    );

    const qOmit = buildDiscoveryQuery(omitted, { rankingAsOf: AS_OF });
    const qOne = buildDiscoveryQuery(one, { rankingAsOf: AS_OF });
    expect(qOmit.whereSql).not.toMatch(/quantity_total/);
    expect(qOne.whereSql).toMatch(/quantity_total/);
    expect(qOne.whereParams).toContain(1);
  });

  it('G7B33-SEARCH-01 empty after normalize + missing/best → best, no search', () => {
    for (const q of ['   ', 'ًٌَ', 'ــــ', '\t\n']) {
      const d = applyDiscoveryDefaults({ q, sort: 'best' } as DiscoverySearchDto);
      expect(d.q).toBeUndefined();
      expect(d.sort).toBe('best');
      const missing = applyDiscoveryDefaults({ q } as DiscoverySearchDto);
      expect(missing.q).toBeUndefined();
      expect(missing.sort).toBe('best');
    }
    expect(normalizeSearchText('ًَ')).toBe('');
  });

  it('G7B33-SEARCH-02 empty after normalize + explicit search_rank → 400', () => {
    expect(() =>
      applyDiscoveryDefaults({ q: '   ', sort: 'search_rank' } as DiscoverySearchDto),
    ).toThrow(/q required for sort=search_rank/);
    expect(() =>
      applyDiscoveryDefaults({ q: 'ًٌَ', sort: 'search_rank' } as DiscoverySearchDto),
    ).toThrow(/q required for sort=search_rank/);
    expect(() =>
      applyDiscoveryDefaults({ sort: 'search_rank' } as DiscoverySearchDto),
    ).toThrow(/q required for sort=search_rank/);
  });
});
