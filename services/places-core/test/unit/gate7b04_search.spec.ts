import {
  buildSearchPredicate,
  flattenSearchParams,
  normalizeSearchText,
  planSearchTokens,
  SEARCH_PERF_STATUS,
  tokenizeSearchQuery,
} from '../../src/modules/filters/application/discovery-search-contract';

describe('Gate 7B.0.4 — G7B04-SEARCH normalize + multi-type labels', () => {
  it('G7B04-SEARCH-01 NFC/AR normalize; one label → many types; perf deferred', () => {
    // Alef variants + tatweel + diacritics collapse
    expect(normalizeSearchText('أَفْنـادق')).toBe(normalizeSearchText('افنادق'));
    expect(normalizeSearchText('Hotel')).toBe('hotel');

    const tokens = tokenizeSearchQuery('ملقا قصر أفراح');
    const { plans, phraseVenueTypes } = planSearchTokens(tokens, [
      { phrase: 'قصر أفراح', venueTypes: ['hall', 'wedding_palace'] },
      { phrase: 'قصر أفراح', venueTypes: ['hall'] }, // merge via Set — no drop
    ]);
    expect(phraseVenueTypes.sort()).toEqual(['hall', 'wedding_palace']);
    expect(plans.map((p) => p.raw)).toEqual([normalizeSearchText('ملقا')]);

    const { sql } = buildSearchPredicate(plans.length, true, 1);
    expect(sql).toContain('ANY($');
    expect(SEARCH_PERF_STATUS).toMatch(/7B31|7B5|EXPLAIN/);
    const params = flattenSearchParams(plans, phraseVenueTypes);
    expect(Array.isArray(params[params.length - 1])).toBe(true);
  });
});
