import { Injectable } from "@nestjs/common";
import { PgService } from "../../../shared/database/pg.service";
import { AppError } from "../../../shared/errors/app-error";
import { ErrorCodes } from "../../../shared/errors/error-codes";
import { isAllowedCloudflareDeliveryUrl } from "../../media/domain/cloudflare-hostname-allowlist";
import { FilterEngineService } from "../../filters/application/filter-engine.service";
import { VenueTypeCapabilityPolicy } from "../../filters/application/venue-type-capability.policy";

@Injectable()
export class CatalogService {
  constructor(
    private readonly pg: PgService,
    private readonly filters: FilterEngineService,
    private readonly caps: VenueTypeCapabilityPolicy,
  ) {}

  /** Legacy feed — delegates to shared discovery query/projection (Gate 7A.1). */
  async feed(query: {
    category?: string;
    cursor?: string;
    city?: string;
  }): Promise<{ items: unknown[]; nextCursor: string | null; total: number }> {
    return this.filters.feedAdapter(query);
  }

  private async requirePublishedDiscoverable(id: string): Promise<{
    id: string;
    name: string;
    venue_type: string;
    booking_mode: "nightly" | "daily" | "event_slot";
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
    lat: number | null;
    lng: number | null;
    description: string | null;
    status: string;
    rating_average: string | null;
    indicative_starting_price: string | null;
    attributes_jsonb: Record<string, unknown> | null;
    enabled_for_booking: boolean;
  }> {
    const v = await this.pg.query<{
      id: string;
      name: string;
      venue_type: string;
      booking_mode: "nightly" | "daily" | "event_slot";
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
      lat: number | null;
      lng: number | null;
      description: string | null;
      status: string;
      rating_average: string | null;
      indicative_starting_price: string | null;
      attributes_jsonb: Record<string, unknown> | null;
      enabled_for_booking: boolean;
    }>(
      `SELECT v.id, v.name, v.venue_type, v.booking_mode, v.city, v.district,
              v.city_id, v.district_id, v.street, v.building_no, v.landmark,
              v.access_notes, v.maps_url, v.location_source, v.lat, v.lng,
              v.description, v.status, v.rating_average::text, v.indicative_starting_price::text,
              v.attributes_jsonb, COALESCE(c.enabled_for_booking, FALSE) AS enabled_for_booking
       FROM venues v
       LEFT JOIN venue_type_capabilities c ON c.venue_type = v.venue_type
       WHERE v.id = $1`,
      [id],
    );
    if (!v.rowCount || v.rows[0].status !== "published") {
      throw new AppError(ErrorCodes.NOT_FOUND, "Venue not found");
    }
    try {
      await this.caps.requireDiscoveryEnabled(v.rows[0].venue_type);
    } catch {
      throw new AppError(ErrorCodes.NOT_FOUND, "Venue not found");
    }
    return v.rows[0];
  }

  async venue(id: string): Promise<Record<string, unknown>> {
    const row = await this.requirePublishedDiscoverable(id);
    const types = await this.pg.query(
      `SELECT id, name, label_ar, inventory_model, quantity_total, base_occupancy, max_occupancy,
              extra_guest_amount::text, sort_order, status
       FROM inventory_types WHERE venue_id = $1 AND status = 'active'
       ORDER BY sort_order ASC, name`,
      [id],
    );
    const media = await this.pg.query(
      `SELECT id, kind, stream_uid, url, cover_url, purpose, sort_order, is_cover,
              inventory_type_id, moderation_status, cloudflare_image_id
       FROM venue_media
       WHERE venue_id = $1 AND moderation_status = 'approved' AND deleted_at IS NULL
       ORDER BY is_cover DESC, sort_order ASC, id ASC
       LIMIT 60`,
      [id],
    );
    const amenities = await this.pg.query(
      `SELECT l.amenity_code AS code, l.state, l.value, l.scope,
              l.inventory_type_id, ac.label_ar, ac.label_en, ac.icon_key,
              ac.sort_order, ac.applicable_venue_types
       FROM venue_amenity_links l
       JOIN amenity_catalog ac ON ac.code = l.amenity_code
       WHERE l.venue_id = $1
       ORDER BY ac.sort_order, l.amenity_code`,
      [id],
    );
    const prices = await this.pg.query<{ id: string; starting: string }>(
      `SELECT t.id, MIN(rr.amount)::text AS starting
       FROM inventory_types t
       JOIN rate_plans rp ON rp.inventory_type_id = t.id AND rp.status = 'active'
       JOIN rate_rules rr ON rr.rate_plan_id = rp.id
       WHERE t.venue_id = $1 AND t.status = 'active'
       GROUP BY t.id`,
      [id],
    );
    const avail = await this.pg.query<{ id: string }>(
      `SELECT DISTINCT t.id
       FROM inventory_types t
       WHERE t.venue_id = $1 AND t.status = 'active'
         AND (
           EXISTS (SELECT 1 FROM availability_overrides o WHERE o.inventory_type_id = t.id)
           OR EXISTS (SELECT 1 FROM availability_rules ar WHERE ar.inventory_type_id = t.id)
         )`,
      [id],
    );
    const unitRows = await this.pg.query<{
      id: string;
      inventory_type_id: string;
      label: string;
      status: string;
    }>(
      `SELECT u.id, u.inventory_type_id, u.label, u.status
       FROM inventory_units u
       JOIN inventory_types t ON t.id = u.inventory_type_id
       WHERE t.venue_id = $1 AND u.status = 'active'
       ORDER BY u.label ASC, u.id ASC`,
      [id],
    );
    const unitsByType = new Map<string, Array<{ id: string; label: string }>>();
    for (const u of unitRows.rows) {
      const list = unitsByType.get(u.inventory_type_id) ?? [];
      list.push({ id: u.id, label: u.label });
      unitsByType.set(u.inventory_type_id, list);
    }
    const priceByType = new Map(prices.rows.map((p) => [p.id, p.starting]));
    const availIds = new Set(avail.rows.map((r) => r.id));
    const primaryImage = media.rows.find((m) => m.kind === "image") ?? null;
    const primaryVideo = media.rows.find((m) => m.kind === "video") ?? null;
    const attrs = row.attributes_jsonb ?? {};
    const eventSlotBlocked =
      row.booking_mode === "event_slot" &&
      process.env.PLACES_EVENT_SLOT_ENABLED !== "true";
    const bookingEnabled =
      row.enabled_for_booking === true && !eventSlotBlocked;
    return {
      id: row.id,
      name: row.name,
      venueType: row.venue_type,
      venue_type: row.venue_type,
      bookingMode: row.booking_mode,
      booking_mode: row.booking_mode,
      enabledForBooking: bookingEnabled,
      enabled_for_booking: bookingEnabled,
      bookingStatus: bookingEnabled ? "BOOKING_READY" : "BOOKING_NOT_READY",
      eventSlotDisabled: eventSlotBlocked,
      city: row.city,
      district: row.district,
      cityId: row.city_id,
      districtId: row.district_id,
      street: row.street,
      buildingNo: row.building_no,
      landmark: row.landmark,
      accessNotes: row.access_notes,
      mapsUrl: row.maps_url,
      locationSource: row.location_source,
      addressDetails: {
        buildingNo: row.building_no,
        landmark: row.landmark,
        accessNotes: row.access_notes,
      },
      formattedAddress: [
        row.street,
        row.building_no,
        row.district,
        row.city,
      ]
        .filter((p) => typeof p === "string" && p.trim())
        .join("، "),
      lat: row.lat,
      lng: row.lng,
      description: row.description,
      status: row.status,
      ratingAverage: row.rating_average,
      rating: row.rating_average,
      rating_average: row.rating_average,
      startingPriceHint: row.indicative_starting_price,
      starting_price_hint: row.indicative_starting_price,
      primaryMediaId: primaryImage?.id ?? primaryVideo?.id ?? null,
      hallType: attrs["hall_type"] ?? null,
      attributes: attrs,
      inventoryTypes: types.rows.map((t) => {
        const typeMedia = media.rows.filter((m) => m.inventory_type_id === t.id);
        const typeAmenities = amenities.rows.filter(
          (a) => a.inventory_type_id === t.id,
        );
        const images = typeMedia
          .filter((m) => m.kind === "image")
          .map((m) => ({
            id: m.id,
            url: m.url,
            coverUrl: m.cover_url,
            inventoryTypeId: m.inventory_type_id,
          }));
        const video = typeMedia.find((m) => m.kind === "video");
        return {
          id: t.id,
          name: (t.label_ar && String(t.label_ar).trim()) || t.name,
          code: t.name,
          labelAr: t.label_ar,
          label_ar: t.label_ar,
          inventoryModel: t.inventory_model,
          inventory_model: t.inventory_model,
          quantityTotal: t.quantity_total,
          quantity_total: t.quantity_total,
          baseOccupancy: t.base_occupancy,
          base_occupancy: t.base_occupancy,
          maxOccupancy: t.max_occupancy,
          max_occupancy: t.max_occupancy,
          extraGuestAmount: t.extra_guest_amount,
          extra_guest_amount: t.extra_guest_amount,
          sortOrder: t.sort_order,
          sort_order: t.sort_order,
          status: t.status,
          startingPriceHint: priceByType.get(t.id) ?? null,
          starting_price_hint: priceByType.get(t.id) ?? null,
          available: availIds.has(t.id),
          units: unitsByType.get(t.id) ?? [],
          videoUrl: video?.url ?? null,
          video_url: video?.url ?? null,
          images,
          media: typeMedia,
          amenities: typeAmenities.map((a) => ({
            id: a.code,
            code: a.code,
            state: a.state,
            scope: a.scope,
            inventoryTypeId: a.inventory_type_id,
            label_ar: a.label_ar,
            labelAr: a.label_ar,
            icon_key: a.icon_key,
            sort_order: a.sort_order,
            sortOrder: a.sort_order,
          })),
        };
      }),
      media: media.rows.map((m) => {
        const cfId = m.cloudflare_image_id as string | null;
        const delivery = typeof m.url === "string" ? m.url : null;
        const variants =
          cfId && delivery && isAllowedCloudflareDeliveryUrl(delivery)
            ? {
                public: delivery.replace(/\/[^/]+$/, "/public"),
                thumbnail: delivery.replace(/\/[^/]+$/, "/thumbnail"),
                gallery: delivery.replace(/\/[^/]+$/, "/gallery"),
                cover: delivery.replace(/\/[^/]+$/, "/cover"),
              }
            : null;
        return {
          id: m.id,
          kind: m.kind,
          streamUid: m.stream_uid,
          stream_uid: m.stream_uid,
          streamUrl: m.url,
          stream_url: m.url,
          url: m.url,
          coverUrl: m.cover_url,
          cover_url: m.cover_url,
          purpose: m.purpose,
          sortOrder: m.sort_order,
          isCover: m.is_cover,
          inventoryTypeId: m.inventory_type_id,
          cloudflareImageId: cfId,
          cloudflare_image_id: cfId,
          variants,
        };
      }),
      amenities: amenities.rows.map((a) => ({
        id: a.code,
        code: a.code,
        state: a.state,
        value: a.value,
        scope: a.scope,
        inventoryTypeId: a.inventory_type_id,
        label_ar: a.label_ar,
        labelAr: a.label_ar,
        label_en: a.label_en,
        icon_key: a.icon_key,
        sort_order: a.sort_order,
        sortOrder: a.sort_order,
        applicable_venue_types: a.applicable_venue_types,
        applicableVenueTypes: a.applicable_venue_types,
      })),
      policies: {
        checkInFrom: attrs["check_in_from"] ?? null,
        checkOutUntil: attrs["check_out_until"] ?? null,
        cancellationSummaryAr: attrs["cancellation_summary_ar"] ?? null,
      },
    };
  }

  /**
   * Approved images only — venue-level (inventory_type_id IS NULL) or scoped to type.
   * Cap 30; ordered by cover then sort_order.
   */
  async gallery(
    venueId: string,
    inventoryTypeId?: string,
  ): Promise<{ items: unknown[]; total: number }> {
    await this.requirePublishedDiscoverable(venueId);
    const rows = inventoryTypeId
      ? await this.pg.query(
          `SELECT id, url, cover_url, sort_order, is_cover, inventory_type_id,
                  cloudflare_image_id
           FROM venue_media
           WHERE venue_id = $1 AND inventory_type_id = $2
             AND kind = 'image' AND moderation_status = 'approved'
             AND deleted_at IS NULL
           ORDER BY is_cover DESC, sort_order ASC, id ASC
           LIMIT 30`,
          [venueId, inventoryTypeId],
        )
      : await this.pg.query(
          `SELECT id, url, cover_url, sort_order, is_cover, inventory_type_id,
                  cloudflare_image_id
           FROM venue_media
           WHERE venue_id = $1 AND inventory_type_id IS NULL
             AND kind = 'image' AND moderation_status = 'approved'
             AND deleted_at IS NULL
           ORDER BY is_cover DESC, sort_order ASC, id ASC
           LIMIT 30`,
          [venueId],
        );
    return {
      items: rows.rows.map((m) => {
        const cfId = m.cloudflare_image_id as string | null;
        const delivery = typeof m.url === "string" ? m.url : null;
        const variants =
          cfId && delivery && isAllowedCloudflareDeliveryUrl(delivery)
            ? {
                public: delivery.replace(/\/[^/]+$/, "/public"),
                thumbnail: delivery.replace(/\/[^/]+$/, "/thumbnail"),
                gallery: delivery.replace(/\/[^/]+$/, "/gallery"),
                cover: delivery.replace(/\/[^/]+$/, "/cover"),
              }
            : null;
        return {
          id: m.id,
          url: m.url,
          coverUrl: m.cover_url,
          sortOrder: m.sort_order,
          isCover: m.is_cover,
          inventoryTypeId: m.inventory_type_id,
          cloudflareImageId: cfId,
          variants,
        };
      }),
      total: rows.rowCount ?? 0,
    };
  }
}
