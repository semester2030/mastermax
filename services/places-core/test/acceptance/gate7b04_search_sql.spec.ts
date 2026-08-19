import { Pool } from 'pg';
import {
  buildSearchPredicate,
  flattenSearchParams,
  normalizeSearchText,
  planSearchTokens,
  tokenizeSearchQuery,
} from '../../src/modules/filters/application/discovery-search-contract';
import { testEnv } from '../helpers/test-app';

describe('Gate 7B.0.4 — G7B04-SEARCH-02 real SQL multi-word + normalize', () => {
  let pool: Pool;

  beforeAll(async () => {
    testEnv();
    pool = new Pool({ connectionString: process.env.DATABASE_URL });
    await pool.query('CREATE EXTENSION IF NOT EXISTS pg_trgm');
  });

  afterAll(async () => {
    await pool.end();
  });

  it('G7B04-SEARCH-02 SQL finds multi-word label types + normalized Arabic', async () => {
    await pool.query(`
      CREATE TEMP TABLE IF NOT EXISTS g7b04_search_v (
        id text PRIMARY KEY,
        venue_type text NOT NULL,
        search_document text NOT NULL
      )
    `);
    await pool.query('TRUNCATE g7b04_search_v');
    const doc1 = normalizeSearchText('شاليه ملقا الفاخر');
    const doc2 = normalizeSearchText('قصر أفراح الرياض');
    await pool.query(`INSERT INTO g7b04_search_v (id, venue_type, search_document) VALUES
      ('1', 'chalet', $1),
      ('2', 'hall', $2),
      ('3', 'wedding_palace', $2)`, [doc1, doc2]);

    const tokens = tokenizeSearchQuery('قصر أفراح');
    const { plans, phraseVenueTypes } = planSearchTokens(tokens, [
      { phrase: 'قصر أفراح', venueTypes: ['hall', 'wedding_palace'] },
    ]);
    const { sql, bindCount } = buildSearchPredicate(plans.length, phraseVenueTypes.length > 0, 1);
    const params = flattenSearchParams(plans, phraseVenueTypes);
    expect(bindCount).toBe(params.length);
    expect(sql).not.toContain('$tokens');

    const res = await pool.query(
      `SELECT id, venue_type FROM g7b04_search_v v WHERE ${sql} ORDER BY id`,
      params,
    );
    expect(res.rows.map((r) => r.id).sort()).toEqual(['2', '3']);
    expect(res.rows.every((r) => r.venue_type !== 'chalet')).toBe(true);
  });
});
