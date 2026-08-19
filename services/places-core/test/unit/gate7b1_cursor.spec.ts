import {
  buildQueryHash,
  canonicalizeResolvedDto,
  decodeCursorV2,
  encodeCursorV2,
  RANKING_EPOCH_CURRENT,
} from '../../src/modules/filters/application/discovery-cursor-v2';
import { buildCursorV2Keyset } from '../../src/modules/filters/application/discovery-keyset-v2';
import { bestScoreSqlExpr } from '../../src/modules/filters/application/discovery-best-score';
import { cursorV2FromRow } from '../../src/modules/filters/application/discovery-cursor-encode';
import { encodeCursor } from '../../src/modules/filters/application/discovery-cursor';
import { newId } from '../../src/shared/ids/ids';

const rankingAsOf = new Date().toISOString().replace(/\.\d{3}Z$/, '.000Z');

function hashFor(body: Record<string, unknown>): string {
  return buildQueryHash({
    resolvedCanonicalJson: canonicalizeResolvedDto({ ...body }),
    surface: (body.surface as string) ?? 'search',
    q: typeof body.q === 'string' && body.q.trim() ? body.q : null,
    originLat: body.lat != null ? Number(body.lat) : null,
    originLng: body.lng != null ? Number(body.lng) : null,
    anchorVenueId: typeof body.anchorVenueId === 'string' ? body.anchorVenueId : null,
    rankingVersion: RANKING_EPOCH_CURRENT,
    rankingEpoch: RANKING_EPOCH_CURRENT,
    rankingAsOf,
    diversityVersion: 0,
    diversityK: 0,
  });
}

describe('Gate 7B.1 — G7B1-CURSOR v2 canonical', () => {
  it('G7B1-CURSOR-01 rejects legacy v1 cursor', () => {
    const v1 = encodeCursor({
      v: 1,
      sort: 'near_me',
      sv: '100',
      id: newId(),
    });
    expect(() =>
      decodeCursorV2(v1, 'near_me', 'a'.repeat(32), RANKING_EPOCH_CURRENT, rankingAsOf, 'forbidden'),
    ).toThrow(/version unsupported/);
  });

  it('G7B1-CURSOR-02 rejects queryHash mismatch before SQL', () => {
    const body = { sort: 'near_me', lat: 24.7, lng: 46.7 };
    const hash = hashFor(body);
    const enc = encodeCursorV2(
      {
        v: 2,
        sort: 'near_me',
        queryHash: hash,
        rankingEpoch: RANKING_EPOCH_CURRENT,
        rankingAsOf,
        sv: '1200',
        id: newId(),
      },
      'forbidden',
    );
    expect(() =>
      decodeCursorV2(enc, 'near_me', '0'.repeat(32), RANKING_EPOCH_CURRENT, rankingAsOf, 'forbidden'),
    ).toThrow(/queryHash/);
  });

  it('G7B1-CURSOR-03 rejects rankingEpoch mismatch', () => {
    const hash = hashFor({ sort: 'best' });
    const enc = encodeCursorV2(
      {
        v: 2,
        sort: 'best',
        queryHash: hash,
        rankingEpoch: RANKING_EPOCH_CURRENT,
        rankingAsOf,
        sv: '0.500000',
        sv2: '4.50',
        sv3: '10',
        id: newId(),
      },
      'forbidden',
    );
    expect(() => decodeCursorV2(enc, 'best', hash, 99, rankingAsOf, 'forbidden')).toThrow(
      /rankingEpoch/,
    );
  });

  it('G7B1-CURSOR-04 near_place keyset uses same distance expr params', () => {
    const cur = {
      v: 2 as const,
      sort: 'near_place' as const,
      queryHash: 'b'.repeat(32),
      rankingEpoch: RANKING_EPOCH_CURRENT,
      rankingAsOf,
      sv: '500',
      id: newId(),
    };
    const ks = buildCursorV2Keyset({
      sort: 'near_place',
      cur,
      priorCount: 3,
      priceExpr: 'p',
      distLatParam: 1,
      distLngParam: 2,
    });
    expect(ks.sql).toContain('$1');
    expect(ks.sql).toContain('$2');
    expect(ks.params).toEqual(['500', cur.id]);
  });

  it('G7B1-CURSOR-05 cursorV2FromRow near_me matches ORDER BY meters', () => {
    const hash = hashFor({ sort: 'near_me', lat: 1, lng: 2 });
    const enc = cursorV2FromRow(
      'near_me',
      { id: newId(), distance_meters: 1500 },
      { queryHash: hash, rankingAsOf },
    );
    const decoded = decodeCursorV2(
      enc,
      'near_me',
      hash,
      RANKING_EPOCH_CURRENT,
      rankingAsOf,
      'forbidden',
    );
    expect(decoded.sv).toBe('1500');
  });

  it('G7B1-CURSOR-06 best keyset tuple matches best_score ORDER BY', () => {
    const score = bestScoreSqlExpr(4);
    const cur = {
      v: 2 as const,
      sort: 'best' as const,
      queryHash: 'c'.repeat(32),
      rankingEpoch: RANKING_EPOCH_CURRENT,
      rankingAsOf,
      sv: '0.700000',
      sv2: '4.20',
      sv3: '8',
      id: newId(),
    };
    const ks = buildCursorV2Keyset({
      sort: 'best',
      cur,
      priorCount: 0,
      priceExpr: 'p',
      bestScoreExpr: score,
    });
    expect(ks.sql).toContain(score);
    expect(ks.params).toEqual(['0.700000', '4.20', '8', cur.id]);
  });
});
