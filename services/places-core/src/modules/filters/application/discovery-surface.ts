/**
 * Discovery surface contracts (Gate 7A.2 / 7B.0.2).
 * Feed is Video-first: requires an approved **playable** video BEFORE count/cursor/limit.
 */
import { isAllowedCloudflareDeliveryUrl } from '../../media/domain/cloudflare-hostname-allowlist';

export type DiscoverySurface = 'feed' | 'map' | 'circle' | 'search';

export const FEED_REQUIRES_APPROVED_VIDEO = true;

/**
 * Playable approved video row predicate (parameter-free).
 * Soft-deleted rows never qualify (F-REV4-12).
 * Playable for feed denorm = non-empty stream_uid OR any HTTPS url.
 * Cloudflare delivery hostname allowlist (F-REV4-16) applies to resolveStreamUrl /
 * catalog variants — not to whether a venue has a playable video for feed eligibility.
 */
export const PLAYABLE_VIDEO_ROW = `(
  m.kind = 'video'
  AND m.moderation_status = 'approved'
  AND m.deleted_at IS NULL
  AND (
    (m.stream_uid IS NOT NULL AND btrim(m.stream_uid) <> '')
    OR (m.url IS NOT NULL AND btrim(m.url) <> '' AND m.url ~* '^https://')
  )
)`;

/**
 * Primary media LATERAL filter — videos must satisfy PLAYABLE_VIDEO_ROW;
 * non-video approved non-deleted media allowed as fallback for map/circle/search.
 * Unplayable videos (http, empty, soft-deleted) NEVER enter the candidate set for LIMIT 1.
 */
export const PRIMARY_MEDIA_LATERAL_WHERE = `(
  m.deleted_at IS NULL
  AND m.moderation_status = 'approved'
  AND (
    ${PLAYABLE_VIDEO_ROW}
    OR (m.kind <> 'video')
  )
)`;

export const PRIMARY_MEDIA_ORDER = `
  CASE WHEN ${PLAYABLE_VIDEO_ROW} THEN 0 ELSE 1 END,
  m.sort_order,
  m.id
`;

export const APPROVED_VIDEO_EXISTS = `v.has_playable_video IS TRUE`;

export const PLAYABLE_APPROVED_VIDEO_EXISTS = APPROVED_VIDEO_EXISTS;

export function normalizeSurface(raw?: string): DiscoverySurface {
  if (raw === 'feed' || raw === 'map' || raw === 'circle' || raw === 'search') {
    return raw;
  }
  return 'search';
}

export function requiresApprovedVideo(surface: DiscoverySurface): boolean {
  return surface === 'feed';
}

/**
 * streamUrl = Cloudflare-allowlisted HTTPS playback URL only (F-REV4-16).
 * Cloudflare Stream UID belongs in streamUid — never synthesize cfstream: into streamUrl.
 */
export function resolveStreamUrl(url: unknown): string | null {
  if (typeof url !== 'string') return null;
  const u = url.trim();
  if (!u) return null;
  if (!isAllowedCloudflareDeliveryUrl(u)) return null;
  return u;
}

/** @deprecated use resolveStreamUrl */
export function resolvePlaybackUrl(url: unknown, _streamUid?: unknown): string | null {
  return resolveStreamUrl(url);
}
