/**
 * Geo bounds / radius (Gate 7B.0.4) — wired into buildDiscoveryQuery.
 * Spherical prefilter uses EARTH_RADIUS_KM=6371 (same R as Haversine).
 * BBox must never drop a point inside the radius (no false negatives).
 */

import { AppError } from '../../../shared/errors/app-error';
import { ErrorCodes } from '../../../shared/errors/error-codes';

/** Must match Haversine R in discovery-query / discovery-cursor-v2. */
export const EARTH_RADIUS_KM = 6371;

export const GEO_RADIUS_KM_MIN = 0.1;
export const GEO_RADIUS_KM_MAX = 200;
export const GEO_POLAR_LAT_ABS = 89.9;
export const GEO_POLAR_RADIUS_KM_MAX = 50;

export interface LatLngBox {
  minLat: number;
  maxLat: number;
  minLng: number;
  maxLng: number;
}

export interface NormalizedBounds {
  boxes: LatLngBox[];
  crossedAntimeridian: boolean;
  /** True when radius bbox spans a pole — longitude unrestricted. */
  spansPole: boolean;
}

function assertFinite(n: number, label: string): void {
  if (!Number.isFinite(n)) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, `invalid ${label}`);
  }
}

export function assertLatLng(lat: number, lng: number): void {
  assertFinite(lat, 'lat');
  assertFinite(lng, 'lng');
  if (lat < -90 || lat > 90) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'lat out of range');
  }
  if (lng < -180 || lng > 180) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'lng out of range');
  }
}

export function assertRadiusKm(radiusKm: number, originLat: number): void {
  assertFinite(radiusKm, 'radiusKm');
  if (radiusKm < GEO_RADIUS_KM_MIN || radiusKm > GEO_RADIUS_KM_MAX) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'radiusKm out of range');
  }
  if (Math.abs(originLat) > GEO_POLAR_LAT_ABS && radiusKm > GEO_POLAR_RADIUS_KM_MAX) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'radiusKm too large near poles');
  }
}

export function normalizeBounds(box: LatLngBox): NormalizedBounds {
  assertLatLng(box.minLat, box.minLng);
  assertLatLng(box.maxLat, box.maxLng);
  if (box.minLat > box.maxLat) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'minLat > maxLat');
  }
  if (box.minLng === box.maxLng) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'degenerate lng bounds');
  }
  if (box.minLng <= box.maxLng) {
    return { boxes: [box], crossedAntimeridian: false, spansPole: false };
  }
  return {
    crossedAntimeridian: true,
    spansPole: false,
    boxes: [
      { minLat: box.minLat, maxLat: box.maxLat, minLng: box.minLng, maxLng: 180 },
      { minLat: box.minLat, maxLat: box.maxLat, minLng: -180, maxLng: box.maxLng },
    ],
  };
}

function wrapLng(lng: number): number {
  return ((((lng + 180) % 360) + 360) % 360) - 180;
}

/**
 * BBox prefilter for radius using spherical angular distance (R=6371).
 * If circle reaches a pole, use full longitude so polar venues are not dropped.
 */
export function radiusToBbox(lat: number, lng: number, radiusKm: number): NormalizedBounds {
  assertLatLng(lat, lng);
  assertRadiusKm(radiusKm, lat);
  const angRad = radiusKm / EARTH_RADIUS_KM;
  const latDeltaDeg = (angRad * 180) / Math.PI;
  const minLat = Math.max(-90, lat - latDeltaDeg);
  const maxLat = Math.min(90, lat + latDeltaDeg);
  const spansPole = minLat <= -89.999 || maxLat >= 89.999;
  if (spansPole) {
    return {
      spansPole: true,
      crossedAntimeridian: false,
      boxes: [{ minLat, maxLat, minLng: -180, maxLng: 180 }],
    };
  }
  // Max longitude span occurs on the parallel with smallest |cos| in the lat band.
  const absLatEdge = Math.min(90, Math.abs(lat) + latDeltaDeg);
  const cosEdge = Math.cos((absLatEdge * Math.PI) / 180);
  if (cosEdge <= 1e-6) {
    return {
      spansPole: true,
      crossedAntimeridian: false,
      boxes: [{ minLat, maxLat, minLng: -180, maxLng: 180 }],
    };
  }
  const sinAng = Math.sin(angRad);
  const ratio = Math.min(1, sinAng / cosEdge);
  const lngDeltaDeg = (Math.asin(ratio) * 180) / Math.PI;
  let minLng = lng - lngDeltaDeg;
  let maxLng = lng + lngDeltaDeg;
  if (minLng < -180 || maxLng > 180) {
    minLng = wrapLng(minLng);
    maxLng = wrapLng(maxLng);
    if (minLng > maxLng) {
      return { ...normalizeBounds({ minLat, maxLat, minLng, maxLng }), spansPole: false };
    }
  }
  return { ...normalizeBounds({ minLat, maxLat, minLng, maxLng }), spansPole: false };
}

/** Haversine km — identical R to SQL distanceExpr. */
export function haversineKm(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * EARTH_RADIUS_KM * Math.asin(Math.min(1, Math.sqrt(a)));
}

export function boundsSql(
  boxes: LatLngBox[],
  startP: number,
): { sql: string; params: number[] } {
  const parts: string[] = [];
  const params: number[] = [];
  let p = startP;
  for (const b of boxes) {
    parts.push(
      `(v.lat BETWEEN $${p} AND $${p + 1} AND v.lng BETWEEN $${p + 2} AND $${p + 3})`,
    );
    params.push(b.minLat, b.maxLat, b.minLng, b.maxLng);
    p += 4;
  }
  return { sql: `(${parts.join(' OR ')})`, params };
}
