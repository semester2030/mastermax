import {
  aggregateLabelPhrases,
  buildSearchPredicate,
  flattenSearchParams,
  normalizeSearchText,
  planSearchTokens,
  SEARCH_PERF_STATUS,
  tokenizeSearchQuery,
} from '../../src/modules/filters/application/discovery-search-contract';

describe('Gate 7B.0.5 — G7B05-SEARCH phrase Set merge', () => {
  it('G7B05-SEARCH-01 two independent phrase rows merge; no type dropped; perf deferred', () => {
    const agg = aggregateLabelPhrases([
      { phrase: 'قصر أفراح', venueTypes: ['hall'] },
      { phrase: 'قصر أفراح', venueTypes: ['wedding_palace'] },
    ]);
    expect([...agg.get(normalizeSearchText('قصر أفراح'))!].sort()).toEqual([
      'hall',
      'wedding_palace',
    ]);

    const tokens = tokenizeSearchQuery('ملقا قصر أفراح');
    const { plans, phraseVenueTypes } = planSearchTokens(tokens, [
      { phrase: 'قصر أفراح', venueTypes: ['hall'] },
      { phrase: 'قصر أفراح', venueTypes: ['wedding_palace'] },
    ]);
    expect(phraseVenueTypes.sort()).toEqual(['hall', 'wedding_palace']);
    expect(plans.map((p) => p.raw)).toEqual([normalizeSearchText('ملقا')]);
    expect(SEARCH_PERF_STATUS).toMatch(/7B31|7B5|EXPLAIN/);

    const { sql } = buildSearchPredicate(plans.length, true, 1);
    expect(sql).toContain('ANY($');
    const params = flattenSearchParams(plans, phraseVenueTypes);
    expect(params[params.length - 1]).toEqual(expect.arrayContaining(['hall', 'wedding_palace']));
  });
});
