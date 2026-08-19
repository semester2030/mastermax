import {
  assertRadiusKm,
  normalizeBounds,
  radiusToBbox,
} from '../../src/modules/filters/application/discovery-geo';
import { AppError } from '../../src/shared/errors/app-error';

describe('Gate 7B.0.2 — G7B02-GEO-01 antimeridian / poles', () => {
  it('G7B02-GEO-01 splits antimeridian; rejects polar oversized radius; no silent clamp', () => {
    const crossed = normalizeBounds({
      minLat: -10,
      maxLat: 10,
      minLng: 170,
      maxLng: -170,
    });
    expect(crossed.crossedAntimeridian).toBe(true);
    expect(crossed.boxes).toHaveLength(2);
    expect(crossed.boxes[0]).toEqual({
      minLat: -10,
      maxLat: 10,
      minLng: 170,
      maxLng: 180,
    });
    expect(crossed.boxes[1]).toEqual({
      minLat: -10,
      maxLat: 10,
      minLng: -180,
      maxLng: -170,
    });

    expect(() => assertRadiusKm(51, 90)).toThrow(AppError);
    expect(() => assertRadiusKm(51, -90)).toThrow(AppError);
    expect(() => normalizeBounds({ minLat: 10, maxLat: 5, minLng: 1, maxLng: 2 })).toThrow(
      AppError,
    );

    const box = radiusToBbox(24.7, 46.7, 25);
    expect(box.crossedAntimeridian).toBe(false);
    expect(box.boxes).toHaveLength(1);
  });
});
