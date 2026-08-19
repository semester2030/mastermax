import {
  buildQueryHash,
  canonicalizeResolvedDto,
  decodeCursorV2,
  encodeCursorV2,
  DIVERSITY_K_DEFAULT,
  DIVERSITY_VERSION_CURRENT,
  RANKING_EPOCH_CURRENT,
} from '../../src/modules/filters/application/discovery-cursor-v2';
import { decimalStringInRange } from '../../src/modules/filters/application/discovery-cursor-v2-validate';
import { AppError } from '../../src/shared/errors/app-error';
import { ErrorCodes } from '../../src/shared/errors/error-codes';

describe('Gate 7B.0.3 — Cursor v2 context match + nested nulls', () => {
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
    diversityVersion: DIVERSITY_VERSION_CURRENT,
    diversityK: DIVERSITY_K_DEFAULT,
    sv: '0.850000',
    sv2: '4.50',
    sv3: '12',
    id: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
  };

  it('G7B03-CURSOR-01 rejects diversityVersion/K mismatch vs decode context', () => {
    const encoded = encodeCursorV2({
      ...base,
      diversity: { lastType: 'hotel', streak: 1, perTypeAfter: {} },
    }, 'required');
    expect(() =>
      decodeCursorV2(encoded, 'best', hash, RANKING_EPOCH_CURRENT, rankingAsOf, 'required', 1, 9),
    ).toThrow(/diversityK mismatch/);
    expect(() =>
      decodeCursorV2(encoded, 'best', hash, RANKING_EPOCH_CURRENT, rankingAsOf, 'required', 99, 2),
    ).toThrow(/diversityVersion mismatch/);
    expect(
      decodeCursorV2(encoded, 'best', hash, RANKING_EPOCH_CURRENT, rankingAsOf, 'required', 1, 2).diversityK,
    ).toBe(2);
  });

  it('G7B03-CURSOR-02 nested null/array/extra → VALIDATION_ERROR; decimal without Number loss', () => {
    expect(() =>
      encodeCursorV2({
        ...base,
        diversity: {
          lastType: 'hotel',
          streak: 1,
          perTypeAfter: { hotel: null as never },
        },
      }, 'required'),
    ).toThrow(AppError);

    try {
      encodeCursorV2({
        ...base,
        diversity: {
          lastType: 'hotel',
          streak: 1,
          perTypeAfter: { hotel: null as never },
        },
      }, 'required');
      fail('expected throw');
    } catch (e) {
      expect(e).toBeInstanceOf(AppError);
      expect((e as AppError).code).toBe(ErrorCodes.VALIDATION_ERROR);
    }

    expect(() =>
      encodeCursorV2({
        ...base,
        diversity: {
          lastType: 'hotel',
          streak: 1,
          perTypeAfter: { hotel: [] as never },
        },
      }, 'required'),
    ).toThrow(/perTypeAfter/);

    expect(() =>
      encodeCursorV2({
        ...base,
        diversity: {
          lastType: 'hotel',
          streak: 1,
          perTypeAfter: {
            hotel: {
              sv: '0.850000',
              sv2: '4.50',
              sv3: '12',
              id: base.id,
              extra: true,
            } as never,
          },
        },
      }, 'required'),
    ).toThrow(/unexpected diversity after field/);

    // IEEE Number would lose precision distinguishing these at high scale;
    // fixed-scale BigInt compare must accept exact 0.999999 and reject 1.000001.
    expect(() => decimalStringInRange('0.999999', '0', '1', 6, 'sv')).not.toThrow();
    expect(() => decimalStringInRange('1.000001', '0', '1', 6, 'sv')).toThrow(/out of range/);
    expect(() => decimalStringInRange('0.8500000001', '0', '1', 6, 'sv')).toThrow(/malformed/);
  });
});
