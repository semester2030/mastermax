import {
  DiversityCandidate,
  deserializeDiversityState,
  diversifyKeysetPage,
  emptyDiversityState,
  peekFromSortedStreams,
  serializeDiversityState,
} from '../../src/modules/filters/application/discovery-diversity';

describe('Gate 7B.0.2 — G7B02-DIV-01 full keyset serialize round-trip', () => {
  it('G7B02-DIV-01 serialize→decode pages: no drop/dupe with full per-type tuples', async () => {
    const seq: DiversityCandidate[] = [
      { id: 'h1', venueType: 'hotel', sv: '0.90', sv2: '5', sv3: '10', rankKey: '0000' },
      { id: 'h2', venueType: 'hotel', sv: '0.89', sv2: '5', sv3: '9', rankKey: '0001' },
      { id: 'h3', venueType: 'hotel', sv: '0.88', sv2: '4', sv3: '8', rankKey: '0002' },
      { id: 'h4', venueType: 'hotel', sv: '0.87', sv2: '4', sv3: '7', rankKey: '0003' },
      { id: 'c1', venueType: 'chalet', sv: '0.86', sv2: '4', sv3: '6', rankKey: '0004' },
      { id: 'h5', venueType: 'hotel', sv: '0.85', sv2: '3', sv3: '5', rankKey: '0005' },
      { id: 'c2', venueType: 'chalet', sv: '0.84', sv2: '3', sv3: '4', rankKey: '0006' },
    ];
    const byType = new Map<string, DiversityCandidate[]>();
    for (const c of seq) {
      const list = byType.get(c.venueType) ?? [];
      list.push(c);
      byType.set(c.venueType, list);
    }
    const peek = peekFromSortedStreams(byType, 'best');
    const types = [...byType.keys()];

    const seen: string[] = [];
    let state = emptyDiversityState();
    for (;;) {
      const page = await diversifyKeysetPage(types, peek, state, 2, 2, 'best');
      seen.push(...page.items.map((i) => i.id));
      for (const item of page.items) {
        const after = page.nextState.perTypeAfter[item.venueType];
        expect(after.sv).toBeDefined();
        expect(after.id).toBeTruthy();
      }
      state = deserializeDiversityState(serializeDiversityState(page.nextState));
      if (page.exhausted) break;
    }
    expect(seen).toHaveLength(7);
    expect(new Set(seen).size).toBe(7);
    expect(seen[0]).toBe('h1');
    expect(seen[1]).toBe('h2');
    expect(seen[2]).toBe('c1');
  });
});
