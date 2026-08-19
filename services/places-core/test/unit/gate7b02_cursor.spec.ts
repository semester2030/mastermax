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

describe('Gate 7B.0.2 — Cursor v2 strict validation', () => {
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

  it('G7B02-CURSOR-01 rejects impossible datetime and extra fields', () => {
    expect(() =>
      encodeCursorV2({
        ...base,
        sort: 'newest',
        sv: '2035-99-99T99:99:99Z',
        sv2: undefined,
        sv3: undefined,
      } as never, 'forbidden'),
    ).toThrow(AppError);

    const bad = Buffer.from(
      JSON.stringify({ ...base, extra: true }),
      'utf8',
    ).toString('base64url');
    expect(() => decodeCursorV2(bad, 'best', hash, RANKING_EPOCH_CURRENT, rankingAsOf, 'forbidden')).toThrow(
      /unexpected cursor field/,
    );
  });

  it('G7B02-CURSOR-02 validates diversityVersion/K/integer streak and perTypeAfter keysets', () => {
    expect(() =>
      encodeCursorV2({
        ...base,
        diversityVersion: 1.5 as never,
        diversityK: 2,
        diversity: { lastType: 'hotel', streak: 1, perTypeAfter: {} },
      }, 'required'),
    ).toThrow(/diversityVersion/);

    expect(() =>
      encodeCursorV2({
        ...base,
        diversityVersion: DIVERSITY_VERSION_CURRENT,
        diversityK: DIVERSITY_K_DEFAULT,
        diversity: {
          lastType: 'hotel',
          streak: 1.5 as never,
          perTypeAfter: {},
        },
      }, 'required'),
    ).toThrow(/streak/);

    expect(() =>
      encodeCursorV2({
        ...base,
        diversityVersion: DIVERSITY_VERSION_CURRENT,
        diversityK: DIVERSITY_K_DEFAULT,
        diversity: {
          lastType: 'hotel',
          streak: 1,
          perTypeAfter: {
            hotel: { sv: 'not-a-score', sv2: '4', sv3: '1', id: base.id },
          },
        },
      }, 'required'),
    ).toThrow(/perTypeAfter/);

    const ok = encodeCursorV2({
      ...base,
      diversityVersion: DIVERSITY_VERSION_CURRENT,
      diversityK: DIVERSITY_K_DEFAULT,
      diversity: {
        lastType: 'hotel',
        streak: 2,
        perTypeAfter: {
          hotel: { sv: '0.850000', sv2: '4.50', sv3: '12', id: base.id },
        },
      },
    }, 'required');
    expect(
      decodeCursorV2(ok, 'best', hash, RANKING_EPOCH_CURRENT, rankingAsOf, 'required', DIVERSITY_VERSION_CURRENT, DIVERSITY_K_DEFAULT).diversity?.streak,
    ).toBe(2);
  });
});
