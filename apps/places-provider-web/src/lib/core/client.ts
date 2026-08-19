import { randomUUID } from "node:crypto";
import { getSessionToken } from "@/lib/auth/session";
import { providerIdFromToken } from "@/lib/auth/jwt";
import { buildCoreHeaders } from "@/lib/core/headers";

export { buildCoreHeaders } from "@/lib/core/headers";

export class CoreApiError extends Error {
  readonly status: number;
  readonly body: unknown;
  readonly correlationId: string;

  constructor(
    message: string,
    opts: { status: number; body: unknown; correlationId: string },
  ) {
    super(message);
    this.name = "CoreApiError";
    this.status = opts.status;
    this.body = opts.body;
    this.correlationId = opts.correlationId;
  }
}

export type CoreRequestOptions = {
  method?: "GET" | "POST" | "PATCH" | "PUT" | "DELETE";
  path: string;
  query?: Record<string, string | undefined | null>;
  body?: unknown;
  /** When true, send Idempotency-Key (uuid). Default: mutating methods. */
  idempotent?: boolean;
  /** Override bearer token (tests / session bootstrap). */
  accessToken?: string | null;
  /** Skip Authorization header (public OTP). */
  public?: boolean;
};

function placesApiBaseUrl(): string {
  const base = process.env.PLACES_API_BASE_URL?.trim();
  if (!base) {
    throw new Error("PLACES_API_BASE_URL is not configured");
  }
  return base.replace(/\/$/, "");
}

function buildUrl(
  path: string,
  query?: Record<string, string | undefined | null>,
): string {
  const url = new URL(
    path.startsWith("/") ? path : `/${path}`,
    `${placesApiBaseUrl()}/`,
  );
  if (query) {
    for (const [key, value] of Object.entries(query)) {
      if (value != null && value !== "") {
        url.searchParams.set(key, value);
      }
    }
  }
  return url.toString();
}

export async function coreFetch<T = unknown>(
  options: CoreRequestOptions,
): Promise<T> {
  const method = options.method ?? "GET";
  const mutating = method !== "GET";
  const idempotent = options.idempotent ?? mutating;
  const accessToken =
    options.public
      ? null
      : (options.accessToken ?? (await getSessionToken()));

  if (!options.public && !accessToken) {
    throw new CoreApiError("Unauthenticated", {
      status: 401,
      body: { error: "missing_session" },
      correlationId: randomUUID(),
    });
  }

  const headers = buildCoreHeaders({
    accessToken,
    idempotent: options.public ? false : idempotent,
    hasJsonBody: options.body !== undefined,
  });

  const res = await fetch(buildUrl(options.path, options.query), {
    method,
    headers: headers as Record<string, string>,
    body:
      options.body === undefined ? undefined : JSON.stringify(options.body),
    cache: "no-store",
  });

  const text = await res.text();
  let parsed: unknown = null;
  if (text) {
    try {
      parsed = JSON.parse(text) as unknown;
    } catch {
      parsed = { raw: text };
    }
  }

  if (!res.ok) {
    const message =
      typeof parsed === "object" &&
      parsed &&
      "message" in parsed &&
      typeof (parsed as { message: unknown }).message === "string"
        ? (parsed as { message: string }).message
        : `Core request failed (${res.status})`;
    throw new CoreApiError(message, {
      status: res.status,
      body: parsed,
      correlationId: headers["X-Correlation-Id"],
    });
  }

  return parsed as T;
}

export async function requireProviderId(
  accessToken?: string | null,
): Promise<string> {
  const token = accessToken ?? (await getSessionToken());
  if (!token) {
    throw new CoreApiError("Unauthenticated", {
      status: 401,
      body: { error: "missing_session" },
      correlationId: randomUUID(),
    });
  }
  const providerId = providerIdFromToken(token);
  if (!providerId) {
    throw new CoreApiError("Missing onBehalfOfProviderId claim", {
      status: 401,
      body: { error: "missing_provider_claim" },
      correlationId: randomUUID(),
    });
  }
  return providerId;
}

/* ---- Auth (public) ---- */

export function sendOtp(phoneE164: string) {
  return coreFetch<{ challengeId: string; expiresInSec?: number }>({
    method: "POST",
    path: "/v1/auth/internal/otp/send",
    body: { phoneE164 },
    public: true,
    idempotent: false,
  });
}

export function verifyOtp(input: { challengeId: string; code: string }) {
  return coreFetch<{
    accessToken: string;
    expiresInSec: number;
    onBehalfOfProviderId: string;
  }>({
    method: "POST",
    path: "/v1/auth/internal/otp/verify",
    body: input,
    public: true,
    idempotent: false,
  });
}

export function logoutCore(accessToken: string) {
  return coreFetch<{ ok: true }>({
    method: "POST",
    path: "/v1/auth/session/logout",
    accessToken,
    body: {},
  });
}

/* ---- Venues ---- */

export function listVenues(providerId: string) {
  return coreFetch<unknown>({
    method: "GET",
    path: "/v1/provider/venues",
    query: { providerId },
    idempotent: false,
  });
}

export function getVenue(venueId: string, providerId: string) {
  return coreFetch<unknown>({
    method: "GET",
    path: `/v1/provider/venues/${venueId}`,
    query: { providerId },
    idempotent: false,
  });
}

export function createVenue(body: {
  providerId: string;
  name: string;
  venueType: string;
  bookingMode: "nightly" | "daily";
  city?: string;
}) {
  return coreFetch<{ venueId: string }>({
    method: "POST",
    path: "/v1/provider/venues",
    body,
  });
}

export function patchVenue(
  venueId: string,
  body: Record<string, unknown>,
) {
  return coreFetch<unknown>({
    method: "PATCH",
    path: `/v1/provider/venues/${venueId}`,
    body,
  });
}

/* ---- Inventory ---- */

export function listInventoryTypes(providerId: string, venueId: string) {
  return coreFetch<unknown[]>({
    method: "GET",
    path: "/v1/provider/inventory-types",
    query: { providerId, venueId },
    idempotent: false,
  });
}

export function createInventoryType(body: {
  providerId: string;
  venueId: string;
  code: string;
  labelAr: string;
  inventoryModel: "pooled" | "physical";
  quantityTotal: number;
  baseOccupancy: number;
  maxOccupancy: number;
  sortOrder?: number;
}) {
  return coreFetch<unknown>({
    method: "POST",
    path: "/v1/provider/inventory-types",
    body,
  });
}

export function patchInventoryType(
  id: string,
  body: Record<string, unknown>,
) {
  return coreFetch<unknown>({
    method: "PATCH",
    path: `/v1/provider/inventory-types/${id}`,
    body,
  });
}

/* ---- Pricing / availability ---- */

export function putPricing(body: {
  ratePlanId: string;
  kind: string;
  amount: string;
  dateFrom?: string;
  dateTo?: string;
  priority?: number;
}) {
  return coreFetch<{ ok: true }>({
    method: "PUT",
    path: "/v1/provider/pricing",
    body,
  });
}

export function putAvailability(body: {
  inventoryTypeId: string;
  date: string;
  kind: "block" | "open" | "maintenance";
  reason?: string;
}) {
  return coreFetch<{ ok: true }>({
    method: "PUT",
    path: "/v1/provider/availability",
    body,
  });
}

export function getCalendar(providerId: string, from: string, to: string) {
  return coreFetch<unknown>({
    method: "GET",
    path: "/v1/provider/calendar",
    query: { providerId, from, to },
    idempotent: false,
  });
}

export function listRatePlans(providerId: string, venueId?: string) {
  return coreFetch<unknown>({
    method: "GET",
    path: "/v1/provider/rate-plans",
    query: { providerId, venueId },
    idempotent: false,
  });
}

export function createRatePlan(body: Record<string, unknown>) {
  return coreFetch<unknown>({
    method: "POST",
    path: "/v1/provider/rate-plans",
    body,
  });
}

/* ---- Media ---- */

export function listMedia(providerId: string, venueId: string) {
  return coreFetch<unknown>({
    method: "GET",
    path: "/v1/provider/media",
    query: { providerId, venueId },
    idempotent: false,
  });
}

export function createImageUploadSession(body: {
  venueId: string;
  inventoryTypeId?: string;
}) {
  return coreFetch<{
    uploadSessionId: string;
    uploadURL: string;
    imagesHash: string;
    expiresAt: string;
    cloudflareImageId?: string;
  }>({
    method: "POST",
    path: "/v1/provider/media/images/upload-session",
    body,
  });
}

export function completeImageUpload(body: {
  uploadSessionId: string;
  cloudflareImageId: string;
  inventoryTypeId?: string;
  sortOrder?: number;
  isCover?: boolean;
}) {
  return coreFetch<{ mediaId: string; url: string }>({
    method: "POST",
    path: "/v1/provider/media/images/complete",
    body,
  });
}

export function listLocationCities() {
  return coreFetch<unknown[]>({
    method: "GET",
    path: "/v1/provider/location/cities",
    idempotent: false,
  });
}

export function listLocationDistricts(cityId: string) {
  return coreFetch<unknown[]>({
    method: "GET",
    path: "/v1/provider/location/districts",
    query: { cityId },
    idempotent: false,
  });
}

export function listAmenityCatalog(venueType?: string) {
  return coreFetch<unknown[]>({
    method: "GET",
    path: "/v1/provider/amenities/catalog",
    query: { venueType },
    idempotent: false,
  });
}

export function listVenueAmenities(venueId: string) {
  return coreFetch<unknown[]>({
    method: "GET",
    path: `/v1/provider/venues/${venueId}/amenities`,
    idempotent: false,
  });
}

export function putVenueAmenities(body: {
  venueId: string;
  inventoryTypeId?: string;
  codes: string[];
}) {
  return coreFetch<{ ok: true; codes: string[] }>({
    method: "PUT",
    path: "/v1/provider/amenities",
    body,
  });
}

export function createVideoUploadSession(body: {
  venueId: string;
  title?: string;
  inventoryTypeId?: string;
}) {
  return coreFetch<{
    uploadSessionId: string;
    uploadURL: string;
    expiresAt?: string;
  }>({
    method: "POST",
    path: "/v1/provider/media/videos/upload-session",
    body,
  });
}

export function completeVideoUpload(body: {
  uploadSessionId: string;
  purpose?: string;
  coverUrl?: string;
}) {
  return coreFetch<{ mediaId: string }>({
    method: "POST",
    path: "/v1/provider/media/videos/complete",
    body,
  });
}

export function reorderMedia(body: {
  venueId: string;
  inventoryTypeId?: string;
  orderedMediaIds: string[];
  expectedCasVersions: number[];
}) {
  return coreFetch<unknown>({
    method: "PUT",
    path: "/v1/provider/media/reorder",
    body,
  });
}

export function setMediaCover(
  mediaId: string,
  body: { expectedCasVersion: number },
) {
  return coreFetch<unknown>({
    method: "PUT",
    path: `/v1/provider/media/${mediaId}/cover`,
    body,
  });
}

export function deleteMedia(
  mediaId: string,
  body: { expectedCasVersion: number },
) {
  return coreFetch<unknown>({
    method: "POST",
    path: `/v1/provider/media/${mediaId}/delete`,
    body,
  });
}

/* ---- Bookings ---- */

export function listBookings(providerId: string) {
  return coreFetch<unknown[]>({
    method: "GET",
    path: "/v1/provider/bookings",
    query: { providerId },
    idempotent: false,
  });
}

export function getBooking(bookingId: string, providerId: string) {
  return coreFetch<unknown>({
    method: "GET",
    path: `/v1/provider/bookings/${bookingId}`,
    query: { providerId },
    idempotent: false,
  });
}

export function cancelBooking(
  bookingId: string,
  body: { reason: string },
) {
  return coreFetch<unknown>({
    method: "POST",
    path: `/v1/provider/bookings/${bookingId}/cancel`,
    body,
  });
}

export function listPendingModeration(providerId: string) {
  return coreFetch<unknown[]>({
    method: "GET",
    path: "/v1/provider/media/pending-moderation",
    query: { providerId },
    idempotent: false,
  });
}

export function moderateMedia(
  mediaId: string,
  body: {
    moderationStatus: "approved" | "rejected";
    expectedCasVersion: number;
    reason?: string;
  },
) {
  return coreFetch<{ ok: true; moderationStatus: string; casVersion: number }>({
    method: "PATCH",
    path: `/v1/provider/media/${mediaId}/moderation`,
    body,
  });
}

/** Normalize list-like Core payloads. */
export function asArray(data: unknown): unknown[] {
  if (Array.isArray(data)) return data;
  if (
    data &&
    typeof data === "object" &&
    "items" in data &&
    Array.isArray((data as { items: unknown }).items)
  ) {
    return (data as { items: unknown[] }).items;
  }
  if (
    data &&
    typeof data === "object" &&
    "venues" in data &&
    Array.isArray((data as { venues: unknown }).venues)
  ) {
    return (data as { venues: unknown[] }).venues;
  }
  return [];
}
