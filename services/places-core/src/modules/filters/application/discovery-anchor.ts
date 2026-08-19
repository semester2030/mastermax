/**
 * Anchor venue resolution for sort=near_place (Gate 7B.1).
 */
import { PoolClient } from 'pg';
import { PgService } from '../../../shared/database/pg.service';
import { AppError } from '../../../shared/errors/app-error';
import { ErrorCodes } from '../../../shared/errors/error-codes';

export interface ResolvedAnchor {
  id: string;
  venueType: string;
  lat: number;
  lng: number;
}

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export async function resolveNearPlaceAnchor(
  pg: PgService | PoolClient,
  anchorVenueId: string,
): Promise<ResolvedAnchor> {
  if (!UUID_RE.test(anchorVenueId)) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'invalid anchorVenueId');
  }
  const query = (sql: string, params: unknown[]) =>
    'query' in pg && typeof (pg as PgService).query === 'function'
      ? (pg as PgService).query(sql, params)
      : (pg as PoolClient).query(sql, params);

  const res = await query(
    `SELECT v.id, v.venue_type, v.lat, v.lng, v.status,
            c.enabled_for_discovery
     FROM venues v
     LEFT JOIN venue_type_capabilities c ON c.venue_type = v.venue_type
     WHERE v.id = $1`,
    [anchorVenueId],
  );
  if (!res.rowCount) {
    throw new AppError(ErrorCodes.NOT_FOUND, 'anchor venue not found');
  }
  const row = res.rows[0] as {
    id: string;
    venue_type: string;
    lat: number | null;
    lng: number | null;
    status: string;
    enabled_for_discovery: boolean | null;
  };
  if (row.status !== 'published') {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'anchor venue not published');
  }
  if (!row.enabled_for_discovery) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'anchor venue not enabled for discovery');
  }
  if (row.lat == null || row.lng == null) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'anchor venue missing coordinates');
  }
  const lat = Number(row.lat);
  const lng = Number(row.lng);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'anchor venue coordinates not finite');
  }
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, 'anchor venue coordinates out of range');
  }
  return {
    id: row.id,
    venueType: row.venue_type,
    lat,
    lng,
  };
}
