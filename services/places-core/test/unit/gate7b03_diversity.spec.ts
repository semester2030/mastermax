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
  decodeCursorV2,
  encodeCursorV2,
  buildQueryHash,
  canonicalizeResolvedDto,
  DIVERSITY_K_DEFAULT,
  DIVERSITY_VERSION_CURRENT,
  RANKING_EPOCH_CURRENT,
} from '../../src/modules/filters/application/discovery-cursor-v2';

describe('Gate 7B.0.3 — G7B03-DIV-01 peek diversity resume', () => {
  const uuid = (n: number) =>
    `aaaaaaaa-bbbb-4ccc-8ddd-${String(n).padStart(12, '0')}`;

  it('G7B03-DIV-01 deleted bookmark + ties + encode/decode pages: no loss/dupe', async () => {
    const hotels: DiversityCandidate[] = [
      { id: uuid(1), venueType: 'hotel', sv: '0.900000', sv2: '5.00', sv3: '10', rankKey: '0000' },
      { id: uuid(2), venueType: 'hotel', sv: '0.900000', sv2: '5.00', sv3: '9', rankKey: '0001' },
      { id: uuid(3), venueType: 'hotel', sv: '0.880000', sv2: '4.00', sv3: '8', rankKey: '0002' },
      { id: uuid(4), venueType: 'hotel', sv: '0.870000', sv2: '4.00', sv3: '7', rankKey: '0003' },
    ];
    const chalets: DiversityCandidate[] = [
      { id: uuid(5), venueType: 'chalet', sv: '0.860000', sv2: '4.00', sv3: '6', rankKey: '0004' },
      { id: uuid(6), venueType: 'chalet', sv: '0.850000', sv2: '3.00', sv3: '5', rankKey: '0005' },
    ];
    const streams = new Map<string, DiversityCandidate[]>([
      ['hotel', hotels],
      ['chalet', chalets],
    ]);
    const peek = peekFromSortedStreams(streams, 'best');
    const types = ['hotel', 'chalet'];

    let state = emptyDiversityState();
    const p1 = await diversifyKeysetPage(types, peek, state, 2, 2, 'best');
    expect(p1.items.map((i) => i.id)).toEqual([uuid(1), uuid(2)]);
    state = deserializeDiversityState(serializeDiversityState(p1.nextState));

    const hotelsAfterDelete = hotels.filter((h) => h.id !== uuid(3));
    const streams2 = new Map<string, DiversityCandidate[]>([
      ['hotel', hotelsAfterDelete],
      ['chalet', chalets],
    ]);
    const peek2 = peekFromSortedStreams(streams2, 'best');
    const p2 = await diversifyKeysetPage(types, peek2, state, 2, 2, 'best');
    const seen = [...p1.items, ...p2.items].map((i) => i.id);
    expect(seen).not.toContain(uuid(3));
    expect(new Set(seen).size).toBe(seen.length);
    expect(p2.items[0].id).toBe(uuid(5));
    expect(p2.items[1].id).toBe(uuid(4));

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
      diversityK: DIVERSITY_K_DEFAULT,
    });
    const last = p2.items[p2.items.length - 1];
    const afterHotel = p2.nextState.perTypeAfter.hotel!;
    const enc = encodeCursorV2({
      v: 2,
      sort: 'best',
      queryHash: hash,
      rankingEpoch: RANKING_EPOCH_CURRENT,
      rankingAsOf,
      diversityVersion: DIVERSITY_VERSION_CURRENT,
      diversityK: DIVERSITY_K_DEFAULT,
      diversity: p2.nextState,
      sv: last.sv,
      sv2: last.sv2!,
      sv3: last.sv3!,
      id: last.id,
    }, 'required');
    const decoded = decodeCursorV2(
      enc,
      'best',
      hash,
      RANKING_EPOCH_CURRENT,
      rankingAsOf,
      'required', DIVERSITY_VERSION_CURRENT, DIVERSITY_K_DEFAULT,
    );
    expect(decoded.diversity?.perTypeAfter.hotel?.id).toBe(afterHotel.id);
    expect(
      isStrictlyAfterForSort(
        'best',
        { id: uuid(4), venueType: 'hotel', sv: '0.870000', sv2: '4.00', sv3: '7', rankKey: 'x' },
        decoded.diversity!.perTypeAfter.hotel!,
      ),
    ).toBe(false);
  });
});
