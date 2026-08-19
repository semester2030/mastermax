import {
  buildSearchPredicate,
  escapeLikeLiteral,
  flattenSearchParams,
  planSearchTokens,
  searchRankSql,
  tokenizeSearchQuery,
} from '../../src/modules/filters/application/discovery-search-contract';
import { AppError } from '../../src/shared/errors/app-error';

describe('Gate 7B.0.2 — G7B02-SEARCH-01 token AND + label per-token', () => {
  it('G7B02-SEARCH-01 AND tokens; type-label does not waive other tokens; escape % _ \\; reject >8', () => {
    expect(escapeLikeLiteral('a%b_c\\d')).toBe('a\\%b\\_c\\\\d');
    expect(() => tokenizeSearchQuery('a b c d e f g h i')).toThrow(AppError);

    const tokens = tokenizeSearchQuery('ملقا فندق');
    const { plans, phraseVenueTypes } = planSearchTokens(tokens, [
      { phrase: 'فندق', venueTypes: ['hotel'] },
    ]);
    expect(plans).toHaveLength(2);
    expect(plans[0].venueTypesFromLabel).toEqual([]);
    expect(plans[1].venueTypesFromLabel).toEqual(['hotel']);
    expect(phraseVenueTypes).toHaveLength(0);
    const { sql } = buildSearchPredicate(plans.length, false, 1);
    expect(sql).toContain(' AND ');
    expect(sql.match(/ILIKE/g)?.length).toBe(2);
    expect(sql).not.toContain('$tokens');
    const params = flattenSearchParams(plans, []);
    expect(params[0]).toBe(plans[0].raw);
    expect(params[1]).toBe(plans[0].escaped);
    expect(searchRankSql(10)).toMatch(/\$10::text\[\]/);
  });
});
