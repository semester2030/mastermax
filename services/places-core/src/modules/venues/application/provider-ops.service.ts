import { Inject, Injectable } from "@nestjs/common";
import { AuthUser, hasClaim } from "../../../shared/auth/auth-user";
import { PgService } from "../../../shared/database/pg.service";
import { AppError } from "../../../shared/errors/app-error";
import { ErrorCodes } from "../../../shared/errors/error-codes";
import { newId } from "../../../shared/ids/ids";
import { AuditService } from "../../audit/application/audit.service";
import { CapacityService } from "../../inventory/application/capacity.service";
import { TenancyService } from "../../providers/application/tenancy.service";
import { VenueTypeCapabilityPolicy } from "../../filters/application/venue-type-capability.policy";
import {
  CLOUDFLARE_MEDIA_PORT,
  CloudflareMediaPort,
} from "../../media/domain/cloudflare-media.port";
import { VenuePublicationService } from "./venue-publication.service";
import { MediaModerationService } from "./media-moderation.service";
import { MEDIA_LIMITS } from "../../media/domain/media-contract";
import { LocationCatalogService } from "./location-catalog.service";
import {
  isValidLatitude,
  isValidLongitude,
  projectVenueLocation,
} from "./venue-location";

const UPLOAD_SESSION_TTL_MS = 30 * 60 * 1000;

@Injectable()
export class ProviderOpsService {
  constructor(
    private readonly pg: PgService,
    private readonly tenancy: TenancyService,
    private readonly audit: AuditService,
    private readonly capacity: CapacityService,
    private readonly caps: VenueTypeCapabilityPolicy,
    @Inject(CLOUDFLARE_MEDIA_PORT) private readonly cf: CloudflareMediaPort,
    private readonly publication: VenuePublicationService,
    private readonly moderation: MediaModerationService,
    private readonly locations: LocationCatalogService,
  ) {}

  private actorUid(actor: string | AuthUser): string {
    return typeof actor === "string" ? actor : actor.uid;
  }

  /**
   * After CF mint succeeded but DB bind failed / crashed mid-path:
   * expire the pending session and enqueue outbox delete (worker performs CF delete).
   * No Cloudflare network I/O inside the DB transaction.
   */
  private async compensateMintedCfAsset(input: {
    sessionId: string;
    kind: "image" | "video";
    cloudflareImageId?: string | null;
    streamUid?: string | null;
  }): Promise<void> {
    await this.pg.tx(async (c) => {
      await c.query(
        `UPDATE media_upload_sessions SET status = 'expired'
         WHERE id = $1 AND status = 'pending'`,
        [input.sessionId],
      );
      if (input.cloudflareImageId || input.streamUid) {
        await c.query(
          `INSERT INTO media_cf_delete_outbox
             (id, kind, cloudflare_image_id, stream_uid, status, next_attempt_at)
           VALUES ($1,$2,$3,$4,'pending', now())`,
          [
            newId(),
            input.kind,
            input.cloudflareImageId ?? null,
            input.streamUid ?? null,
          ],
        );
      }
    });
  }

  async createVenue(
    actor: string | AuthUser,
    body: {
      providerId: string;
      name: string;
      venueType: string;
      bookingMode: "nightly" | "daily" | "event_slot";
      city?: string;
    },
    correlationId: string,
  ): Promise<{ venueId: string }> {
    await this.tenancy.require(actor, body.providerId, "venue.crud");
    await this.caps.requireProviderEnabled(body.venueType);
    // event_slot create still requires PLACES_EVENT_SLOT_ENABLED=true (capabilities stay OFF).
    this.caps.requireEventSlotPathAllowed(body.bookingMode);
    const id = newId();
    await this.pg.query(
      `INSERT INTO venues (id, provider_id, name, venue_type, booking_mode, status, city)
       VALUES ($1,$2,$3,$4,$5,'draft',$6)`,
      [
        id,
        body.providerId,
        body.name,
        body.venueType,
        body.bookingMode,
        body.city ?? null,
      ],
    );
    await this.audit.write({
      actorUid: typeof actor === "string" ? actor : actor.uid,
      actorRole: "provider",
      entityType: "venue",
      entityId: id,
      after: body,
      correlationId,
    });
    return { venueId: id };
  }

  async listVenues(
    actor: string | AuthUser,
    providerId: string,
  ): Promise<unknown[]> {
    await this.tenancy.require(actor, providerId, "venue.crud");
    const res = await this.pg.query(
      `SELECT id, name, venue_type, booking_mode, status, city, city_id, district,
              district_id, street, building_no, google_place_id, formatted_address,
              location_source, lat, lng, created_at, updated_at
       FROM venues
       WHERE provider_id = $1
       ORDER BY updated_at DESC NULLS LAST, created_at DESC`,
      [providerId],
    );
    return res.rows.map((r) => {
      const location = projectVenueLocation(r);
      return {
        id: r.id,
        name: r.name,
        venueType: r.venue_type,
        bookingMode: r.booking_mode,
        status: r.status,
        city: r.city,
        cityId: r.city_id,
        district: r.district,
        districtId: r.district_id,
        street: r.street,
        googlePlaceId: location.googlePlaceId,
        formattedAddress: location.formattedAddress,
        locationSource: location.locationSource,
        lat: location.lat,
        lng: location.lng,
        latitude: location.latitude,
        longitude: location.longitude,
        locationComplete: location.locationComplete,
        createdAt: r.created_at,
        updatedAt: r.updated_at,
      };
    });
  }

  async getVenue(
    actor: string | AuthUser,
    venueId: string,
  ): Promise<Record<string, unknown>> {
    const v = await this.pg.query<{
      id: string;
      provider_id: string;
      name: string;
      venue_type: string;
      booking_mode: string;
      status: string;
      city: string | null;
      district: string | null;
      city_id: string | null;
      district_id: string | null;
      street: string | null;
      building_no: string | null;
      landmark: string | null;
      access_notes: string | null;
      maps_url: string | null;
      location_source: string | null;
      google_place_id: string | null;
      formatted_address: string | null;
      lat: number | null;
      lng: number | null;
      created_at: Date;
      updated_at: Date;
    }>(
      `SELECT id, provider_id, name, venue_type, booking_mode, status, city, district,
              city_id, district_id, street, building_no, landmark, access_notes,
              maps_url, location_source, google_place_id, formatted_address,
              lat, lng, created_at, updated_at
       FROM venues WHERE id = $1`,
      [venueId],
    );
    if (!v.rowCount) {
      throw new AppError(ErrorCodes.NOT_FOUND, "Venue not found");
    }
    await this.tenancy.require(actor, v.rows[0].provider_id, "venue.crud");
    const row = v.rows[0];
    const location = projectVenueLocation(row);
    return {
      id: row.id,
      providerId: row.provider_id,
      name: row.name,
      venueType: row.venue_type,
      bookingMode: row.booking_mode,
      status: row.status,
      city: row.city,
      district: row.district,
      cityId: row.city_id,
      districtId: row.district_id,
      street: row.street,
      buildingNo: row.building_no,
      landmark: row.landmark,
      accessNotes: row.access_notes,
      mapsUrl: row.maps_url,
      locationSource: location.locationSource,
      googlePlaceId: location.googlePlaceId,
      formattedAddress: location.formattedAddress,
      lat: location.lat,
      lng: location.lng,
      latitude: location.latitude,
      longitude: location.longitude,
      locationComplete: location.locationComplete,
      addressDetails: {
        buildingNo: row.building_no,
        landmark: row.landmark,
        accessNotes: row.access_notes,
      },
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    };
  }

  async listMedia(
    actor: string | AuthUser,
    venueId: string,
  ): Promise<unknown[]> {
    const v = await this.pg.query<{ provider_id: string }>(
      `SELECT provider_id FROM venues WHERE id = $1`,
      [venueId],
    );
    if (!v.rowCount) {
      throw new AppError(ErrorCodes.NOT_FOUND, "Venue not found");
    }
    await this.tenancy.require(actor, v.rows[0].provider_id, "media.upload");
    const res = await this.pg.query(
      `SELECT id, kind, url, stream_uid, cover_url, moderation_status, sort_order,
              is_cover, cas_version, inventory_type_id, deleted_at, created_at
       FROM venue_media
       WHERE venue_id = $1 AND deleted_at IS NULL
       ORDER BY sort_order ASC, created_at ASC`,
      [venueId],
    );
    return res.rows.map((r) => ({
      id: r.id,
      kind: r.kind,
      /** Contract alias of moderationStatus (F-V3-013). */
      status: r.moderation_status,
      moderationStatus: r.moderation_status,
      /** venue | inventory_type */
      scope: r.inventory_type_id ? "inventory_type" : "venue",
      /** Contract alias of sortOrder */
      order: r.sort_order,
      sortOrder: r.sort_order,
      /** Contract alias of isCover */
      cover: r.is_cover,
      isCover: r.is_cover,
      url: r.url,
      streamUid: r.stream_uid,
      coverUrl: r.cover_url,
      casVersion: r.cas_version,
      // Null marks venue-level media — the only kind that satisfies publish.
      inventoryTypeId: r.inventory_type_id,
      createdAt: r.created_at,
    }));
  }

  /**
   * Wave1 RC2 — staging/internal only. Forbidden when NODE_ENV=production.
   */
  private assertInternalOperatorStaging(actor: AuthUser): void {
    if (process.env.NODE_ENV === "production") {
      throw new AppError(
        ErrorCodes.FORBIDDEN_PROVIDER_SCOPE,
        "Internal media moderation is forbidden in production",
      );
    }
    if (!hasClaim(actor, "placesInternalOperator")) {
      throw new AppError(
        ErrorCodes.FORBIDDEN_PROVIDER_SCOPE,
        "placesInternalOperator required",
      );
    }
  }

  async listPendingModerationForOperator(
    actor: AuthUser,
    providerId?: string,
  ): Promise<unknown[]> {
    this.assertInternalOperatorStaging(actor);
    const pid = providerId ?? actor.onBehalfOfProviderId;
    if (!pid) {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, "providerId required");
    }
    await this.tenancy.require(actor, pid, "media.upload");
    const res = await this.pg.query(
      `SELECT m.id, m.venue_id, m.kind, m.url, m.stream_uid, m.cover_url,
              m.moderation_status, m.cas_version, m.is_cover, m.created_at,
              v.name AS venue_name
       FROM venue_media m
       JOIN venues v ON v.id = m.venue_id
       WHERE m.provider_id = $1
         AND m.deleted_at IS NULL
         AND m.moderation_status = 'pending'
       ORDER BY m.created_at ASC`,
      [pid],
    );
    return res.rows.map((r) => ({
      id: r.id,
      venueId: r.venue_id,
      venueName: r.venue_name,
      kind: r.kind,
      url: r.url,
      streamUid: r.stream_uid,
      coverUrl: r.cover_url,
      moderationStatus: r.moderation_status,
      casVersion: r.cas_version,
      isCover: r.is_cover,
      createdAt: r.created_at,
    }));
  }

  async moderateMediaAsOperator(
    actor: AuthUser,
    mediaId: string,
    body: {
      moderationStatus: "approved" | "rejected";
      expectedCasVersion: number;
      reason?: string;
      rejectionReason?: string;
    },
    correlationId: string,
  ): Promise<{ ok: true; moderationStatus: string; casVersion: number }> {
    this.assertInternalOperatorStaging(actor);
    const before = await this.pg.query<{
      provider_id: string;
      deleted_at: Date | null;
    }>(
      `SELECT provider_id, deleted_at FROM venue_media WHERE id = $1`,
      [mediaId],
    );
    if (!before.rowCount || before.rows[0].deleted_at) {
      throw new AppError(ErrorCodes.NOT_FOUND, "Media not found");
    }
    await this.tenancy.require(actor, before.rows[0].provider_id, "media.upload");
    return this.moderation.moderate({
      mediaId,
      decision: body.moderationStatus,
      expectedCasVersion: body.expectedCasVersion,
      actorUid: actor.uid,
      actorRole: "placesInternalOperator",
      correlationId,
      reason: body.reason,
      rejectionReason: body.rejectionReason,
    });
  }

  async patchVenue(
    actor: string | AuthUser,
    venueId: string,
    patch: Record<string, unknown>,
    correlationId: string,
  ): Promise<void> {
    const v = await this.pg.query<{ provider_id: string; status: string }>(
      "SELECT provider_id, status FROM venues WHERE id = $1",
      [venueId],
    );
    if (!v.rowCount) {
      throw new AppError(ErrorCodes.NOT_FOUND, "Venue not found");
    }
    await this.tenancy.require(actor, v.rows[0].provider_id, "venue.crud");
    if (patch.status === "published" || patch.status === "draft") {
      await this.tenancy.require(actor, v.rows[0].provider_id, "venue.publish");
    }
    if (patch.status === "published") {
      await this.applyLocationPatch(venueId, patch);
      await this.publication.publishVenue({
        venueId,
        actorUid: this.actorUid(actor),
        actorRole: "provider",
        correlationId,
        name: typeof patch.name === "string" ? patch.name : null,
        city: typeof patch.city === "string" ? patch.city : null,
      });
      return;
    }
    await this.applyLocationPatch(venueId, patch);
    await this.pg.query(
      `UPDATE venues SET
         name = COALESCE($2, name),
         status = COALESCE($3, status),
         updated_at = now()
       WHERE id = $1`,
      [venueId, patch.name ?? null, patch.status ?? null],
    );
    await this.audit.write({
      actorUid: typeof actor === "string" ? actor : actor.uid,
      actorRole: "provider",
      entityType: "venue",
      entityId: venueId,
      before: v.rows[0],
      after: patch,
      correlationId,
    });
  }

  private async applyLocationPatch(
    venueId: string,
    patch: Record<string, unknown>,
  ): Promise<void> {
    const cityId = typeof patch.cityId === "string" ? patch.cityId : undefined;
    const districtId =
      typeof patch.districtId === "string" ? patch.districtId : undefined;
    const hasLocation =
      cityId != null ||
      districtId != null ||
      typeof patch.street === "string" ||
      typeof patch.district === "string" ||
      typeof patch.city === "string" ||
      typeof patch.buildingNo === "string" ||
      typeof patch.landmark === "string" ||
      typeof patch.accessNotes === "string" ||
      typeof patch.mapsUrl === "string" ||
      typeof patch.locationSource === "string" ||
      typeof patch.googlePlaceId === "string" ||
      typeof patch.formattedAddress === "string" ||
      typeof patch.lat === "number" ||
      typeof patch.lng === "number" ||
      typeof patch.latitude === "number" ||
      typeof patch.longitude === "number";
    if (!hasLocation) {
      return;
    }
    const names = await this.locations.resolveNames({
      cityId: cityId ?? null,
      districtId: districtId ?? null,
    });
    const latRaw = patch.lat ?? patch.latitude;
    const lngRaw = patch.lng ?? patch.longitude;
    const lat = isValidLatitude(latRaw) ? latRaw : null;
    const lng = isValidLongitude(lngRaw) ? lngRaw : null;
    if ((latRaw != null && lat == null) || (lngRaw != null && lng == null)) {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        "latitude must be between -90 and 90 and longitude between -180 and 180",
      );
    }
    await this.pg.query(
      `UPDATE venues SET
         city_id = COALESCE($2, city_id),
         district_id = COALESCE($3, district_id),
         street = COALESCE($4, street),
         building_no = COALESCE($5, building_no),
         landmark = COALESCE($6, landmark),
         access_notes = COALESCE($7, access_notes),
         maps_url = COALESCE($8, maps_url),
         location_source = COALESCE($9, location_source),
         google_place_id = COALESCE($10, google_place_id),
         formatted_address = COALESCE($11, formatted_address),
         lat = COALESCE($12, lat),
         lng = COALESCE($13, lng),
         city = COALESCE($14, city),
         district = COALESCE($15, district),
         updated_at = now()
       WHERE id = $1`,
      [
        venueId,
        cityId ?? null,
        districtId ?? null,
        typeof patch.street === "string" ? patch.street.trim() : null,
        typeof patch.buildingNo === "string" ? patch.buildingNo.trim() : null,
        typeof patch.landmark === "string" ? patch.landmark.trim() : null,
        typeof patch.accessNotes === "string" ? patch.accessNotes.trim() : null,
        typeof patch.mapsUrl === "string" ? patch.mapsUrl.trim() : null,
        typeof patch.locationSource === "string"
          ? patch.locationSource
          : "manual",
        typeof patch.googlePlaceId === "string"
          ? patch.googlePlaceId.trim()
          : null,
        typeof patch.formattedAddress === "string"
          ? patch.formattedAddress.trim()
          : null,
        lat,
        lng,
        names.city ?? (typeof patch.city === "string" ? patch.city : null),
        names.district ??
          (typeof patch.district === "string" ? patch.district : null),
      ],
    );
  }

  async putAmenities(
    actor: string | AuthUser,
    body: { venueId: string; inventoryTypeId?: string; codes: string[] },
    correlationId: string,
  ): Promise<{ ok: true; codes: string[] }> {
    const v = await this.pg.query<{ provider_id: string; venue_type: string }>(
      `SELECT provider_id, venue_type FROM venues WHERE id = $1`,
      [body.venueId],
    );
    if (!v.rowCount) {
      throw new AppError(ErrorCodes.NOT_FOUND, "Venue not found");
    }
    await this.tenancy.require(actor, v.rows[0].provider_id, "venue.crud");
    const unique = [...new Set(body.codes.map((c) => c.trim()).filter(Boolean))];
    if (unique.length) {
      const catalog = await this.pg.query<{ code: string }>(
        `SELECT code FROM amenity_catalog
         WHERE status = 'active' AND code = ANY($1::text[])
           AND (
             applicable_venue_types @> ARRAY['*']::text[]
             OR applicable_venue_types @> ARRAY[$2]::text[]
           )`,
        [unique, v.rows[0].venue_type],
      );
      if (catalog.rowCount !== unique.length) {
        throw new AppError(
          ErrorCodes.VALIDATION_ERROR,
          "Amenity codes must come from the venue-type catalog",
        );
      }
    }
    if (body.inventoryTypeId) {
      const t = await this.pg.query(
        `SELECT 1 FROM inventory_types WHERE id = $1 AND venue_id = $2`,
        [body.inventoryTypeId, body.venueId],
      );
      if (!t.rowCount) {
        throw new AppError(ErrorCodes.VALIDATION_ERROR, "inventoryTypeId not on venue");
      }
    }
    const scope = body.inventoryTypeId ? "inventory" : "venue";
    await this.pg.tx(async (c) => {
      if (body.inventoryTypeId) {
        await c.query(
          `DELETE FROM venue_amenity_links
           WHERE venue_id = $1 AND inventory_type_id = $2`,
          [body.venueId, body.inventoryTypeId],
        );
      } else {
        await c.query(
          `DELETE FROM venue_amenity_links
           WHERE venue_id = $1 AND inventory_type_id IS NULL`,
          [body.venueId],
        );
      }
      for (const code of unique) {
        await c.query(
          `INSERT INTO venue_amenity_links
             (id, venue_id, amenity_code, inventory_type_id, scope, state)
           VALUES ($1,$2,$3,$4,$5,'AVAILABLE')`,
          [newId(), body.venueId, code, body.inventoryTypeId ?? null, scope],
        );
      }
    });
    await this.audit.write({
      actorUid: this.actorUid(actor),
      actorRole: "provider",
      entityType: "venue_amenities",
      entityId: body.venueId,
      after: { codes: unique, inventoryTypeId: body.inventoryTypeId ?? null },
      correlationId,
    });
    return { ok: true, codes: unique };
  }

  async listVenueAmenities(
    actor: string | AuthUser,
    venueId: string,
  ): Promise<unknown[]> {
    const v = await this.pg.query<{ provider_id: string }>(
      `SELECT provider_id FROM venues WHERE id = $1`,
      [venueId],
    );
    if (!v.rowCount) {
      throw new AppError(ErrorCodes.NOT_FOUND, "Venue not found");
    }
    await this.tenancy.require(actor, v.rows[0].provider_id, "venue.crud");
    const res = await this.pg.query(
      `SELECT l.amenity_code AS code, l.inventory_type_id, l.scope, l.state,
              ac.label_ar, ac.label_en, ac.icon_key
       FROM venue_amenity_links l
       JOIN amenity_catalog ac ON ac.code = l.amenity_code
       WHERE l.venue_id = $1
       ORDER BY ac.sort_order, l.amenity_code`,
      [venueId],
    );
    return res.rows.map((r) => ({
      code: r.amenity_code ?? r.code,
      id: r.amenity_code ?? r.code,
      inventoryTypeId: r.inventory_type_id,
      scope: r.scope,
      state: r.state,
      labelAr: r.label_ar,
      labelEn: r.label_en,
      iconKey: r.icon_key,
    }));
  }

  async putAvailability(
    actor: string | AuthUser,
    body: {
      inventoryTypeId: string;
      date: string;
      kind: "block" | "open" | "maintenance";
      reason?: string;
    },
    correlationId: string,
  ): Promise<void> {
    const t = await this.pg.query<{ venue_id: string }>(
      "SELECT venue_id FROM inventory_types WHERE id = $1",
      [body.inventoryTypeId],
    );
    if (!t.rowCount) {
      throw new AppError(ErrorCodes.NOT_FOUND, "Inventory type not found");
    }
    const v = await this.pg.query<{ provider_id: string }>(
      "SELECT provider_id FROM venues WHERE id = $1",
      [t.rows[0].venue_id],
    );
    await this.tenancy.require(actor, v.rows[0].provider_id, "inventory.block");
    await this.pg.tx(async (c) => {
      // Idempotent upsert via partial unique (NULL unit): PG treats NULL≠NULL on full UNIQUE.
      await c.query(
        `INSERT INTO availability_overrides (id, inventory_type_id, date, kind, reason)
         VALUES ($1,$2,$3::date,$4,$5)
         ON CONFLICT (inventory_type_id, date, kind) WHERE inventory_unit_id IS NULL
         DO UPDATE SET reason = EXCLUDED.reason`,
        [
          newId(),
          body.inventoryTypeId,
          body.date,
          body.kind,
          body.reason ?? null,
        ],
      );
      if (body.kind === "open") {
        // Opening a day clears type-level block/maintenance overrides for that date.
        await c.query(
          `DELETE FROM availability_overrides
           WHERE inventory_type_id = $1 AND inventory_unit_id IS NULL AND date = $2::date
             AND kind IN ('block', 'maintenance')`,
          [body.inventoryTypeId, body.date],
        );
      }
      await this.capacity.recomputeBlocked(body.inventoryTypeId, body.date, c);
      await this.audit.write(
        {
          actorUid: typeof actor === "string" ? actor : actor.uid,
          actorRole: "provider",
          entityType: "availability",
          entityId: body.inventoryTypeId,
          after: body,
          reason: body.reason,
          correlationId,
        },
        c,
      );
    });
  }

  async putPricing(
    actor: string | AuthUser,
    body: {
      ratePlanId: string;
      kind: string;
      amount: string;
      dateFrom?: string;
      dateTo?: string;
      priority?: number;
    },
    correlationId: string,
  ): Promise<void> {
    const plan = await this.pg.query<{ inventory_type_id: string }>(
      "SELECT inventory_type_id FROM rate_plans WHERE id = $1",
      [body.ratePlanId],
    );
    const t = await this.pg.query<{ venue_id: string }>(
      "SELECT venue_id FROM inventory_types WHERE id = $1",
      [plan.rows[0].inventory_type_id],
    );
    const v = await this.pg.query<{ provider_id: string }>(
      "SELECT provider_id FROM venues WHERE id = $1",
      [t.rows[0].venue_id],
    );
    await this.tenancy.require(actor, v.rows[0].provider_id, "pricing.edit");
    await this.pg.tx(async (c) => {
      // Upsert by logical key (rate_plan_id, kind, date_from, date_to) so sticky
      // handler replay after idempotency expiry cannot duplicate rate_rules.
      const matching = await c.query<{ id: string }>(
        `SELECT id FROM rate_rules
         WHERE rate_plan_id = $1
           AND kind = $2
           AND date_from IS NOT DISTINCT FROM $3::date
           AND date_to IS NOT DISTINCT FROM $4::date
         ORDER BY priority DESC, id ASC
         FOR UPDATE`,
        [
          body.ratePlanId,
          body.kind,
          body.dateFrom ?? null,
          body.dateTo ?? null,
        ],
      );
      if (matching.rowCount) {
        const keepId = matching.rows[0].id;
        await c.query(
          `UPDATE rate_rules SET amount = $2, priority = $3 WHERE id = $1`,
          [keepId, body.amount, body.priority ?? 0],
        );
        if (matching.rowCount > 1) {
          await c.query(
            `DELETE FROM rate_rules
             WHERE rate_plan_id = $1
               AND kind = $2
               AND date_from IS NOT DISTINCT FROM $3::date
               AND date_to IS NOT DISTINCT FROM $4::date
               AND id <> $5`,
            [
              body.ratePlanId,
              body.kind,
              body.dateFrom ?? null,
              body.dateTo ?? null,
              keepId,
            ],
          );
        }
      } else {
        await c.query(
          `INSERT INTO rate_rules (id, rate_plan_id, kind, amount, date_from, date_to, priority)
           VALUES ($1,$2,$3,$4,$5::date,$6::date,$7)`,
          [
            newId(),
            body.ratePlanId,
            body.kind,
            body.amount,
            body.dateFrom ?? null,
            body.dateTo ?? null,
            body.priority ?? 0,
          ],
        );
      }
      await this.audit.write(
        {
          actorUid: typeof actor === "string" ? actor : actor.uid,
          actorRole: "provider",
          entityType: "pricing",
          entityId: body.ratePlanId,
          after: body,
          correlationId,
        },
        c,
      );
    });
  }

  /**
   * @deprecated Gone — use POST media/videos/upload-session + complete.
   */
  async registerMedia(
    _actor: string | AuthUser,
    _body: {
      venueId: string;
      streamUid: string;
      purpose: string;
      coverUrl?: string;
    },
    _correlationId: string,
  ): Promise<{ mediaId: string; upload: string }> {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, "use upload-session");
  }

  /** Step 1: signed Cloudflare Stream upload URL (direct upload; no Nest bytes). */
  async createStreamUploadSession(
    actor: string | AuthUser,
    body: { venueId: string; title?: string; inventoryTypeId?: string },
    correlationId: string,
  ): Promise<{
    uploadSessionId: string;
    uploadURL: string;
    streamUid: string;
    customerSubdomain: string;
    expiresAt: string;
  }> {
    const v = await this.pg.query<{ provider_id: string }>(
      "SELECT provider_id FROM venues WHERE id = $1",
      [body.venueId],
    );
    if (!v.rowCount) {
      throw new AppError(ErrorCodes.NOT_FOUND, "Venue not found");
    }
    await this.tenancy.require(actor, v.rows[0].provider_id, "media.upload");
    if (body.inventoryTypeId) {
      const t = await this.pg.query(
        `SELECT 1 FROM inventory_types WHERE id = $1 AND venue_id = $2`,
        [body.inventoryTypeId, body.venueId],
      );
      if (!t.rowCount) {
        throw new AppError(ErrorCodes.VALIDATION_ERROR, "inventoryTypeId not on venue");
      }
    }

    // Phase 6 RC2 + 8B: atomic video quota reservation BEFORE CF mint, per scope.
    const sessionId = newId();
    const expiresAt = new Date(Date.now() + UPLOAD_SESSION_TTL_MS);
    await this.pg.tx(async (c) => {
      await c.query(`SELECT places_lock_media_write_scope($1::uuid, $2::uuid)`, [
        body.venueId,
        body.inventoryTypeId ?? null,
      ]);
      await c.query(`SELECT places_expire_stale_video_upload_sessions($1::uuid)`, [
        body.venueId,
      ]);
      const used = await c.query<{ c: string }>(
        `SELECT places_video_quota_used_scope($1::uuid, $2::uuid)::text AS c`,
        [body.venueId, body.inventoryTypeId ?? null],
      );
      if (Number(used.rows[0].c) >= MEDIA_LIMITS.maxVideosPerScope) {
        throw new AppError(
          ErrorCodes.VALIDATION_ERROR,
          `Video quota full (max ${MEDIA_LIMITS.maxVideosPerScope} pending+approved)`,
        );
      }
      await c.query(
        `INSERT INTO media_upload_sessions (
           id, provider_id, venue_id, inventory_type_id, kind, stream_uid, status, created_by_uid, expires_at
         ) VALUES ($1,$2,$3,$4,'video',NULL,'pending',$5,$6)`,
        [
          sessionId,
          v.rows[0].provider_id,
          body.venueId,
          body.inventoryTypeId ?? null,
          this.actorUid(actor),
          expiresAt.toISOString(),
        ],
      );
    });

    let mintedUid: string | null = null;
    let direct: {
      uploadURL: string;
      uid: string;
      customerSubdomain: string;
    };
    try {
      direct = await this.cf.createStreamDirectUpload(body.title);
      mintedUid = direct.uid;
      const upd = await this.pg.query(
        `UPDATE media_upload_sessions SET stream_uid = $2
         WHERE id = $1 AND status = 'pending'`,
        [sessionId, direct.uid],
      );
      if (!upd.rowCount) {
        throw new AppError(
          ErrorCodes.VALIDATION_ERROR,
          "Upload session no longer pending for stream bind",
        );
      }
      await this.audit.write({
        actorUid: typeof actor === "string" ? actor : actor.uid,
        actorRole: "provider",
        entityType: "media_upload_session",
        entityId: sessionId,
        after: { venueId: body.venueId, kind: "video", streamUid: direct.uid },
        correlationId,
      });
    } catch (err) {
      if (mintedUid) {
        await this.compensateMintedCfAsset({
          sessionId,
          kind: "video",
          streamUid: mintedUid,
        });
      } else {
        await this.pg.query(
          `UPDATE media_upload_sessions SET status = 'expired' WHERE id = $1 AND status = 'pending'`,
          [sessionId],
        );
      }
      throw err;
    }
    return {
      uploadSessionId: sessionId,
      uploadURL: direct.uploadURL,
      streamUid: direct.uid,
      customerSubdomain: direct.customerSubdomain,
      expiresAt: expiresAt.toISOString(),
    };
  }

  /** Step 2: after Stream upload — persist stream_uid + HLS URL (pending moderation). */
  async completeStreamUpload(
    actor: string | AuthUser,
    body: {
      uploadSessionId: string;
      purpose?: string;
      coverUrl?: string;
    },
    correlationId: string,
  ): Promise<{ mediaId: string; streamUid: string; streamUrl: string }> {
    const session = await this.pg.tx(async (c) => {
      const s = await c.query<{
        id: string;
        provider_id: string;
        venue_id: string;
        inventory_type_id: string | null;
        stream_uid: string | null;
        status: string;
        expires_at: Date;
        completed_media_id: string | null;
        created_by_uid: string;
      }>(
        `SELECT id, provider_id, venue_id, inventory_type_id, stream_uid, status, expires_at,
                completed_media_id, created_by_uid
         FROM media_upload_sessions WHERE id = $1 FOR UPDATE`,
        [body.uploadSessionId],
      );
      if (!s.rowCount) {
        throw new AppError(ErrorCodes.NOT_FOUND, "Upload session not found");
      }
      const row = s.rows[0];
      await this.tenancy.require(actor, row.provider_id, "media.upload");
      if (row.created_by_uid !== this.actorUid(actor)) {
        throw new AppError(ErrorCodes.FORBIDDEN_PROVIDER_SCOPE, "Upload session ownership mismatch");
      }
      if (row.status === "completed" && row.completed_media_id && row.stream_uid) {
        return { ...row, replay: true as const };
      }
      const lateRecoverable =
        row.status === "expired" || row.status === "orphaned_cleaned";
      if (row.status !== "pending" && !lateRecoverable) {
        throw new AppError(ErrorCodes.VALIDATION_ERROR, "Upload session not pending");
      }
      if (!row.stream_uid) {
        throw new AppError(ErrorCodes.VALIDATION_ERROR, "streamUid missing on session");
      }
      return { ...row, replay: false as const };
    });

    if (session.replay && session.completed_media_id && session.stream_uid) {
      const media = await this.pg.query<{ id: string; url: string }>(
        `SELECT id, url FROM venue_media WHERE id = $1 AND deleted_at IS NULL`,
        [session.completed_media_id],
      );
      if (!media.rowCount) {
        throw new AppError(ErrorCodes.NOT_FOUND, "Completed media missing");
      }
      return {
        mediaId: media.rows[0].id,
        streamUid: session.stream_uid,
        streamUrl: media.rows[0].url,
      };
    }

    // Cloudflare outside DB transaction
    const streamStatus = await this.cf.getStreamStatus(session.stream_uid!);
    if (!streamStatus.exists || !streamStatus.readyToStream) {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        "Stream not readyToStream yet",
      );
    }
    const streamUrl = this.cf.streamPlaybackUrl(session.stream_uid!);

    return this.pg.tx(async (c) => {
      const claim = await c.query<{ id: string }>(
        `UPDATE media_upload_sessions
         SET status = 'completed'
         WHERE id = $1 AND status IN ('pending', 'expired', 'orphaned_cleaned')
         RETURNING id`,
        [session.id],
      );
      if (!claim.rowCount) {
        const again = await c.query<{
          completed_media_id: string | null;
          stream_uid: string | null;
        }>(
          `SELECT completed_media_id, stream_uid FROM media_upload_sessions WHERE id = $1`,
          [session.id],
        );
        if (again.rows[0]?.completed_media_id) {
          const m = await c.query<{ id: string; url: string }>(
            `SELECT id, url FROM venue_media WHERE id = $1`,
            [again.rows[0].completed_media_id],
          );
          if (m.rowCount) {
            return {
              mediaId: m.rows[0].id,
              streamUid: again.rows[0].stream_uid!,
              streamUrl: m.rows[0].url,
            };
          }
        }
        throw new AppError(ErrorCodes.DUPLICATE_REQUEST, "Upload session already completed");
      }
      const mediaId = newId();
      await c.query(`SELECT places_lock_media_write_scope($1::uuid, $2::uuid)`, [
        session.venue_id,
        session.inventory_type_id ?? null,
      ]);
      await c.query(`SELECT places_expire_stale_video_upload_sessions($1::uuid)`, [
        session.venue_id,
      ]);
      const used = await c.query<{ c: string }>(
        `SELECT places_video_quota_used_scope($1::uuid, $2::uuid)::text AS c`,
        [session.venue_id, session.inventory_type_id ?? null],
      );
      if (Number(used.rows[0].c) >= MEDIA_LIMITS.maxVideosPerScope) {
        throw new AppError(
          ErrorCodes.VALIDATION_ERROR,
          `Video quota full (max ${MEDIA_LIMITS.maxVideosPerScope} pending+approved)`,
        );
      }
      await c.query(
        `INSERT INTO venue_media (
           id, venue_id, inventory_type_id, provider_id, kind, stream_uid, url, cover_url, purpose, moderation_status
         ) VALUES ($1,$2,$3,$4,'video',$5,$6,$7,$8,'pending')`,
        [
          mediaId,
          session.venue_id,
          session.inventory_type_id ?? null,
          session.provider_id,
          session.stream_uid,
          streamUrl,
          body.coverUrl ?? null,
          body.purpose ?? "hero",
        ],
      );
      await c.query(
        `UPDATE media_upload_sessions
         SET completed_media_id = $2
         WHERE id = $1`,
        [session.id, mediaId],
      );
      await this.audit.write(
        {
          actorUid: typeof actor === "string" ? actor : actor.uid,
          actorRole: "provider",
          entityType: "media",
          entityId: mediaId,
          after: { streamUid: session.stream_uid, streamUrl },
          correlationId,
        },
        c,
      );
      return { mediaId, streamUid: session.stream_uid!, streamUrl };
    });
  }

  /**
   * Direct signed upload — same Cloudflare Images API as DAR CAR Functions.
   * Bytes go client → Cloudflare; Nest never receives the file.
   */
  async createImageUploadSession(
    actor: string | AuthUser,
    body: { venueId: string; inventoryTypeId?: string },
    correlationId: string,
  ): Promise<{
    uploadSessionId: string;
    uploadURL: string;
    imagesHash: string;
    expiresAt: string;
    cloudflareImageId: string | null;
  }> {
    const v = await this.pg.query<{ provider_id: string }>(
      "SELECT provider_id FROM venues WHERE id = $1",
      [body.venueId],
    );
    if (!v.rowCount) {
      throw new AppError(ErrorCodes.NOT_FOUND, "Venue not found");
    }
    await this.tenancy.require(actor, v.rows[0].provider_id, "media.upload");
    if (body.inventoryTypeId) {
      const t = await this.pg.query(
        `SELECT 1 FROM inventory_types WHERE id = $1 AND venue_id = $2`,
        [body.inventoryTypeId, body.venueId],
      );
      if (!t.rowCount) {
        throw new AppError(ErrorCodes.VALIDATION_ERROR, "inventoryTypeId not on venue");
      }
    }

    // Atomic quota reservation: pending session counts toward cap BEFORE CF mint (F-REV4-13).
    const sessionId = newId();
    const expiresAt = new Date(Date.now() + UPLOAD_SESSION_TTL_MS);
    await this.pg.tx(async (c) => {
      await c.query(`SELECT places_lock_media_write_scope($1::uuid, $2::uuid)`, [
        body.venueId,
        body.inventoryTypeId ?? null,
      ]);
      await c.query(
        `SELECT places_expire_stale_image_upload_sessions($1::uuid, $2::uuid)`,
        [body.venueId, body.inventoryTypeId ?? null],
      );
      const used = await c.query<{ c: string }>(
        `SELECT places_image_quota_used($1::uuid, $2::uuid)::text AS c`,
        [body.venueId, body.inventoryTypeId ?? null],
      );
      if (Number(used.rows[0].c) >= 30) {
        throw new AppError(
          ErrorCodes.VALIDATION_ERROR,
          "Image quota full (max 30 pending+approved)",
        );
      }
      // Reserve slot (session row); CF id bound after mint.
      await c.query(
        `INSERT INTO media_upload_sessions (
           id, provider_id, venue_id, inventory_type_id, kind,
           cloudflare_image_id, images_hash, status, created_by_uid, expires_at
         ) VALUES ($1,$2,$3,$4,'image',NULL,NULL,'pending',$5,$6)`,
        [
          sessionId,
          v.rows[0].provider_id,
          body.venueId,
          body.inventoryTypeId ?? null,
          this.actorUid(actor),
          expiresAt.toISOString(),
        ],
      );
    });

    let mintedImageId: string | null = null;
    let direct: {
      uploadURL: string;
      imagesHash: string;
      cloudflareImageId?: string | null;
    };
    try {
      direct = await this.cf.createImagesDirectUpload();
      mintedImageId = direct.cloudflareImageId ?? null;
      const upd = await this.pg.query(
        `UPDATE media_upload_sessions
         SET cloudflare_image_id = $2, images_hash = $3
         WHERE id = $1 AND status = 'pending'`,
        [sessionId, direct.cloudflareImageId ?? null, direct.imagesHash],
      );
      if (!upd.rowCount) {
        throw new AppError(
          ErrorCodes.VALIDATION_ERROR,
          "Upload session no longer pending for image bind",
        );
      }
      await this.audit.write({
        actorUid: typeof actor === "string" ? actor : actor.uid,
        actorRole: "provider",
        entityType: "media_upload_session",
        entityId: sessionId,
        after: {
          venueId: body.venueId,
          kind: "image",
          cloudflareImageId: direct.cloudflareImageId ?? null,
        },
        correlationId,
      });
    } catch (err) {
      if (mintedImageId) {
        await this.compensateMintedCfAsset({
          sessionId,
          kind: "image",
          cloudflareImageId: mintedImageId,
        });
      } else {
        await this.pg.query(
          `UPDATE media_upload_sessions SET status = 'expired' WHERE id = $1 AND status = 'pending'`,
          [sessionId],
        );
      }
      throw err;
    }
    return {
      uploadSessionId: sessionId,
      uploadURL: direct.uploadURL,
      imagesHash: direct.imagesHash,
      expiresAt: expiresAt.toISOString(),
      cloudflareImageId: direct.cloudflareImageId ?? null,
    };
  }

  /**
   * After client uploads to Cloudflare — persist cloudflareImageId + delivery URL.
   * Cloudflare I/O is outside the DB transaction. Completed sessions replay stably.
   */
  async completeImageUpload(
    actor: string | AuthUser,
    body: {
      uploadSessionId: string;
      cloudflareImageId: string;
      inventoryTypeId?: string;
      sortOrder?: number;
      isCover?: boolean;
      purpose?: string;
    },
    correlationId: string,
  ): Promise<{ mediaId: string; url: string; variants: Record<string, string> }> {
    if (!body.cloudflareImageId || body.cloudflareImageId.length < 4) {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, "cloudflareImageId required");
    }

    // Phase 1: validate session (short TX), then CF outside TX.
    const session = await this.pg.tx(async (c) => {
      const s = await c.query<{
        id: string;
        provider_id: string;
        venue_id: string;
        inventory_type_id: string | null;
        kind: string;
        images_hash: string | null;
        status: string;
        expires_at: Date;
        cloudflare_image_id: string | null;
        completed_media_id: string | null;
        created_by_uid: string;
      }>(
        `SELECT id, provider_id, venue_id, inventory_type_id, kind, images_hash, status, expires_at,
                cloudflare_image_id, completed_media_id, created_by_uid
         FROM media_upload_sessions WHERE id = $1 FOR UPDATE`,
        [body.uploadSessionId],
      );
      if (!s.rowCount) {
        throw new AppError(ErrorCodes.NOT_FOUND, "Upload session not found");
      }
      const row = s.rows[0];
      await this.tenancy.require(actor, row.provider_id, "media.upload");
      if (row.created_by_uid !== this.actorUid(actor)) {
        throw new AppError(ErrorCodes.FORBIDDEN_PROVIDER_SCOPE, "Upload session ownership mismatch");
      }
      if (row.kind !== "image") {
        throw new AppError(ErrorCodes.VALIDATION_ERROR, "Upload session kind mismatch (not image)");
      }
      // Stable replay for completed sessions
      if (row.status === "completed" && row.completed_media_id) {
        return { ...row, replay: true as const };
      }
      if (row.status !== "pending") {
        throw new AppError(ErrorCodes.VALIDATION_ERROR, "Upload session not pending");
      }
      if (new Date(row.expires_at).getTime() < Date.now()) {
        await c.query(`UPDATE media_upload_sessions SET status = 'expired' WHERE id = $1`, [
          row.id,
        ]);
        throw new AppError(ErrorCodes.VALIDATION_ERROR, "Upload session expired");
      }
      if (
        body.inventoryTypeId !== undefined &&
        body.inventoryTypeId !== (row.inventory_type_id ?? undefined)
      ) {
        throw new AppError(
          ErrorCodes.VALIDATION_ERROR,
          "inventoryTypeId does not match upload session scope",
        );
      }
      if (!row.cloudflare_image_id) {
        throw new AppError(
          ErrorCodes.VALIDATION_ERROR,
          "Upload session has no bound cloudflareImageId",
        );
      }
      if (body.cloudflareImageId !== row.cloudflare_image_id) {
        throw new AppError(
          ErrorCodes.VALIDATION_ERROR,
          "cloudflareImageId does not match upload session",
        );
      }
      if (!row.images_hash) {
        throw new AppError(ErrorCodes.VALIDATION_ERROR, "Upload session imagesHash missing");
      }
      return { ...row, replay: false as const };
    });

    if (session.replay && session.completed_media_id) {
      const media = await this.pg.query<{
        id: string;
        url: string;
        cloudflare_image_id: string | null;
      }>(
        `SELECT id, url, cloudflare_image_id FROM venue_media WHERE id = $1 AND deleted_at IS NULL`,
        [session.completed_media_id],
      );
      if (!media.rowCount) {
        throw new AppError(ErrorCodes.NOT_FOUND, "Completed media missing");
      }
      const cfId = media.rows[0].cloudflare_image_id ?? body.cloudflareImageId;
      const imagesHash = session.images_hash!;
      const url = media.rows[0].url;
      return {
        mediaId: media.rows[0].id,
        url,
        variants: {
          public: url,
          thumbnail: this.cf.imageDeliveryUrl(imagesHash, cfId, "thumbnail"),
          gallery: this.cf.imageDeliveryUrl(imagesHash, cfId, "gallery"),
          cover: this.cf.imageDeliveryUrl(imagesHash, cfId, "cover"),
        },
      };
    }

    // Phase 2: Cloudflare outside any DB transaction
    const cfId = session.cloudflare_image_id!;
    const imagesHash = session.images_hash!;
    const cfStatus = await this.cf.getImageStatus(cfId);
    if (!cfStatus.exists || !cfStatus.ready || cfStatus.draft) {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        "cloudflareImageId not ready with Cloudflare",
      );
    }
    const url = this.cf.imageDeliveryUrl(imagesHash, cfId, "public");
    const variants = {
      public: url,
      thumbnail: this.cf.imageDeliveryUrl(imagesHash, cfId, "thumbnail"),
      gallery: this.cf.imageDeliveryUrl(imagesHash, cfId, "gallery"),
      cover: this.cf.imageDeliveryUrl(imagesHash, cfId, "cover"),
    };

    // Phase 3: persist (DB only)
    return this.pg.tx(async (c) => {
      const claim = await c.query<{ id: string }>(
        `UPDATE media_upload_sessions
         SET status = 'completed'
         WHERE id = $1 AND status = 'pending'
         RETURNING id`,
        [session.id],
      );
      if (!claim.rowCount) {
        // Concurrent complete — replay
        const again = await c.query<{ completed_media_id: string | null }>(
          `SELECT completed_media_id FROM media_upload_sessions WHERE id = $1`,
          [session.id],
        );
        if (again.rows[0]?.completed_media_id) {
          const m = await c.query<{ id: string; url: string }>(
            `SELECT id, url FROM venue_media WHERE id = $1`,
            [again.rows[0].completed_media_id],
          );
          if (m.rowCount) {
            return { mediaId: m.rows[0].id, url: m.rows[0].url, variants };
          }
        }
        throw new AppError(ErrorCodes.DUPLICATE_REQUEST, "Upload session already completed");
      }
      const invType = session.inventory_type_id ?? undefined;
      await c.query(`SELECT places_lock_media_write_scope($1::uuid, $2::uuid)`, [
        session.venue_id,
        invType ?? null,
      ]);
      if (body.isCover) {
        if (invType) {
          await c.query(
            `UPDATE venue_media SET is_cover = FALSE
             WHERE inventory_type_id = $1 AND kind = 'image'
               AND moderation_status = 'pending' AND deleted_at IS NULL`,
            [invType],
          );
        } else {
          await c.query(
            `UPDATE venue_media SET is_cover = FALSE
             WHERE venue_id = $1 AND inventory_type_id IS NULL AND kind = 'image'
               AND moderation_status = 'pending' AND deleted_at IS NULL`,
            [session.venue_id],
          );
        }
      }
      const mediaId = newId();
      await c.query(
        `INSERT INTO venue_media (
           id, venue_id, inventory_type_id, provider_id, kind, url, cloudflare_image_id,
           purpose, moderation_status, sort_order, is_cover
         ) VALUES ($1,$2,$3,$4,'image',$5,$6,$7,'pending',$8,$9)`,
        [
          mediaId,
          session.venue_id,
          invType ?? null,
          session.provider_id,
          url,
          cfId,
          body.purpose ?? "gallery",
          body.sortOrder ?? 0,
          body.isCover ?? false,
        ],
      );
      await c.query(
        `UPDATE media_upload_sessions
         SET cloudflare_image_id = $2, completed_media_id = $3
         WHERE id = $1`,
        [session.id, cfId, mediaId],
      );
      await this.audit.write(
        {
          actorUid: typeof actor === "string" ? actor : actor.uid,
          actorRole: "provider",
          entityType: "media",
          entityId: mediaId,
          after: { cloudflareImageId: cfId, url },
          correlationId,
        },
        c,
      );
      return { mediaId, url, variants };
    });
  }

  /**
   * @deprecated Gone — use createImageUploadSession + completeImageUpload.
   */
  async registerImageMedia(
    _actor: string | AuthUser,
    _body: {
      venueId: string;
      url: string;
      cloudflareImageId: string;
      inventoryTypeId?: string;
      sortOrder?: number;
      isCover?: boolean;
      purpose?: string;
    },
    _correlationId: string,
  ): Promise<{ mediaId: string }> {
    throw new AppError(ErrorCodes.VALIDATION_ERROR, "use upload-session");
  }

  /**
   * Expire pending sessions and enqueue CF orphan cleanup (DB-first).
   * Prefer admin; provider-scoped when providerId supplied (tenancy checked by caller).
   */
  async cleanupOrphanUploads(
    providerId?: string | null,
    limit = 50,
  ): Promise<{ cleaned: number }> {
    const stale = providerId
      ? await this.pg.query<{ id: string }>(
          `SELECT id FROM media_upload_sessions
           WHERE status = 'pending' AND expires_at < now() AND provider_id = $2
           ORDER BY expires_at ASC LIMIT $1`,
          [limit, providerId],
        )
      : await this.pg.query<{ id: string }>(
          `SELECT id FROM media_upload_sessions
           WHERE status = 'pending' AND expires_at < now()
           ORDER BY expires_at ASC LIMIT $1`,
          [limit],
        );
    let cleaned = 0;
    for (const { id } of stale.rows) {
      try {
        const did = await this.pg.tx(async (c) => {
          const locked = await c.query<{
            id: string;
            cloudflare_image_id: string | null;
            stream_uid: string | null;
            kind: string;
            status: string;
          }>(
            `SELECT id, cloudflare_image_id, stream_uid, kind, status
             FROM media_upload_sessions WHERE id = $1 FOR UPDATE`,
            [id],
          );
          if (!locked.rowCount) {
            return false;
          }
          const row = locked.rows[0];
          const upd = await c.query(
            `UPDATE media_upload_sessions SET status = 'orphaned_cleaned'
             WHERE id = $1 AND status = 'pending' AND expires_at < now()`,
            [row.id],
          );
          if (!upd.rowCount) {
            return false;
          }
          // Never enqueue CF delete for ids still referenced by completed non-deleted media.
          let stillLive = false;
          if (row.cloudflare_image_id) {
            const live = await c.query(
              `SELECT 1 FROM venue_media
               WHERE cloudflare_image_id = $1 AND deleted_at IS NULL LIMIT 1`,
              [row.cloudflare_image_id],
            );
            stillLive = !!live.rowCount;
          }
          if (!stillLive && row.stream_uid) {
            const live = await c.query(
              `SELECT 1 FROM venue_media
               WHERE stream_uid = $1 AND deleted_at IS NULL LIMIT 1`,
              [row.stream_uid],
            );
            stillLive = !!live.rowCount;
          }
          if (!stillLive && (row.cloudflare_image_id || row.stream_uid)) {
            await c.query(
              `INSERT INTO media_cf_delete_outbox
                 (id, kind, cloudflare_image_id, stream_uid, status, next_attempt_at)
               VALUES ($1,$2,$3,$4,'pending', now())`,
              [
                newId(),
                row.kind === "video" ? "video" : "image",
                row.cloudflare_image_id,
                row.stream_uid,
              ],
            );
          }
          return true;
        });
        if (did) cleaned += 1;
      } catch {
        await this.pg.query(
          `UPDATE media_upload_sessions SET status = 'expired'
           WHERE id = $1 AND status = 'pending'`,
          [id],
        );
      }
    }
    return { cleaned };
  }

  async reorderMedia(
    actor: string | AuthUser,
    body: {
      venueId: string;
      inventoryTypeId?: string;
      orderedMediaIds: string[];
      expectedCasVersions: number[];
    },
    correlationId: string,
  ): Promise<{ ok: true }> {
    if (body.orderedMediaIds.length > 30) {
      throw new AppError(ErrorCodes.VALIDATION_ERROR, "Max 30 media items");
    }
    const v = await this.pg.query<{ provider_id: string }>(
      "SELECT provider_id FROM venues WHERE id = $1",
      [body.venueId],
    );
    if (!v.rowCount) {
      throw new AppError(ErrorCodes.NOT_FOUND, "Venue not found");
    }
    await this.tenancy.require(actor, v.rows[0].provider_id, "media.upload");
    await this.pg.tx(async (c) => {
      await c.query(
        `SELECT places_lock_media_write_scope($1::uuid, $2::uuid)`,
        [body.venueId, body.inventoryTypeId ?? null],
      );
      if (
        !Array.isArray(body.expectedCasVersions) ||
        body.expectedCasVersions.length !== body.orderedMediaIds.length
      ) {
        throw new AppError(
          ErrorCodes.VALIDATION_ERROR,
          "expectedCasVersions length must match orderedMediaIds",
        );
      }
      let i = 0;
      for (const mediaId of body.orderedMediaIds) {
        const expected = body.expectedCasVersions[i];
        // Locked re-read: refuse deleted/rejected; only approved images reorder.
        const locked = await c.query<{
          moderation_status: string;
          deleted_at: Date | null;
        }>(
          `SELECT moderation_status, deleted_at FROM venue_media
           WHERE id = $1 AND venue_id = $2 AND provider_id = $3
             AND kind = 'image'
             AND ($4::uuid IS NULL AND inventory_type_id IS NULL
                  OR inventory_type_id = $4)
           FOR UPDATE`,
          [
            mediaId,
            body.venueId,
            v.rows[0].provider_id,
            body.inventoryTypeId ?? null,
          ],
        );
        if (!locked.rowCount || locked.rows[0].deleted_at) {
          throw new AppError(ErrorCodes.NOT_FOUND, "Media not found");
        }
        if (
          locked.rows[0].moderation_status === "rejected" ||
          locked.rows[0].moderation_status !== "approved"
        ) {
          throw new AppError(
            ErrorCodes.VALIDATION_ERROR,
            "Cannot reorder deleted/rejected/non-approved media",
          );
        }
        const upd = await c.query(
          `UPDATE venue_media SET sort_order = $3, cas_version = cas_version + 1
           WHERE id = $1 AND venue_id = $2 AND provider_id = $4
             AND kind = 'image' AND cas_version = $6
             AND deleted_at IS NULL AND moderation_status = 'approved'
             AND ($5::uuid IS NULL AND inventory_type_id IS NULL
                  OR inventory_type_id = $5)`,
          [
            mediaId,
            body.venueId,
            i,
            v.rows[0].provider_id,
            body.inventoryTypeId ?? null,
            expected,
          ],
        );
        i += 1;
        if (!upd.rowCount) {
          throw new AppError(
            ErrorCodes.DUPLICATE_REQUEST,
            "Media reorder CAS conflict",
          );
        }
      }
      await this.audit.write(
        {
          actorUid: typeof actor === "string" ? actor : actor.uid,
          actorRole: "provider",
          entityType: "media",
          entityId: body.venueId,
          after: body,
          correlationId,
        },
        c,
      );
    });
    return { ok: true };
  }

  async setMediaCover(
    actor: string | AuthUser,
    mediaId: string,
    correlationId: string,
    expectedCasVersion: number,
  ): Promise<{ ok: true; casVersion: number }> {
    const m = await this.pg.query<{
      venue_id: string;
      provider_id: string;
      inventory_type_id: string | null;
      kind: string;
      moderation_status: string;
      deleted_at: Date | null;
    }>(
      `SELECT venue_id, provider_id, inventory_type_id, kind, moderation_status, deleted_at
       FROM venue_media WHERE id = $1`,
      [mediaId],
    );
    if (!m.rowCount || m.rows[0].kind !== "image" || m.rows[0].deleted_at) {
      throw new AppError(ErrorCodes.NOT_FOUND, "Image media not found");
    }
    if (
      m.rows[0].moderation_status === "rejected" ||
      m.rows[0].moderation_status !== "approved"
    ) {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        "Only approved images can be cover",
      );
    }
    await this.tenancy.require(actor, m.rows[0].provider_id, "media.upload");
    await this.pg.tx(async (c) => {
      await c.query(
        `SELECT places_lock_media_write_scope($1::uuid, $2::uuid)`,
        [m.rows[0].venue_id, m.rows[0].inventory_type_id],
      );
      // CAS / locked re-read inside TX — refuse deleted/rejected.
      const fresh = await c.query<{
        moderation_status: string;
        deleted_at: Date | null;
        kind: string;
      }>(
        `SELECT moderation_status, deleted_at, kind FROM venue_media
         WHERE id = $1 FOR UPDATE`,
        [mediaId],
      );
      if (
        !fresh.rowCount ||
        fresh.rows[0].deleted_at ||
        fresh.rows[0].kind !== "image"
      ) {
        throw new AppError(ErrorCodes.NOT_FOUND, "Image media not found");
      }
      if (
        fresh.rows[0].moderation_status === "rejected" ||
        fresh.rows[0].moderation_status !== "approved"
      ) {
        throw new AppError(
          ErrorCodes.VALIDATION_ERROR,
          "Only approved images can be cover",
        );
      }
      // Clear other approved covers only.
      if (m.rows[0].inventory_type_id) {
        await c.query(
          `UPDATE venue_media SET is_cover = FALSE
           WHERE inventory_type_id = $1 AND kind = 'image'
             AND moderation_status = 'approved' AND deleted_at IS NULL AND id <> $2`,
          [m.rows[0].inventory_type_id, mediaId],
        );
      } else {
        await c.query(
          `UPDATE venue_media SET is_cover = FALSE
           WHERE venue_id = $1 AND inventory_type_id IS NULL AND kind = 'image'
             AND moderation_status = 'approved' AND deleted_at IS NULL AND id <> $2`,
          [m.rows[0].venue_id, mediaId],
        );
      }
      const cas = await c.query(
        `UPDATE venue_media SET is_cover = TRUE, cas_version = cas_version + 1
         WHERE id = $1 AND cas_version = $2 AND deleted_at IS NULL
           AND moderation_status = 'approved'`,
        [mediaId, expectedCasVersion],
      );
      if (cas.rowCount !== 1) {
        throw new AppError(
          ErrorCodes.DUPLICATE_REQUEST,
          "Media cover CAS conflict",
        );
      }
      await this.audit.write(
        {
          actorUid: typeof actor === "string" ? actor : actor.uid,
          actorRole: "provider",
          entityType: "media",
          entityId: mediaId,
          after: { isCover: true, casVersion: expectedCasVersion + 1 },
          correlationId,
        },
        c,
      );
    });
    return { ok: true, casVersion: expectedCasVersion + 1 };
  }

  async deleteMedia(
    actor: string | AuthUser,
    mediaId: string,
    correlationId: string,
    expectedCasVersion: number,
  ): Promise<{ ok: true; casVersion: number }> {
    const m = await this.pg.query<{
      venue_id: string;
      provider_id: string;
      inventory_type_id: string | null;
      cloudflare_image_id: string | null;
      stream_uid: string | null;
      kind: string;
      deleted_at: Date | null;
      moderation_status: string;
    }>(
      `SELECT venue_id, provider_id, inventory_type_id, cloudflare_image_id, stream_uid, kind,
              deleted_at, moderation_status
       FROM venue_media WHERE id = $1`,
      [mediaId],
    );
    if (!m.rowCount || m.rows[0].deleted_at) {
      throw new AppError(ErrorCodes.NOT_FOUND, "Media not found");
    }
    if (m.rows[0].moderation_status === "rejected") {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        "Cannot delete rejected media",
      );
    }
    await this.tenancy.require(actor, m.rows[0].provider_id, "media.upload");
    await this.pg.tx(async (c) => {
      await c.query(`SELECT places_lock_media_write_scope($1::uuid, $2::uuid)`, [
        m.rows[0].venue_id,
        m.rows[0].inventory_type_id,
      ]);
      const fresh = await c.query<{
        kind: string;
        inventory_type_id: string | null;
        moderation_status: string;
        deleted_at: Date | null;
        cloudflare_image_id: string | null;
        stream_uid: string | null;
      }>(
        `SELECT kind, inventory_type_id, moderation_status, deleted_at,
                cloudflare_image_id, stream_uid
         FROM venue_media WHERE id = $1 FOR UPDATE`,
        [mediaId],
      );
      if (!fresh.rowCount || fresh.rows[0].deleted_at) {
        throw new AppError(ErrorCodes.NOT_FOUND, "Media not found");
      }
      if (fresh.rows[0].moderation_status === "rejected") {
        throw new AppError(
          ErrorCodes.VALIDATION_ERROR,
          "Cannot delete rejected media",
        );
      }
      const venue = await c.query<{ status: string }>(
        `SELECT status FROM venues WHERE id = $1 FOR NO KEY UPDATE`,
        [m.rows[0].venue_id],
      );
      // Forbid deleting the last approved venue-level image while published.
      if (
        venue.rows[0]?.status === "published" &&
        fresh.rows[0].kind === "image" &&
        fresh.rows[0].inventory_type_id == null &&
        fresh.rows[0].moderation_status === "approved"
      ) {
        const other = await c.query(
          `SELECT 1 FROM venue_media
           WHERE venue_id = $1 AND inventory_type_id IS NULL AND kind = 'image'
             AND moderation_status = 'approved' AND deleted_at IS NULL AND id <> $2
           LIMIT 1`,
          [m.rows[0].venue_id, mediaId],
        );
        if (!other.rowCount) {
          throw new AppError(
            ErrorCodes.VALIDATION_ERROR,
            "Cannot delete last approved venue image while venue is published",
          );
        }
      }
      const soft = await c.query(
        `UPDATE venue_media SET deleted_at = now(), is_cover = FALSE,
               cas_version = cas_version + 1
         WHERE id = $1 AND provider_id = $2 AND deleted_at IS NULL
           AND moderation_status <> 'rejected'
           AND cas_version = $3`,
        [mediaId, m.rows[0].provider_id, expectedCasVersion],
      );
      if (!soft.rowCount) {
        throw new AppError(
          ErrorCodes.DUPLICATE_REQUEST,
          "Media delete CAS conflict",
        );
      }
      await c.query(
        `INSERT INTO media_cf_delete_outbox
           (id, kind, cloudflare_image_id, stream_uid, venue_media_id, status, next_attempt_at)
         VALUES ($1,$2,$3,$4,$5,'pending', now())`,
        [
          newId(),
          fresh.rows[0].kind === "video" ? "video" : "image",
          fresh.rows[0].cloudflare_image_id,
          fresh.rows[0].stream_uid,
          mediaId,
        ],
      );
      await this.audit.write(
        {
          actorUid: typeof actor === "string" ? actor : actor.uid,
          actorRole: "provider",
          entityType: "media",
          entityId: mediaId,
          after: { deleted: true, softDelete: true },
          correlationId,
        },
        c,
      );
    });
    return { ok: true, casVersion: expectedCasVersion + 1 };
  }

  async team(actor: string | AuthUser, providerId: string): Promise<unknown[]> {
    await this.tenancy.require(actor, providerId, "bookings.view");
    const res = await this.pg.query(
      `SELECT firebase_uid, role, status FROM provider_users WHERE provider_id = $1`,
      [providerId],
    );
    return res.rows;
  }

  async finance(actor: string | AuthUser, providerId: string): Promise<unknown> {
    await this.tenancy.require(actor, providerId, "finance.view");
    const rec = await this.pg.query(
      `SELECT status, sum(amount)::text AS amount FROM provider_receivables WHERE provider_id = $1 GROUP BY status`,
      [providerId],
    );
    return { receivables: rec.rows };
  }

  async calendar(
    actor: string | AuthUser,
    providerId: string,
    from: string,
    to: string,
  ): Promise<unknown[]> {
    await this.tenancy.require(actor, providerId, "bookings.view");
    const res = await this.pg.query(
      `SELECT d.inventory_type_id, d.date, d.capacity, d.held, d.booked, d.blocked, d.available
       FROM inventory_daily_capacity d
       JOIN inventory_types t ON t.id = d.inventory_type_id
       JOIN venues v ON v.id = t.venue_id
       WHERE v.provider_id = $1 AND d.date BETWEEN $2::date AND $3::date
       ORDER BY d.date`,
      [providerId, from, to],
    );
    return res.rows;
  }
}
