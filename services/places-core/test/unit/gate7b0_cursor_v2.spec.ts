import {
  buildQueryHash,
  buildWorstCaseBestDiversityCursor,
  canonicalizeResolvedDto,
  CURSOR_V2_ORDER_KEYS,
  decodeCursorV2,
  DISCOVERY_CURSOR_MAX_LENGTH,
  distanceKmToMeters,
  distanceMetersSqlExpr,
  DIVERSITY_K_DEFAULT,
  DIVERSITY_VERSION_CURRENT,
  encodeCursorV2,
  formatDistanceMetersCursorSv,
  RANKING_EPOCH_CURRENT,
} from '../../src/modules/filters/application/discovery-cursor-v2';
import { AppError } from '../../src/shared/errors/app-error';

describe('Gate 7B.0.1 — Cursor v2 contract', () => {
  const rankingAsOf = new Date().toISOString().replace(/\.\d{3}Z$/, '.000Z');
  const resolved = canonicalizeResolvedDto({
    category: 'hotel',
    city: 'Riyadh',
    sort: 'best',
    surface: 'feed',
    limit: 20,
    cursor: 'should-be-stripped',
  });

  const ctx = {
    resolvedCanonicalJson: resolved,
    surface: 'feed',
    q: null as string | null,
    originLat: 24.7,
    originLng: 46.7,
    anchorVenueId: null as string | null,
    rankingVersion: 1,
    rankingEpoch: RANKING_EPOCH_CURRENT,
    rankingAsOf,
    diversityVersion: DIVERSITY_VERSION_CURRENT,
    diversityK: DIVERSITY_K_DEFAULT,
  };

  it('G7B01-CUR-01 canonicalizer strips cursor and sorts keys', () => {
    const a = canonicalizeResolvedDto({ b: 1, a: 2, cursor: 'x' });
    const b = canonicalizeResolvedDto({ a: 2, b: 1, cursor: 'y' });
    expect(a).toBe(b);
    expect(a).not.toContain('cursor');
  });

  it('G7B01-CUR-02 queryHash includes rankingAsOf and diversity version/K', () => {
    const h1 = buildQueryHash(ctx);
    const h2 = buildQueryHash({
      ...ctx,
      rankingAsOf: new Date(Date.now() - 1000).toISOString().replace(/\.\d{3}Z$/, '.000Z'),
    });
    const h3 = buildQueryHash({ ...ctx, diversityK: 3 });
    expect(h1).toHaveLength(32);
    expect(h1).not.toBe(h2);
    expect(h1).not.toBe(h3);
  });

  it('G7B01-CUR-03 order keys + distanceMeters SQL shared expression', () => {
    expect(CURSOR_V2_ORDER_KEYS.near_me).toEqual(['distance_meters', 'id']);
    expect(CURSOR_V2_ORDER_KEYS.best).toContain('best_score');
    const sql = distanceMetersSqlExpr(1, 2);
    expect(sql).toContain('ROUND(');
    expect(sql).toContain('::bigint');
    expect(sql).toContain('$1');
    expect(sql).toContain('$2');
  });

  it('G7B01-CUR-04 meters integer; rejects float', () => {
    expect(distanceKmToMeters(1.23456)).toBe(1235);
    expect(formatDistanceMetersCursorSv(1235)).toBe('1235');
    expect(() => formatDistanceMetersCursorSv(1.5)).toThrow(AppError);
  });

  it('G7B01-CUR-05 validates sv keys, rejects v1 / hash / epoch / rankingAsOf mismatch', () => {
    const hash = buildQueryHash(ctx);
    const v2 = encodeCursorV2({
      v: 2,
      sort: 'best',
      queryHash: hash,
      rankingEpoch: RANKING_EPOCH_CURRENT,
      rankingAsOf,
      sv: '0.850000',
      sv2: '4.50',
      sv3: '12',
      id: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
    }, 'forbidden');
    expect(decodeCursorV2(v2, 'best', hash, RANKING_EPOCH_CURRENT, rankingAsOf, 'forbidden').sv3).toBe('12');

    const v1 = Buffer.from(
      JSON.stringify({
        v: 1,
        sort: 'best',
        sv: '4',
        sv2: '1',
        id: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
      }),
      'utf8',
    ).toString('base64url');
    expect(() => decodeCursorV2(v1, 'best', hash, RANKING_EPOCH_CURRENT, rankingAsOf, 'forbidden')).toThrow(
      /cursor version unsupported/,
    );
    expect(() => decodeCursorV2(v2, 'best', '0'.repeat(32), RANKING_EPOCH_CURRENT, rankingAsOf, 'forbidden')).toThrow(
      /queryHash/,
    );
    expect(() => decodeCursorV2(v2, 'best', hash, 99, rankingAsOf, 'forbidden')).toThrow(/rankingEpoch/);
    expect(() =>
      decodeCursorV2(v2, 'best', hash, RANKING_EPOCH_CURRENT, '2026-08-14T00:00:00.000Z', 'forbidden'),
    ).toThrow(/rankingAsOf/);
  });

  it('G7B01-CUR-06 worst-case server cursor fits DTO max and round-trips', () => {
    // Freeze time check: buildWorstCase uses fixed rankingAsOf — assert length only here.
    const encoded = buildWorstCaseBestDiversityCursor();
    expect(encoded.length).toBeGreaterThan(200);
    expect(encoded.length).toBeLessThanOrEqual(DISCOVERY_CURSOR_MAX_LENGTH);
    expect(DISCOVERY_CURSOR_MAX_LENGTH).toBe(4096);
    const parsed = JSON.parse(Buffer.from(encoded, 'base64url').toString('utf8')) as {
      sort: string;
      diversity: { perTypeAfter: Record<string, unknown> };
    };
    expect(parsed.sort).toBe('best');
    expect(Object.keys(parsed.diversity.perTypeAfter).length).toBeGreaterThanOrEqual(6);
    // Round-trip: encode → decode bytes → re-encode
    const again = Buffer.from(JSON.stringify(parsed), 'utf8').toString('base64url');
    expect(again.length).toBeLessThanOrEqual(DISCOVERY_CURSOR_MAX_LENGTH);
  });

  it('G7B01-CUR-07 rejects forbidden sv2 on near_me and missing sv3 on best', () => {
    const hash = buildQueryHash(ctx);
    expect(() =>
      decodeCursorV2(
        encodeCursorV2({
          v: 2,
          sort: 'near_me',
          queryHash: hash,
          rankingEpoch: 1,
          rankingAsOf,
          sv: '100',
          sv2: '1',
          id: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
        }, 'forbidden'),
        'near_me',
        hash,
        1,
        rankingAsOf,
        'forbidden',
      ),
    ).toThrow(/sv2/);
    expect(() =>
      decodeCursorV2(
        encodeCursorV2({
          v: 2,
          sort: 'best',
          queryHash: hash,
          rankingEpoch: 1,
          rankingAsOf,
          sv: '0.5',
          sv2: '4',
          id: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
        }, 'forbidden'),
        'best',
        hash,
        1,
        rankingAsOf,
        'forbidden',
      ),
    ).toThrow(/sv3/);
  });
});
