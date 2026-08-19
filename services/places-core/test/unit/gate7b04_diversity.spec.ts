import {
  DiversityCandidate,
  diversifyKeysetPage,
  emptyDiversityState,
  isStrictlyAfterForSort,
  orderCmpNullsLast,
  peekFromSortedStreams,
  serializeDiversityState,
  deserializeDiversityState,
} from '../../src/modules/filters/application/discovery-diversity';

describe('Gate 7B.0.4 — G7B04-DIV async peek + NULLS LAST + full traverse', () => {
  const uuid = (n: number) =>
    `bbbbbbbb-bbbb-4ccc-8ddd-${String(n).padStart(12, '0')}`;

  it('G7B04-DIV-01 NULLS LAST + deleted bookmark + last page no loss/dupe', async () => {
    expect(orderCmpNullsLast(null, '1', 'desc')).toBe(1);
    expect(orderCmpNullsLast('5', '3', 'desc')).toBeLessThan(0);

    const hotels: DiversityCandidate[] = [
      { id: uuid(1), venueType: 'hotel', sv: '5.00', sv2: '10', rankKey: 'a' },
      { id: uuid(2), venueType: 'hotel', sv: '5.00', sv2: '9', rankKey: 'b' }, // full tuple tie on sv
      { id: uuid(3), venueType: 'hotel', sv: '4.00', sv2: '8', rankKey: 'c' },
      { id: uuid(4), venueType: 'hotel', sv: null, sv2: '1', rankKey: 'd' }, // NULLS LAST
    ];
    const chalets: DiversityCandidate[] = [
      { id: uuid(5), venueType: 'chalet', sv: '4.50', sv2: '7', rankKey: 'e' },
      { id: uuid(6), venueType: 'chalet', sv: '3.00', sv2: '6', rankKey: 'f' },
    ];

    // Streams must be in ORDER BY order (rating DESC NULLS LAST)
    const streams = new Map([
      ['hotel', hotels],
      ['chalet', chalets],
    ]);
    const peek = peekFromSortedStreams(streams, 'rating');
    const types = ['hotel', 'chalet'];

    let state = emptyDiversityState();
    const page1 = await diversifyKeysetPage(types, peek, state, 2, 2, 'rating');
    expect(page1.items.map((i) => i.id)).toEqual([uuid(1), uuid(2)]);
    state = deserializeDiversityState(serializeDiversityState(page1.nextState));

    // Delete bookmark uuid(3)
    const hotels2 = hotels.filter((h) => h.id !== uuid(3));
    const peek2 = peekFromSortedStreams(
      new Map([
        ['hotel', hotels2],
        ['chalet', chalets],
      ]),
      'rating',
    );

    const all: string[] = [...page1.items.map((i) => i.id)];
    for (;;) {
      const page = await diversifyKeysetPage(types, peek2, state, 2, 2, 'rating');
      all.push(...page.items.map((i) => i.id));
      state = page.nextState;
      if (page.exhausted) break;
    }

    expect(all).not.toContain(uuid(3));
    expect(new Set(all).size).toBe(all.length);
    expect(all).toContain(uuid(4)); // null sv still reached last
    expect(all[all.length - 1]).toBe(uuid(4));
    expect(
      isStrictlyAfterForSort(
        'rating',
        { id: uuid(4), venueType: 'hotel', sv: null, sv2: '1', rankKey: 'd' },
        { sv: '4.00', sv2: '8', id: uuid(3) },
      ),
    ).toBe(true);
  });
});
