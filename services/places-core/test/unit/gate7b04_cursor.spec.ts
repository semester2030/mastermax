import {
  buildQueryHash,
  canonicalizeResolvedDto,
  decodeCursorV2,
  encodeCursorV2,
  DIVERSITY_K_DEFAULT,
  DIVERSITY_VERSION_CURRENT,
  RANKING_EPOCH_CURRENT,
} from '../../src/modules/filters/application/discovery-cursor-v2';
import { AppError } from '../../src/shared/errors/app-error';
import { ErrorCodes } from '../../src/shared/errors/error-codes';

describe('Gate 7B.0.4 — G7B04-CURSOR diversity all-or-nothing', () => {
  const rankingAsOf = new Date().toISOString().replace(/\.\d{3}Z$/, '.000Z');
  const hash = buildQueryHash({
    resolvedCanonicalJson: canonicalizeResolvedDto({ sort: 'best', surface: 'feed' }),
    surface: 'feed',
    q: null,
    originLat: null,
    originLng: null,
    anchorVenueId: null,
    rankingVersion: 1,
    rankingEpoch: RANKING_EPOCH_CURRENT,
    rankingAsOf,
    diversityVersion: DIVERSITY_VERSION_CURRENT,
    diversityK: DIVERSITY_K_DEFAULT,
  });

  const base = {
    v: 2 as const,
    sort: 'best' as const,
    queryHash: hash,
    rankingEpoch: RANKING_EPOCH_CURRENT,
    rankingAsOf,
    sv: '0.850000',
    sv2: '4.50',
    sv3: '12',
    id: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
  };

  it('G7B04-CURSOR-01 rejects partial diversity; accepts full or none', () => {
    expect(() =>
      encodeCursorV2({
        ...base,
        diversityVersion: DIVERSITY_VERSION_CURRENT,
        diversityK: DIVERSITY_K_DEFAULT,
        // missing diversity state
      } as never, 'required'),
    ).toThrow(/diversity required/);

    expect(() =>
      encodeCursorV2({
        ...base,
        diversity: { lastType: 'hotel', streak: 1, perTypeAfter: {} },
        // missing version/K
      } as never, 'required'),
    ).toThrow(/diversity required/);

    expect(() =>
      encodeCursorV2({
        ...base,
        diversityVersion: DIVERSITY_VERSION_CURRENT,
        diversityK: DIVERSITY_K_DEFAULT,
        diversity: { lastType: 'hotel', streak: 1 } as never,
      }, 'required'),
    ).toThrow(/missing diversity field/);

    const okNone = encodeCursorV2({ ...base }, 'forbidden');
    expect(decodeCursorV2(okNone, 'best', hash, RANKING_EPOCH_CURRENT, rankingAsOf, 'forbidden').diversity).toBeUndefined();

    const okFull = encodeCursorV2({
      ...base,
      diversityVersion: DIVERSITY_VERSION_CURRENT,
      diversityK: DIVERSITY_K_DEFAULT,
      diversity: { lastType: null, streak: 0, perTypeAfter: {} },
    }, 'required');
    const decoded = decodeCursorV2(
      okFull,
      'best',
      hash,
      RANKING_EPOCH_CURRENT,
      rankingAsOf,
      'required', DIVERSITY_VERSION_CURRENT, DIVERSITY_K_DEFAULT,
    );
    expect(decoded.diversityVersion).toBe(1);
    expect(decoded.diversityK).toBe(2);

    try {
      encodeCursorV2({
        ...base,
        diversityVersion: 1,
        diversityK: 2,
      } as never, 'required');
      fail('expected');
    } catch (e) {
      expect((e as AppError).code).toBe(ErrorCodes.VALIDATION_ERROR);
    }
  });
});
