/**
 * Exact Cloudflare delivery hostname allowlist (REV4 F-REV4-16).
 * Never use substring includes('imagedelivery.net') — spoof hosts match that.
 */

const EXACT_IMAGE_HOSTS = new Set([
  'imagedelivery.net',
  'upload.imagedelivery.net',
]);

const STREAM_CUSTOMER_HOST =
  /^customer-[a-z0-9-]+\.cloudflarestream\.com$/i;

/** SQL fragment (alias `m`) — keep in sync with places_cf_https_url_allowed(). */
export const CF_HTTPS_URL_ALLOWED_SQL = `(
  m.url ~* '^https://imagedelivery\\.net/'
  OR m.url ~* '^https://upload\\.imagedelivery\\.net/'
  OR m.url ~* '^https://customer-[a-z0-9-]+\\.cloudflarestream\\.com/'
)`;

export function isAllowedCloudflareMediaHostname(hostname: string): boolean {
  const h = hostname.trim().toLowerCase();
  if (!h) return false;
  if (EXACT_IMAGE_HOSTS.has(h)) return true;
  return STREAM_CUSTOMER_HOST.test(h);
}

export function isAllowedCloudflareDeliveryUrl(url: string): boolean {
  try {
    const u = new URL(url.trim());
    if (u.protocol !== 'https:') return false;
    return isAllowedCloudflareMediaHostname(u.hostname);
  } catch {
    return false;
  }
}
