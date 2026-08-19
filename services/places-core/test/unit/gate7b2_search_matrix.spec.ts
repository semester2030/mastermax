import {
  assertSearchQuery,
  escapeLikeLiteral,
  flattenSearchParams,
  normalizeSearchText,
  planSearchTokens,
  prepareSearchQuery,
  searchRankSql,
  tokenizeSearchQuery,
  buildSearchPredicate,
} from '../../src/modules/filters/application/discovery-search-contract';
import { AppError } from '../../src/shared/errors/app-error';

describe('Gate 7B.2 / 7B.3.1 — G7B2-SEARCH matrix (updated)', () => {
  it('G7B2-SEARCH-01 Arabic NFC + diacritics + tatweel normalize', () => {
    expect(normalizeSearchText('مَلْقَـا')).toBe(normalizeSearchText('ملقا'));
  });

  it('G7B2-SEARCH-02 English lower + whitespace collapse', () => {
    expect(normalizeSearchText('  Hotel   RIYADH ')).toBe('hotel riyadh');
  });

  it('G7B2-SEARCH-03 token AND with label merge for same phrase', () => {
    const tokens = tokenizeSearchQuery('ملقا قصر أفراح');
    const { plans, phrasePlans } = planSearchTokens(tokens, [
      { phrase: 'قصر أفراح', venueTypes: ['hall'] },
      { phrase: 'قصر أفراح', venueTypes: ['wedding_palace'] },
    ]);
    expect(phrasePlans).toHaveLength(1);
    expect(phrasePlans[0].venueTypes.sort()).toEqual(['hall', 'wedding_palace']);
    expect(plans.map((p) => p.raw)).toEqual([normalizeSearchText('ملقا')]);
  });

  it('G7B2-SEARCH-04 raw similarity binds separated from escaped ILIKE', () => {
    const { plans } = planSearchTokens(['hotel'], []);
    const params = flattenSearchParams(plans, []);
    expect(params[0]).toBe('hotel');
    expect(params[1]).toBe(escapeLikeLiteral('hotel'));
    const { sql } = buildSearchPredicate(1, 0, 1);
    expect(sql).toMatch(/v\.search_document % \$1/);
    expect(sql).toMatch(/ILIKE '%' \|\| \$2 \|\| '%' ESCAPE/);
  });

  it('G7B2-SEARCH-05 blank/whitespace = no search', () => {
    expect(prepareSearchQuery('   ')).toBeNull();
    expect(() => assertSearchQuery('   ')).toThrow(/blank/);
  });

  it('G7B2-SEARCH-06 reject q too short (single char)', () => {
    expect(() => prepareSearchQuery('a')).toThrow(/too short/);
  });

  it('G7B2-SEARCH-07 reject >8 tokens', () => {
    expect(() => prepareSearchQuery('a b c d e f g h i')).toThrow(/too many tokens/);
  });

  it('G7B2-SEARCH-08 % _ \\ are literal via escaped binds', () => {
    const tokens = tokenizeSearchQuery('a%b_c');
    expect(tokens[0]).toContain('%');
    expect(escapeLikeLiteral(tokens[0])).toContain('\\%');
    expect(escapeLikeLiteral('x_y\\z')).toBe('x\\_y\\\\z');
  });

  it('G7B2-SEARCH-09 search_rank SQL uses raw token array bind', () => {
    expect(searchRankSql(7)).toMatch(/unnest\(\$7::text\[\]\)/);
  });

  it('G7B2-SEARCH-10 alef/yeh/teh-marbuta folding', () => {
    expect(normalizeSearchText('آفاق')).toBe(normalizeSearchText('افاق'));
    expect(normalizeSearchText('مستشفى')).toBe(normalizeSearchText('مستشفي'));
    expect(normalizeSearchText('مدرسة')).toBe(normalizeSearchText('مدرسه'));
    expect(AppError).toBeDefined();
  });
});
