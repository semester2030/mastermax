import {
  assertDiscoveryLimits,
  buildDiscoveryQuery,
} from '../../src/modules/filters/application/discovery-query';
import { radiusToBbox } from '../../src/modules/filters/application/discovery-geo';
import { DiscoverySearchDto } from '../../src/shared/api/dto/discovery-search.dto';
import { AppError } from '../../src/shared/errors/app-error';
import { ErrorCodes } from '../../src/shared/errors/error-codes';

describe('Gate 7B.0.3 — G7B03-GEO-01 runtime geo wiring', () => {
  it('G7B03-GEO-01 radius+bounds exclusive; polar full-lng; antimeridian OR boxes in SQL', () => {
    expect(() =>
      assertDiscoveryLimits({
        lat: 24,
        lng: 46,
        radiusKm: 10,
        minLat: 1,
        maxLat: 2,
        minLng: 3,
        maxLng: 4,
      } as DiscoverySearchDto),
    ).toThrow(/mutually exclusive/);

    expect(() =>
      assertDiscoveryLimits({ minLat: 1, maxLat: 2, minLng: 3 } as DiscoverySearchDto),
    ).toThrow(/partial bounds/);

    try {
      assertDiscoveryLimits({
        lat: 24,
        lng: 46,
        radiusKm: 10,
        minLat: 1,
        maxLat: 2,
        minLng: 3,
        maxLng: 4,
      } as DiscoverySearchDto);
      fail('expected');
    } catch (e) {
      expect((e as AppError).code).toBe(ErrorCodes.VALIDATION_ERROR);
    }

    // Pole-reaching radius → full longitude prefilter (no false negatives near pole)
    const polar = radiusToBbox(89.5, 10, 80);
    expect(polar.spansPole).toBe(true);
    expect(polar.boxes[0].minLng).toBe(-180);
    expect(polar.boxes[0].maxLng).toBe(180);

    const polarQ = buildDiscoveryQuery(
      {
        lat: 89.5,
        lng: 10,
        radiusKm: 80,
        surface: 'map',
      } as DiscoverySearchDto,
      { rankingAsOf: '2026-08-14T00:00:00.000Z' },
    );
    expect(polarQ.whereSql).toContain('BETWEEN');
    expect(polarQ.whereParams).toContain(-180);
    expect(polarQ.whereParams).toContain(180);

    // Antimeridian bounds → OR of two boxes in runtime SQL
    const anti = buildDiscoveryQuery(
      {
        minLat: -5,
        maxLat: 5,
        minLng: 170,
        maxLng: -170,
        surface: 'map',
      } as DiscoverySearchDto,
      { rankingAsOf: '2026-08-14T00:00:00.000Z' },
    );
    expect(anti.whereSql).toMatch(/OR/);
    expect(anti.whereParams).toEqual(expect.arrayContaining([170, 180, -180, -170]));
  });
});
