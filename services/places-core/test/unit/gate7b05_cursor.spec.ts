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

describe('Gate 7B.0.5 — G7B05-CURSOR diversity required|forbidden', () => {
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

  it('G7B05-CURSOR-01 required rejects missing diversity; forbidden rejects any diversity fields', () => {
    const plain = encodeCursorV2({ ...base }, 'forbidden');
    expect(() =>
      decodeCursorV2(plain, 'best', hash, RANKING_EPOCH_CURRENT, rankingAsOf, 'required', 1, 2),
    ).toThrow(/diversity required/);

    const withDiv = encodeCursorV2(
      {
        ...base,
        diversityVersion: DIVERSITY_VERSION_CURRENT,
        diversityK: DIVERSITY_K_DEFAULT,
        diversity: { lastType: null, streak: 0, perTypeAfter: {} },
      },
      'required',
    );
    expect(() =>
      decodeCursorV2(
        withDiv,
        'best',
        hash,
        RANKING_EPOCH_CURRENT,
        rankingAsOf,
        'forbidden', 1, 2,
      ),
    ).toThrow(/diversity fields forbidden/);

    expect(
      decodeCursorV2(
        withDiv,
        'best',
        hash,
        RANKING_EPOCH_CURRENT,
        rankingAsOf,
        'required', 1, 2,
      ).diversityK,
    ).toBe(2);

    try {
      decodeCursorV2(plain, 'best', hash, RANKING_EPOCH_CURRENT, rankingAsOf, 'required', 1, 2);
      fail('expected');
    } catch (e) {
      expect((e as AppError).code).toBe(ErrorCodes.VALIDATION_ERROR);
    }
  });
});
