import {
  DiversityCandidate,
  deserializeDiversityState,
  diversifyKeysetPage,
  emptyDiversityState,
  isStrictlyAfterForSort,
  peekFromSortedStreams,
  serializeDiversityState,
} from '../../src/modules/filters/application/discovery-diversity';
import {
  buildQueryHash,
  canonicalizeResolvedDto,
  decodeCursorV2,
  encodeCursorV2,
  DIVERSITY_K_DEFAULT,
  DIVERSITY_VERSION_CURRENT,
  RANKING_EPOCH_CURRENT,
} from '../../src/modules/filters/application/discovery-cursor-v2';

describe('Gate 7B.0.5 — G7B05-DIV real bookmark delete + full pages', () => {
  const uuid = (n: number) =>
    `cccccccc-bbbb-4ccc-8ddd-${String(n).padStart(12, '0')}`;

  it('G7B05-DIV-01 delete last page bookmark; full-tuple ties by id; encode/decode to exhaustion', async () => {
    // Identical sort keys except id — tie-break MUST be id ASC (not rankKey).
    const hotels: DiversityCandidate[] = [
      { id: uuid(2), venueType: 'hotel', sv: '5.00', sv2: '10', rankKey: 'zzz' }, // higher rankKey but later id
      { id: uuid(1), venueType: 'hotel', sv: '5.00', sv2: '10', rankKey: 'aaa' },
      { id: uuid(3), venueType: 'hotel', sv: '4.00', sv2: '8', rankKey: 'm' },
      { id: uuid(4), venueType: 'hotel', sv: null, sv2: '1', rankKey: 'n' },
    ].sort((a, b) => {
      // Pre-sort stream as SQL would (rating DESC NULLS LAST, id ASC)
      if (a.sv == null && b.sv != null) return 1;
      if (a.sv != null && b.sv == null) return -1;
      if (a.sv !== b.sv) return a.sv! > b.sv! ? -1 : 1;
      if (a.sv2 !== b.sv2) return Number(a.sv2!) > Number(b.sv2!) ? -1 : 1;
      return a.id < b.id ? -1 : 1;
    });
    const chalets: DiversityCandidate[] = [
      { id: uuid(5), venueType: 'chalet', sv: '4.50', sv2: '7', rankKey: 'e' },
      { id: uuid(6), venueType: 'chalet', sv: '3.00', sv2: '6', rankKey: 'f' },
    ];

    expect(hotels[0].id).toBe(uuid(1)); // id ASC wins over rankKey among equal scores
    expect(hotels[1].id).toBe(uuid(2));

    const types = ['hotel', 'chalet'];
    let streams = new Map([
      ['hotel', hotels],
      ['chalet', chalets],
    ]);
    let peek = peekFromSortedStreams(streams, 'rating');
    let state = emptyDiversityState();

    const rankingAsOf = new Date().toISOString().replace(/\.\d{3}Z$/, '.000Z');
    const hash = buildQueryHash({
      resolvedCanonicalJson: canonicalizeResolvedDto({ sort: 'rating' }),
      surface: 'feed',
      q: null,
      originLat: null,
      originLng: null,
      anchorVenueId: null,
      rankingVersion: 1,
      rankingEpoch: RANKING_EPOCH_CURRENT,
      rankingAsOf,
      diversityVersion: DIVERSITY_VERSION_CURRENT,
      diversityK: DIVERSITY_K_DEFAULT,
    });

    const seen: string[] = [];
    for (;;) {
      const page = await diversifyKeysetPage(types, peek, state, 2, 2, 'rating');
      seen.push(...page.items.map((i) => i.id));

      // Encode/decode diversity cursor between pages (rating forbids null top-level sv).
      if (page.items.length > 0 && page.items[page.items.length - 1].sv != null) {
        const last = page.items[page.items.length - 1];
        const enc = encodeCursorV2(
          {
            v: 2,
            sort: 'rating',
            queryHash: hash,
            rankingEpoch: RANKING_EPOCH_CURRENT,
            rankingAsOf,
            diversityVersion: DIVERSITY_VERSION_CURRENT,
            diversityK: DIVERSITY_K_DEFAULT,
            diversity: page.nextState,
            sv: last.sv,
            sv2: last.sv2 ?? '0',
            id: last.id,
          },
          'required',
        );
        const decoded = decodeCursorV2(
          enc,
          'rating',
          hash,
          RANKING_EPOCH_CURRENT,
          rankingAsOf,
          'required', DIVERSITY_VERSION_CURRENT, DIVERSITY_K_DEFAULT,
        );
        state = deserializeDiversityState(serializeDiversityState(decoded.diversity!));
      } else {
        state = deserializeDiversityState(serializeDiversityState(page.nextState));
      }

      if (page.exhausted) break;

      // Delete the ACTUAL bookmark emitted as last item of this page (not a middle id).
      const bookmarkId = page.items[page.items.length - 1].id;
      const hotelAfter = (streams.get('hotel') ?? []).filter((h) => h.id !== bookmarkId);
      const chaletAfter = (streams.get('chalet') ?? []).filter((c) => c.id !== bookmarkId);
      streams = new Map([
        ['hotel', hotelAfter],
        ['chalet', chaletAfter],
      ]);
      peek = peekFromSortedStreams(streams, 'rating');
    }

    expect(new Set(seen).size).toBe(seen.length);
    expect(seen).toContain(uuid(1));
    expect(seen).toContain(uuid(2));
    expect(seen).toContain(uuid(4)); // NULLS LAST reached
    expect(seen.indexOf(uuid(1))).toBeLessThan(seen.indexOf(uuid(2))); // id ASC on tie
    expect(
      isStrictlyAfterForSort(
        'rating',
        { id: uuid(2), venueType: 'hotel', sv: '5.00', sv2: '10', rankKey: 'zzz' },
        { sv: '5.00', sv2: '10', id: uuid(1) },
      ),
    ).toBe(true);
  });
});
