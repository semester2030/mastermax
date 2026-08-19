import {
  buildSearchPredicate,
  flattenSearchParams,
  normalizeSearchText,
  planSearchTokens,
  searchRankSql,
  SEARCH_PERF_STATUS,
  tokenizeSearchQuery,
} from '../../src/modules/filters/application/discovery-search-contract';

describe('Gate 7B.0.3 — G7B03-SEARCH-01 binds + multi-word labels', () => {
  it('G7B03-SEARCH-01 raw≠escaped similarity binds; multi-word labels; SQL syntax; perf deferred', () => {
    const tokens = tokenizeSearchQuery('ملقا wedding hall فندق');
    const { plans, phraseVenueTypes } = planSearchTokens(tokens, [
      { phrase: 'wedding hall', venueTypes: ['hall', 'wedding_palace'] },
      { phrase: 'فندق', venueTypes: ['hotel'] },
    ]);
    expect(phraseVenueTypes.sort()).toEqual(['hall', 'wedding_palace']);
    expect(plans.map((p) => p.raw)).toEqual([
      normalizeSearchText('ملقا'),
      normalizeSearchText('فندق'),
    ]);
    expect(plans[1].venueTypesFromLabel).toEqual(['hotel']);

    const startP = 5;
    const { sql, bindCount } = buildSearchPredicate(plans.length, phraseVenueTypes.length > 0, startP);
    expect(sql).not.toMatch(/\$tokens\b/);
    expect(sql).toContain('v.search_document % $5');
    expect(sql).toContain(`ILIKE '%' || $7 || '%'`);
    expect(sql).toContain('= ANY($');
    expect(bindCount).toBe(plans.length * 3 + 1);

    const params = flattenSearchParams(plans, phraseVenueTypes);
    expect(params[0]).toBe(plans[0].raw);
    expect(params[2]).toBe(plans[0].escaped);

    const escPlan = planSearchTokens(['a%b'], []);
    const escParams = flattenSearchParams(escPlan.plans, []);
    expect(escParams[0]).toBe('a%b');
    expect(escParams[1]).toBe('a\\%b');
    expect(escParams[0]).not.toBe(escParams[1]);

    expect(searchRankSql(12)).toContain('$12::text[]');
    expect(SEARCH_PERF_STATUS).toMatch(/7B31|7B5|EXPLAIN/);
  });
});
