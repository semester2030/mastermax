import { Pool } from 'pg';
import {
  buildSearchPredicate,
  escapeLikeLiteral,
  flattenSearchParams,
  normalizeSearchText,
  planSearchTokens,
  SEARCH_PERF_STATUS,
  tokenizeSearchQuery,
} from '../../src/modules/filters/application/discovery-search-contract';
import { testEnv } from '../helpers/test-app';

describe('Gate 7B.0.5 — G7B05-SEARCH-02 real PG normalize + location + binds', () => {
  let pool: Pool;

  beforeAll(async () => {
    testEnv();
    pool = new Pool({ connectionString: process.env.DATABASE_URL });
    await pool.query('CREATE EXTENSION IF NOT EXISTS pg_trgm');
  });

  afterAll(async () => {
    await pool.end();
  });

  it('G7B05-SEARCH-02 مَلْقَا قصر أفراح — NFC/diacritics + ILIKE/similarity + ANY', async () => {
    expect(SEARCH_PERF_STATUS).toMatch(/7B31|7B5|EXPLAIN/);
    await pool.query(`
      CREATE TEMP TABLE IF NOT EXISTS g7b05_search_v (
        id text PRIMARY KEY,
        venue_type text NOT NULL,
        search_document text NOT NULL
      )
    `);
    await pool.query('TRUNCATE g7b05_search_v');

    const docHall = normalizeSearchText('قاعة قصر أفراح في ملقا');
    const docWp = normalizeSearchText('قصر أفراح الرياض');
    const docOther = normalizeSearchText('شاليه بعيدة');
    await pool.query(
      `INSERT INTO g7b05_search_v (id, venue_type, search_document) VALUES
        ('1', 'hall', $1),
        ('2', 'wedding_palace', $2),
        ('3', 'chalet', $3)`,
      [docHall, docWp, docOther],
    );

    // Diacritics on ملقا must normalize; multi-word phrase → both types
    const tokens = tokenizeSearchQuery('مَلْقَا قصر أفراح');
    expect(tokens[0]).toBe(normalizeSearchText('ملقا'));

    const { plans, phraseVenueTypes } = planSearchTokens(tokens, [
      { phrase: 'قصر أفراح', venueTypes: ['hall'] },
      { phrase: 'قصر أفراح', venueTypes: ['wedding_palace'] },
    ]);
    expect(phraseVenueTypes.sort()).toEqual(['hall', 'wedding_palace']);
    expect(plans).toHaveLength(1); // ملقا remains
    expect(plans[0].raw).toBe(normalizeSearchText('ملقا'));
    expect(plans[0].escaped).toBe(escapeLikeLiteral(plans[0].raw));

    const { sql, bindCount } = buildSearchPredicate(plans.length, true, 1);
    const params = flattenSearchParams(plans, phraseVenueTypes);
    expect(bindCount).toBe(params.length);
    expect(sql).not.toContain('$tokens');
    expect(sql).toMatch(/v\.search_document % \$1/);
    expect(sql).toContain(`ILIKE '%' || $2 || '%'`);

    const res = await pool.query(
      `SELECT id, venue_type FROM g7b05_search_v v WHERE ${sql} ORDER BY id`,
      params,
    );
    // location token ملقا AND phrase types → only hall (doc contains ملقا)
    expect(res.rows.map((r) => r.id)).toEqual(['1']);
    expect(res.rows[0].venue_type).toBe('hall');
  });
});
