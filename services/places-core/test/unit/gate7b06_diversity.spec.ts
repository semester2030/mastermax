import {
  DiversityCandidate,
  deserializeDiversityState,
  diversifyKeysetPage,
  emptyDiversityState,
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
import { assertCursorV2PayloadShape } from '../../src/modules/filters/application/discovery-cursor-v2-validate';

describe('Gate 7B.0.6 — G7B06-DIV streak clamp + id ASC + cheapest NULLS LAST', () => {
  const uuid = (n: number) =>
    `dddddddd-bbbb-4ccc-8ddd-${String(n).padStart(12, '0')}`;

  it('G7B06-DIV-01 mono-type K=2 multipage encode/decode; all IDs once; streak<=K', async () => {
    const hotels: DiversityCandidate[] = Array.from({ length: 7 }, (_, i) => ({
      id: uuid(i + 1),
      venueType: 'hotel',
      sv: `${(0.9 - i * 0.01).toFixed(6)}`,
      sv2: '4.00',
      sv3: String(10 - i),
      rankKey: `r${i}`,
    }));
    const types = ['hotel'];
    const streams = new Map([['hotel', hotels]]);
    const peek = peekFromSortedStreams(streams, 'best');
    let state = emptyDiversityState();

    const rankingAsOf = new Date().toISOString().replace(/\.\d{3}Z$/, '.000Z');
    const hash = buildQueryHash({
      resolvedCanonicalJson: canonicalizeResolvedDto({ sort: 'best' }),
      surface: 'feed',
      q: null,
      originLat: null,
      originLng: null,
      anchorVenueId: null,
      rankingVersion: 1,
      rankingEpoch: RANKING_EPOCH_CURRENT,
      rankingAsOf,
      diversityVersion: DIVERSITY_VERSION_CURRENT,
      diversityK: 2,
    });

    const seen: string[] = [];
    let pages = 0;
    for (;;) {
      const page = await diversifyKeysetPage(types, peek, state, 2, 2, 'best');
      pages += 1;
      expect(page.items.length).toBeGreaterThan(0);
      for (const item of page.items) seen.push(item.id);

      expect(page.nextState.streak).toBeLessThanOrEqual(2);
      const last = page.items[page.items.length - 1];
      const enc = encodeCursorV2(
        {
          v: 2,
          sort: 'best',
          queryHash: hash,
          rankingEpoch: RANKING_EPOCH_CURRENT,
          rankingAsOf,
          diversityVersion: DIVERSITY_VERSION_CURRENT,
          diversityK: 2,
          diversity: page.nextState,
          sv: last.sv,
          sv2: last.sv2!,
          sv3: last.sv3!,
          id: last.id,
        },
        'required',
      );
      // Validator must accept the forced-streak cursor (never streak > K).
      assertCursorV2PayloadShape(
        JSON.parse(Buffer.from(enc, 'base64url').toString('utf8')),
        'required',
      );
      const decoded = decodeCursorV2(
        enc,
        'best',
        hash,
        RANKING_EPOCH_CURRENT,
        rankingAsOf,
        'required',
        DIVERSITY_VERSION_CURRENT,
        2,
      );
      state = deserializeDiversityState(serializeDiversityState(decoded.diversity!));
      if (page.exhausted) break;
    }

    expect(pages).toBeGreaterThanOrEqual(3);
    expect(seen).toEqual(hotels.map((h) => h.id));
    expect(new Set(seen).size).toBe(7);
  });

  it('G7B06-DIV-02 identical sort keys; inverted rankKey vs id → id ASC wins', async () => {
    const a: DiversityCandidate = {
      id: uuid(2),
      venueType: 'hotel',
      sv: '50.00',
      rankKey: 'aaa', // would win if rankKey mattered
    };
    const b: DiversityCandidate = {
      id: uuid(1),
      venueType: 'chalet',
      sv: '50.00',
      rankKey: 'zzz',
    };
    // Streams already in id ASC within type; cross-type pool must pick lower id.
    const streams = new Map<string, DiversityCandidate[]>([
      ['hotel', [a]],
      ['chalet', [b]],
    ]);
    const page = await diversifyKeysetPage(
      ['hotel', 'chalet'],
      peekFromSortedStreams(streams, 'cheapest'),
      emptyDiversityState(),
      2,
      2,
      'cheapest',
    );
    expect(page.items.map((i) => i.id)).toEqual([uuid(1), uuid(2)]);
    expect(page.items[0].rankKey).toBe('zzz');
  });

  it('G7B06-DIV-03 cheapest NULLS LAST crosses page boundary with cursor round-trip', async () => {
    const hotels: DiversityCandidate[] = [
      { id: uuid(1), venueType: 'hotel', sv: '10.00', rankKey: 'a' },
      { id: uuid(2), venueType: 'hotel', sv: '20.00', rankKey: 'b' },
      { id: uuid(3), venueType: 'hotel', sv: null, rankKey: 'c' }, // NULLS LAST
    ];
    const chalets: DiversityCandidate[] = [
      { id: uuid(4), venueType: 'chalet', sv: '15.00', rankKey: 'd' },
    ];
    const types = ['hotel', 'chalet'];
    let streams = new Map([
      ['hotel', hotels],
      ['chalet', chalets],
    ]);
    let peek = peekFromSortedStreams(streams, 'cheapest');
    let state = emptyDiversityState();

    const rankingAsOf = new Date().toISOString().replace(/\.\d{3}Z$/, '.000Z');
    const hash = buildQueryHash({
      resolvedCanonicalJson: canonicalizeResolvedDto({ sort: 'cheapest' }),
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

    const page1 = await diversifyKeysetPage(types, peek, state, 2, 2, 'cheapest');
    expect(page1.items.map((i) => i.id)).toEqual([uuid(1), uuid(4)]);
    const last1 = page1.items[page1.items.length - 1];
    const enc1 = encodeCursorV2(
      {
        v: 2,
        sort: 'cheapest',
        queryHash: hash,
        rankingEpoch: RANKING_EPOCH_CURRENT,
        rankingAsOf,
        diversityVersion: DIVERSITY_VERSION_CURRENT,
        diversityK: DIVERSITY_K_DEFAULT,
        diversity: page1.nextState,
        sv: last1.sv,
        id: last1.id,
      },
      'required',
    );
    state = deserializeDiversityState(
      serializeDiversityState(
        decodeCursorV2(
          enc1,
          'cheapest',
          hash,
          RANKING_EPOCH_CURRENT,
          rankingAsOf,
          'required',
        ).diversity!,
      ),
    );

    // Continue from remaining streams (simulate next fetch after cursor).
    const emitted = new Set(page1.items.map((i) => i.id));
    streams = new Map([
      ['hotel', hotels.filter((h) => !emitted.has(h.id))],
      ['chalet', chalets.filter((c) => !emitted.has(c.id))],
    ]);
    peek = peekFromSortedStreams(streams, 'cheapest');

    const page2 = await diversifyKeysetPage(types, peek, state, 2, 2, 'cheapest');
    expect(page2.items.map((i) => i.id)).toEqual([uuid(2), uuid(3)]);
    const nullItem = page2.items.find((i) => i.sv == null)!;
    expect(nullItem.id).toBe(uuid(3));

    const enc2 = encodeCursorV2(
      {
        v: 2,
        sort: 'cheapest',
        queryHash: hash,
        rankingEpoch: RANKING_EPOCH_CURRENT,
        rankingAsOf,
        diversityVersion: DIVERSITY_VERSION_CURRENT,
        diversityK: DIVERSITY_K_DEFAULT,
        diversity: page2.nextState,
        sv: nullItem.sv,
        id: nullItem.id,
      },
      'required',
    );
    const decoded2 = decodeCursorV2(
      enc2,
      'cheapest',
      hash,
      RANKING_EPOCH_CURRENT,
      rankingAsOf,
      'required',
    );
    expect(decoded2.sv).toBeNull();
    expect(decoded2.diversity?.perTypeAfter.hotel?.sv).toBeNull();
    expect(decoded2.diversity?.perTypeAfter.hotel?.id).toBe(uuid(3));
  });
});
