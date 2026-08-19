import { bestScoreSqlExpr } from '../../src/modules/filters/application/discovery-best-score';
import {
  assertDiscoveryLimits,
  buildDiscoveryQuery,
} from '../../src/modules/filters/application/discovery-query';
import { buildCursorV2Keyset } from '../../src/modules/filters/application/discovery-keyset-v2';
import {
  assertRankingAsOfFresh,
  decodeCursorV2,
  encodeCursorV2,
  RANKING_AS_OF_TTL_MS,
  RANKING_EPOCH_CURRENT,
} from '../../src/modules/filters/application/discovery-cursor-v2';
import { DiscoverySearchDto } from '../../src/shared/api/dto/discovery-search.dto';
import { APPROVED_VIDEO_EXISTS } from '../../src/modules/filters/application/discovery-surface';
import { newId } from '../../src/shared/ids/ids';

const rankingAsOf = new Date().toISOString().replace(/\.\d{3}Z$/, '.000Z');

describe('Gate 7B.3 — G7B3-RANK', () => {
  it('G7B3-RANK-01 locked formula: static column + freshness weight (no availability/distance)', () => {
    const expr = bestScoreSqlExpr(3);
    // Gate 7B.5.1: rating+reviews+video live in venues.best_score_static (STORED);
    // query adds freshness 0.15*EXP — algebra matches Gate 7B.3 locked equation.
    expect(expr).toContain('best_score_static');
    expect(expr).toContain('0.15');
    expect(expr).toContain('EXP');
    expect(expr).not.toMatch(/availability/i);
    expect(expr).not.toMatch(/distance/i);
    expect(APPROVED_VIDEO_EXISTS).toContain('has_playable_video');
  });

  it('G7B3-RANK-02 sort=best ORDER BY score, rating, reviews, id', () => {
    const q = buildDiscoveryQuery({ sort: 'best', surface: 'search' } as DiscoverySearchDto, {
      rankingAsOf,
    });
    expect(q.orderBySql.replace(/\s+/g, ' ')).toMatch(
      /numeric\(8,6\) \) DESC NULLS LAST, v\.weighted_rating DESC NULLS LAST, v\.reviews_count DESC, v\.id ASC/,
    );
    expect(q.selectExtras).toContain('AS best_score');
  });

  it('G7B3-RANK-03 sort=rating independent of best_score order', () => {
    const q = buildDiscoveryQuery({ sort: 'rating', surface: 'search' } as DiscoverySearchDto, {
      rankingAsOf,
    });
    expect(q.orderBySql).toContain('v.weighted_rating DESC');
    expect(q.orderBySql).not.toContain('best_score');
  });

  it('G7B3-RANK-04 rankingAsOf TTL 15m', () => {
    expect(RANKING_AS_OF_TTL_MS).toBe(15 * 60 * 1000);
    assertRankingAsOfFresh(rankingAsOf);
    expect(() =>
      assertRankingAsOfFresh(new Date(Date.now() - RANKING_AS_OF_TTL_MS - 1000).toISOString()),
    ).toThrow(/expired/);
  });

  it('G7B3-RANK-05 cursor rankingAsOf mismatch rejected', () => {
    const enc = encodeCursorV2(
      {
        v: 2,
        sort: 'best',
        queryHash: 'd'.repeat(32),
        rankingEpoch: RANKING_EPOCH_CURRENT,
        rankingAsOf,
        sv: '0.500000',
        sv2: '4.00',
        sv3: '1',
        id: newId(),
      },
      'forbidden',
    );
    expect(() =>
      decodeCursorV2(
        enc,
        'best',
        'd'.repeat(32),
        RANKING_EPOCH_CURRENT,
        '2020-01-01T00:00:00.000Z',
        'forbidden',
      ),
    ).toThrow(/rankingAsOf/);
  });

  it('G7B3-RANK-06 cursor tuple matches ORDER BY keys', () => {
    const score = bestScoreSqlExpr(1);
    const id = newId();
    const ks = buildCursorV2Keyset({
      sort: 'best',
      cur: {
        v: 2,
        sort: 'best',
        queryHash: 'e'.repeat(32),
        rankingEpoch: RANKING_EPOCH_CURRENT,
        rankingAsOf,
        sv: '0.800000',
        sv2: '4.80',
        sv3: '20',
        id,
      },
      priorCount: 2,
      priceExpr: 'p',
      bestScoreExpr: score,
    });
    expect(ks.params).toEqual(['0.800000', '4.80', '20', id]);
    expect(ks.sql).toContain('v.weighted_rating');
    expect(ks.sql).toContain('v.reviews_count');
  });

  it('G7B3-RANK-07 search_rank requires q', () => {
    expect(() =>
      assertDiscoveryLimits({ sort: 'search_rank' } as DiscoverySearchDto),
    ).toThrow(/search_rank requires q/);
  });

  it('G7B3-RANK-08 explicit sort keeps order when q present (filter only)', () => {
    const q = buildDiscoveryQuery(
      {
        sort: 'newest',
        q: 'hotel',
        surface: 'search',
      } as DiscoverySearchDto,
      {
        rankingAsOf,
        searchPlans: [{ raw: 'hotel', escaped: 'hotel', venueTypesFromLabel: [] }],
      },
    );
    expect(q.orderBySql).toMatch(/created_at/);
    expect(q.whereSql).toMatch(/search_document/);
  });
});
