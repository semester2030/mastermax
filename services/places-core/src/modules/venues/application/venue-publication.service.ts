import { Injectable } from "@nestjs/common";
import { AppError } from "../../../shared/errors/app-error";
import { ErrorCodes } from "../../../shared/errors/error-codes";
import { PgService } from "../../../shared/database/pg.service";
import { AuditService } from "../../audit/application/audit.service";
import { VenueTypeCapabilityPolicy } from "../../filters/application/venue-type-capability.policy";

export type PublishActorRole = "admin" | "provider" | "operator";

/**
 * Single shared publish path (Phase 5 / F-V2-011 + Phase 8B location/media).
 * Controllers stay thin — all publish invariants live here.
 */
@Injectable()
export class VenuePublicationService {
  constructor(
    private readonly pg: PgService,
    private readonly audit: AuditService,
    private readonly caps: VenueTypeCapabilityPolicy,
  ) {}

  /**
   * Publish a venue. Phase 8B: city+district+street, approved venue video,
   * cover image, price+availability, and each active unit type needs
   * approved video + image.
   */
  async publishVenue(input: {
    venueId: string;
    actorUid: string;
    actorRole: PublishActorRole;
    correlationId: string;
    name?: string | null;
    city?: string | null;
  }): Promise<{ ok: true; status: "published" }> {
    const v = await this.pg.query<{
      id: string;
      status: string;
      provider_id: string;
      venue_type: string;
      booking_mode: string;
      city_id: string | null;
      district_id: string | null;
      street: string | null;
    }>(
      `SELECT id, status, provider_id, venue_type, booking_mode,
              city_id, district_id, street
       FROM venues WHERE id = $1`,
      [input.venueId],
    );
    if (!v.rowCount) {
      throw new AppError(ErrorCodes.NOT_FOUND, "Venue not found");
    }
    const venue = v.rows[0];
    await this.caps.requireProviderEnabled(venue.venue_type);
    this.caps.requireEventSlotPathAllowed(venue.booking_mode);

    if (!venue.city_id || !venue.district_id || !venue.street?.trim()) {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        "Publish requires cityId, districtId, and street",
      );
    }

    await this.pg.tx(async (c) => {
      await c.query(`SELECT places_lock_media_write_scope($1::uuid, NULL)`, [
        input.venueId,
      ]);
      const approvedImage = await c.query(
        `SELECT 1 FROM venue_media
         WHERE venue_id = $1 AND inventory_type_id IS NULL AND kind = 'image'
           AND moderation_status = 'approved' AND deleted_at IS NULL
           AND is_cover = TRUE
         LIMIT 1`,
        [input.venueId],
      );
      if (!approvedImage.rowCount) {
        throw new AppError(
          ErrorCodes.VALIDATION_ERROR,
          "Publish requires an approved venue-level cover image",
        );
      }
      const approvedVideo = await c.query(
        `SELECT 1 FROM venue_media
         WHERE venue_id = $1 AND inventory_type_id IS NULL AND kind = 'video'
           AND moderation_status = 'approved' AND deleted_at IS NULL
         LIMIT 1`,
        [input.venueId],
      );
      if (!approvedVideo.rowCount) {
        throw new AppError(
          ErrorCodes.VALIDATION_ERROR,
          "Publish requires an approved venue-level hero video",
        );
      }
      const priced = await c.query(
        `SELECT 1
         FROM rate_plans rp
         JOIN inventory_types t ON t.id = rp.inventory_type_id
         JOIN rate_rules rr ON rr.rate_plan_id = rp.id
         WHERE t.venue_id = $1 AND t.status = 'active' AND rp.status = 'active'
         LIMIT 1`,
        [input.venueId],
      );
      if (!priced.rowCount) {
        throw new AppError(
          ErrorCodes.VALIDATION_ERROR,
          "Publish requires a price on an active unit type",
        );
      }
      const avail = await c.query(
        `SELECT 1
         FROM availability_overrides o
         JOIN inventory_types t ON t.id = o.inventory_type_id
         WHERE t.venue_id = $1 AND t.status = 'active'
         LIMIT 1`,
        [input.venueId],
      );
      const rules = avail.rowCount
        ? avail
        : await c.query(
            `SELECT 1
             FROM availability_rules ar
             JOIN inventory_types t ON t.id = ar.inventory_type_id
             WHERE t.venue_id = $1 AND t.status = 'active'
             LIMIT 1`,
            [input.venueId],
          );
      if (!rules.rowCount) {
        throw new AppError(
          ErrorCodes.VALIDATION_ERROR,
          "Publish requires availability on an active unit type",
        );
      }
      const units = await c.query<{ id: string }>(
        `SELECT id FROM inventory_types WHERE venue_id = $1 AND status = 'active'`,
        [input.venueId],
      );
      for (const u of units.rows) {
        const img = await c.query(
          `SELECT 1 FROM venue_media
           WHERE venue_id = $1 AND inventory_type_id = $2 AND kind = 'image'
             AND moderation_status = 'approved' AND deleted_at IS NULL
           LIMIT 1`,
          [input.venueId, u.id],
        );
        const vid = await c.query(
          `SELECT 1 FROM venue_media
           WHERE venue_id = $1 AND inventory_type_id = $2 AND kind = 'video'
             AND moderation_status = 'approved' AND deleted_at IS NULL
           LIMIT 1`,
          [input.venueId, u.id],
        );
        if (!img.rowCount || !vid.rowCount) {
          throw new AppError(
            ErrorCodes.VALIDATION_ERROR,
            "Publish requires approved video and image on each active unit type",
          );
        }
      }
      await c.query(
        `UPDATE venues SET
           name = COALESCE($2, name),
           city = COALESCE($3, city),
           status = 'published',
           updated_at = now()
         WHERE id = $1`,
        [input.venueId, input.name ?? null, input.city ?? null],
      );
      await this.audit.write(
        {
          actorUid: input.actorUid,
          actorRole: input.actorRole,
          entityType: "venue",
          entityId: input.venueId,
          before: { status: venue.status },
          after: { status: "published" },
          correlationId: input.correlationId,
          reason: "venue_publish_shared",
        },
        c,
      );
    });
    return { ok: true, status: "published" };
  }
}
