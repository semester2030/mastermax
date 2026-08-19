import {
  applyDiscoveryDefaults,
  assertDiscoveryLimits,
  buildDiscoveryQuery,
  distanceMetersExpr,
  NEAR_PLACE_DEFAULT_RADIUS_KM,
} from '../../src/modules/filters/application/discovery-query';
import { normalizeBounds, radiusToBbox } from '../../src/modules/filters/application/discovery-geo';
import { DiscoverySearchDto } from '../../src/shared/api/dto/discovery-search.dto';

const AS_OF = '2026-08-14T12:00:00.000Z';
const anchor = {
  id: 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
  venueType: 'hotel',
  lat: 24.7136,
  lng: 46.6753,
};

describe('Gate 7B.1 / 7B.3.1 — G7B1-GEO near_place', () => {
  it('G7B1-GEO-01 near_place requires anchorVenueId', () => {
    expect(() =>
      assertDiscoveryLimits({ sort: 'near_place' } as DiscoverySearchDto),
    ).toThrow(/anchorVenueId/);
  });

  it('G7B1-GEO-02 excludes anchor and supports sameTypeOnly', () => {
    const q = buildDiscoveryQuery(
      {
        sort: 'near_place',
        anchorVenueId: anchor.id,
        sameTypeOnly: true,
        radiusKm: 50,
        surface: 'map',
      } as DiscoverySearchDto,
      { rankingAsOf: AS_OF, anchor, excludeAnchor: true },
    );
    expect(q.whereSql).toContain('v.id <>');
    expect(q.whereSql).toContain('v.venue_type =');
    expect(q.whereParams).toEqual(expect.arrayContaining([anchor.id, 'hotel']));
    expect(q.selectExtras).toContain('distance_meters');
  });

  it('G7B1-GEO-03 near_place forbids bounds; radius without client lat uses anchor', () => {
    expect(() =>
      assertDiscoveryLimits({
        sort: 'near_place',
        anchorVenueId: anchor.id,
        radiusKm: 10,
        minLat: 1,
        maxLat: 2,
        minLng: 3,
        maxLng: 4,
      } as DiscoverySearchDto),
    ).toThrow(/forbids bounds/);

    expect(() =>
      assertDiscoveryLimits({
        sort: 'near_place',
        anchorVenueId: anchor.id,
        lat: 24,
        lng: 46,
      } as DiscoverySearchDto),
    ).toThrow(/forbids client lat\/lng/);

    const q = buildDiscoveryQuery(
      {
        sort: 'near_place',
        anchorVenueId: anchor.id,
        radiusKm: 25,
        surface: 'map',
      } as DiscoverySearchDto,
      { rankingAsOf: AS_OF, anchor },
    );
    expect(q.whereParams).toEqual(expect.arrayContaining([anchor.lat, anchor.lng, 25]));
  });

  it('G7B1-GEO-04 antimeridian bounds (non-near_place map) produce OR boxes', () => {
    const anti = normalizeBounds({ minLat: -5, maxLat: 5, minLng: 170, maxLng: -170 });
    expect(anti.crossedAntimeridian).toBe(true);
    const q = buildDiscoveryQuery(
      {
        sort: 'newest',
        minLat: -5,
        maxLat: 5,
        minLng: 170,
        maxLng: -170,
        surface: 'map',
      } as DiscoverySearchDto,
      { rankingAsOf: AS_OF },
    );
    expect(q.whereSql).toMatch(/OR/);
    expect(q.whereParams).toEqual(expect.arrayContaining([170, 180, -180, -170]));
  });

  it('G7B1-GEO-05 high-latitude radius spans full longitude', () => {
    const box = radiusToBbox(89.5, 10, 80);
    expect(box.spansPole).toBe(true);
    expect(box.boxes[0].minLng).toBe(-180);
    expect(box.boxes[0].maxLng).toBe(180);
    // Contract polar cap: radiusKm<=50 near poles — query still builds with Anchor-only origin
    const q = buildDiscoveryQuery(
      {
        sort: 'near_place',
        anchorVenueId: anchor.id,
        radiusKm: 50,
        surface: 'map',
      } as DiscoverySearchDto,
      {
        rankingAsOf: AS_OF,
        anchor: { ...anchor, lat: 89.5, lng: 10 },
      },
    );
    expect(q.whereParams).toEqual(expect.arrayContaining([89.5, 10, 50]));
    expect(q.whereSql).toContain('BETWEEN');
  });

  it('G7B1-GEO-06 identical distance_meters in SELECT/ORDER BY', () => {
    const q = buildDiscoveryQuery(
      {
        sort: 'near_place',
        anchorVenueId: anchor.id,
        radiusKm: NEAR_PLACE_DEFAULT_RADIUS_KM,
        surface: 'map',
      } as DiscoverySearchDto,
      { rankingAsOf: AS_OF, anchor },
    );
    const expr = distanceMetersExpr(q.originLatParam!, q.originLngParam!);
    expect(q.selectExtras).toContain(expr);
    expect(q.orderBySql).toContain(expr);
  });

  it('G7B1-GEO-07 near_me forbids anchor; requires lat/lng', () => {
    expect(() =>
      assertDiscoveryLimits({
        sort: 'near_me',
        lat: 24,
        lng: 46,
        anchorVenueId: anchor.id,
      } as DiscoverySearchDto),
    ).toThrow(/forbids anchorVenueId/);
    expect(() =>
      assertDiscoveryLimits({ sort: 'near_me' } as DiscoverySearchDto),
    ).toThrow(/near_me requires lat\/lng/);
  });

  it('G7B1-GEO-08 defaults radiusKm=50 sameTypeOnly=true', () => {
    const d = applyDiscoveryDefaults({
      sort: 'near_place',
      anchorVenueId: anchor.id,
    } as DiscoverySearchDto);
    expect(d.radiusKm).toBe(50);
    expect(d.sameTypeOnly).toBe(true);
    expect(d.lat).toBeUndefined();
  });
});
