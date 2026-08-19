import {
  DiversityCandidate,
  diversifyKeysetPage,
  emptyDiversityState,
  peekFromSortedStreams,
} from '../../src/modules/filters/application/discovery-diversity';

describe('Gate 7B.0.1 — per-type keyset diversity (compat)', () => {
  it('G7B0-DIV-01 unbalanced multi-page still covers all ids', async () => {
    const candidates: DiversityCandidate[] = [
      { id: 'h1', venueType: 'hotel', sv: '0.90', rankKey: '0000' },
      { id: 'h2', venueType: 'hotel', sv: '0.89', rankKey: '0001' },
      { id: 'h3', venueType: 'hotel', sv: '0.88', rankKey: '0002' },
      { id: 'h4', venueType: 'hotel', sv: '0.87', rankKey: '0003' },
      { id: 'c1', venueType: 'chalet', sv: '0.86', rankKey: '0004' },
      { id: 'h5', venueType: 'hotel', sv: '0.85', rankKey: '0005' },
      { id: 'c2', venueType: 'chalet', sv: '0.84', rankKey: '0006' },
    ];
    const streams = new Map<string, DiversityCandidate[]>();
    for (const c of candidates) {
      const list = streams.get(c.venueType) ?? [];
      list.push(c);
      streams.set(c.venueType, list);
    }
    const peek = peekFromSortedStreams(streams, 'best');
    const types = [...streams.keys()];
    const out: DiversityCandidate[] = [];
    let state = emptyDiversityState();
    for (;;) {
      const page = await diversifyKeysetPage(types, peek, state, 2, 2, 'best');
      out.push(...page.items);
      state = page.nextState;
      if (page.exhausted) break;
    }
    expect(out).toHaveLength(7);
    expect(new Set(out.map((r) => r.id)).size).toBe(7);
    expect(out[2].venueType).toBe('chalet');
  });
});
