import {
  EARTH_RADIUS_KM,
  haversineKm,
  normalizeBounds,
  radiusToBbox,
} from '../../src/modules/filters/application/discovery-geo';
import {
  assertDiscoveryLimits,
  buildDiscoveryQuery,
} from '../../src/modules/filters/application/discovery-query';
import { DiscoverySearchDto } from '../../src/shared/api/dto/discovery-search.dto';
import { AppError } from '../../src/shared/errors/app-error';

describe('Gate 7B.0.4 — G7B04-GEO spherical R=6371', () => {
  it('G7B04-GEO-01 bbox never drops (0,0)+200km venue at 1.797°; poles/antimeridian', () => {
    expect(EARTH_RADIUS_KM).toBe(6371);
    const d = haversineKm(0, 0, 1.797, 0);
    expect(d).toBeLessThanOrEqual(200);
    expect(d).toBeGreaterThan(199);

    const box = radiusToBbox(0, 0, 200);
    expect(box.boxes[0].maxLat).toBeGreaterThanOrEqual(1.797);
    expect(box.boxes[0].minLat).toBeLessThanOrEqual(-1.797);

    const q = buildDiscoveryQuery(
      {
        lat: 0,
        lng: 0,
        radiusKm: 200,
        surface: 'map',
      } as DiscoverySearchDto,
      { rankingAsOf: '2026-08-14T00:00:00.000Z' },
    );
    const maxLatIdx = q.whereParams.findIndex((p, i) => i >= 0 && p === box.boxes[0].maxLat);
    expect(maxLatIdx).toBeGreaterThanOrEqual(0);
    expect(q.whereParams).toEqual(
      expect.arrayContaining([box.boxes[0].minLat, box.boxes[0].maxLat, 0, 0, 200]),
    );

    // Antimeridian
    const anti = normalizeBounds({ minLat: -5, maxLat: 5, minLng: 170, maxLng: -170 });
    expect(anti.crossedAntimeridian).toBe(true);
    expect(anti.boxes).toHaveLength(2);

    // Pole-reaching
    const polar = radiusToBbox(89.5, 10, 80);
    expect(polar.spansPole).toBe(true);
    expect(polar.boxes[0].minLng).toBe(-180);

    expect(() =>
      assertDiscoveryLimits({
        lat: 0,
        lng: 0,
        radiusKm: 10,
        minLat: 1,
        maxLat: 2,
        minLng: 3,
        maxLng: 4,
      } as DiscoverySearchDto),
    ).toThrow(AppError);
  });
});
