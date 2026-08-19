/**
 * Shared discovery page SELECT / LATERAL media / amenities projection (Gate 7B.4.1 / 7B.5.1).
 * Used by both the global keyset path and Mixed Feed Diversity peeks — one template.
 *
 * Gate 7B.5.1: two-phase plan — ORDER BY/LIMIT on venues only (index-friendly),
 * then project media/amenities for the page rows (avoids LATERAL×candidate blow-up).
 * Outer ORDER BY uses projected aliases so it never re-evaluates heavy exprs on joins.
 */
import {
  PRIMARY_MEDIA_LATERAL_WHERE,
  PRIMARY_MEDIA_ORDER,
} from './discovery-surface';
import { BuiltDiscoveryQuery } from './discovery-query';
import { CursorV2Sort } from './discovery-cursor-v2';

const VENUE_PAGE_COLUMNS = `
             v.id, v.name, v.venue_type, v.booking_mode, v.city, v.district, v.lat, v.lng,
             v.verified, v.stars, v.bedrooms, v.bathrooms, v.beds, v.capacity,
             v.size_sqm, v.rating_average, v.reviews_count, v.weighted_rating,
             v.has_active_offer, v.filter_data_completeness, v.attributes_jsonb,
             v.created_at,
             COALESCE((
               SELECT c.enabled_for_booking FROM venue_type_capabilities c
               WHERE c.venue_type = v.venue_type
             ), FALSE) AS enabled_for_booking`;

/** Ranked venue rows only (no media/amenities). */
export function discoveryPageSelectSql(built: BuiltDiscoveryQuery): string {
  return `
      SELECT ${VENUE_PAGE_COLUMNS},
             ${built.selectExtras}
      FROM venues v
`;
}

/** Stable page order using CTE aliases (matches buildDiscoveryQuery ORDER BY keys). */
export function discoveryPageOuterOrderSql(sort: CursorV2Sort): string {
  switch (sort) {
    case 'cheapest':
      return 'r.starting_price_hint ASC NULLS LAST, r.id ASC';
    case 'most_expensive':
      return 'r.starting_price_hint DESC NULLS LAST, r.id ASC';
    case 'rating':
      return 'r.weighted_rating DESC NULLS LAST, r.reviews_count DESC, r.id ASC';
    case 'newest':
      return "date_trunc('milliseconds', r.created_at) DESC NULLS LAST, r.id ASC";
    case 'near_me':
    case 'near_place':
      return 'r.distance_meters ASC NULLS LAST, r.id ASC';
    case 'search_rank':
      return 'r.text_rank DESC NULLS LAST, r.best_score DESC NULLS LAST, r.id ASC';
    case 'best':
    default:
      return 'r.best_score DESC NULLS LAST, r.weighted_rating DESC NULLS LAST, r.reviews_count DESC, r.id ASC';
  }
}

export function discoveryPageSql(
  built: BuiltDiscoveryQuery,
  pageWhere: string,
  limitParamIndex: number,
): string {
  // ORDER BY + LIMIT (not ROW_NUMBER over full set) so btree indexes apply.
  return `
        WITH ranked AS (
          SELECT ${VENUE_PAGE_COLUMNS},
                 ${built.selectExtras}
          FROM venues v
          WHERE ${pageWhere}
          ORDER BY ${built.orderBySql}
          LIMIT $${limitParamIndex}
        )
        SELECT r.id, r.name, r.venue_type, r.booking_mode, r.city, r.district, r.lat, r.lng,
               r.verified, r.stars, r.bedrooms, r.bathrooms, r.beds, r.capacity,
               r.size_sqm, r.rating_average, r.reviews_count, r.weighted_rating,
               r.has_active_offer, r.filter_data_completeness, r.attributes_jsonb,
               r.created_at, r.enabled_for_booking,
               r.starting_price_hint, r.distance_meters, r.best_score, r.text_rank,
               pm.id AS media_id, pm.kind AS media_kind, pm.url AS stream_url,
               pm.stream_uid AS stream_uid, pm.cover_url, pm.category AS media_category,
               COALESCE((
                 SELECT array_agg(DISTINCT l.amenity_code ORDER BY l.amenity_code)
                 FROM venue_amenity_links l
                 WHERE l.venue_id = r.id AND l.state = 'AVAILABLE'
               ), ARRAY[]::text[]) AS amenities
        FROM ranked r
        LEFT JOIN LATERAL (
          SELECT m.id, m.kind, m.url, m.stream_uid, m.cover_url, m.category
          FROM venue_media m
          WHERE m.venue_id = r.id
            AND ${PRIMARY_MEDIA_LATERAL_WHERE}
          ORDER BY ${PRIMARY_MEDIA_ORDER}
          LIMIT 1
        ) pm ON TRUE
        ORDER BY ${discoveryPageOuterOrderSql(built.sort)}
      `;
}
