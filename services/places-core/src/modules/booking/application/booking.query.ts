import { Injectable } from "@nestjs/common";
import { PgService } from "../../../shared/database/pg.service";
import { AppError } from "../../../shared/errors/app-error";
import { ErrorCodes } from "../../../shared/errors/error-codes";
import { mapConsumerBookingDocument } from "./consumer-booking-document";
import { readGuestSnapshot } from "./guest-snapshot";
import {
  isPdfBuffer,
  renderBookingDocumentPdf,
} from "./booking-document-pdf";

/**
 * Consumer-safe booking projection (F-V2-003 / F-REV3-06).
 * Never select/map commission_*, provider_net, provider_id, ledger, or hold/quote ids.
 */
const CONSUMER_BOOKING_SELECT = `
  b.id,
  b.human_code,
  b.status,
  b.check_in,
  b.check_out,
  b.gross_total,
  b.currency,
  b.payment_method,
  b.payment_status,
  b.venue_id,
  b.inventory_type_id,
  b.quantity,
  b.slot_code,
  b.confirmed_at,
  b.cancelled_at,
  b.created_at,
  b.updated_at,
  b.cancellation_policy_snapshot_json,
  v.name AS venue_name,
  v.lat AS venue_lat,
  v.lng AS venue_lng,
  it.name AS inventory_type_name,
  it.label_ar AS inventory_type_label_ar,
  iu.label AS inventory_unit_label,
  q.guests_adults,
  q.guests_children,
  b.guest_snapshot_json,
  cover.cover_url AS cover_url,
  (r.id IS NOT NULL) AS has_review
`;

const CONSUMER_BOOKING_FROM = `
  FROM bookings b
  JOIN venues v ON v.id = b.venue_id
  JOIN inventory_types it ON it.id = b.inventory_type_id
  LEFT JOIN inventory_units iu ON iu.id = b.inventory_unit_id
  LEFT JOIN quotes q ON q.id = b.quote_id
  LEFT JOIN LATERAL (
    SELECT COALESCE(m.cover_url, m.url) AS cover_url
    FROM venue_media m
    WHERE m.venue_id = b.venue_id
      AND m.kind = 'image'
      AND m.moderation_status = 'approved'
      AND m.deleted_at IS NULL
      AND (m.inventory_type_id = b.inventory_type_id OR m.inventory_type_id IS NULL)
    ORDER BY (m.inventory_type_id IS NOT NULL) DESC,
             m.is_cover DESC,
             m.sort_order ASC,
             m.id ASC
    LIMIT 1
  ) cover ON TRUE
  LEFT JOIN reviews r ON r.booking_id = b.id
`;

export type ConsumerBookingProjection = Record<string, unknown>;

/** Exported for contract unit tests (Core ⇄ Flutter field names). */
export function mapConsumerBookingRow(
  row: Record<string, unknown>,
): ConsumerBookingProjection {
  const gross = row.gross_total;
  const paymentMethod = String(row.payment_method ?? "");
  const paymentStatus = String(row.payment_status ?? "");
  const dueAtVenue =
    paymentMethod === "PAY_AT_VENUE" && paymentStatus === "DUE_AT_VENUE"
      ? gross
      : null;

  const adults =
    row.guests_adults == null ? null : Number(row.guests_adults);
  const children =
    row.guests_children == null ? null : Number(row.guests_children);
  const guests =
    adults == null && children == null
      ? null
      : {
          adults: adults ?? 0,
          children: children ?? 0,
        };

  const policyRaw = row.cancellation_policy_snapshot_json;
  const policyText = consumerPolicyText(policyRaw);
  const lat = row.venue_lat == null ? null : Number(row.venue_lat);
  const lng = row.venue_lng == null ? null : Number(row.venue_lng);
  const hasReview = row.has_review === true || row.has_review === "t";
  const guestSnapshot = readGuestSnapshot(row.guest_snapshot_json);

  // Dual snake_case + camelCase for Flutter Booking / BookingDetails parsers.
  return {
    id: row.id,
    bookingId: row.id,
    human_code: row.human_code,
    humanCode: row.human_code,
    status: row.status,
    check_in: row.check_in,
    checkIn: row.check_in,
    check_out: row.check_out,
    checkOut: row.check_out,
    gross_total: gross,
    grossTotal: gross,
    currency: row.currency,
    payment_method: row.payment_method,
    paymentMethod: row.payment_method,
    payment_status: row.payment_status,
    paymentStatus: row.payment_status,
    venue_id: row.venue_id,
    venueId: row.venue_id,
    venue_name: row.venue_name,
    venueName: row.venue_name,
    cover_url: row.cover_url ?? null,
    coverUrl: row.cover_url ?? null,
    inventory_type_id: row.inventory_type_id,
    inventoryTypeId: row.inventory_type_id,
    inventory_type_name: row.inventory_type_label_ar || row.inventory_type_name,
    inventoryTypeName: row.inventory_type_label_ar || row.inventory_type_name,
    inventory_unit_label: row.inventory_unit_label ?? null,
    inventoryUnitLabel: row.inventory_unit_label ?? null,
    quantity: row.quantity,
    slot_code: row.slot_code,
    slotCode: row.slot_code,
    confirmed_at: row.confirmed_at,
    confirmedAt: row.confirmed_at,
    cancelled_at: row.cancelled_at,
    cancelledAt: row.cancelled_at,
    created_at: row.created_at,
    createdAt: row.created_at,
    updated_at: row.updated_at,
    updatedAt: row.updated_at,
    due_at_venue_amount: dueAtVenue,
    dueAtVenueAmount: dueAtVenue,
    guests,
    cancellation_policy_snapshot_json: policyRaw ?? null,
    cancellation_policy_snapshot: policyText,
    cancellationPolicySnapshot: policyText,
    lat: Number.isFinite(lat as number) ? lat : null,
    lng: Number.isFinite(lng as number) ? lng : null,
    latitude: Number.isFinite(lat as number) ? lat : null,
    longitude: Number.isFinite(lng as number) ? lng : null,
    has_review: hasReview,
    hasReview,
    guest_snapshot: guestSnapshot,
    guestSnapshot,
    document: mapConsumerBookingDocument({
      status: row.status,
      payment_status: row.payment_status,
      payment_method: row.payment_method,
      human_code: row.human_code,
      gross_total: row.gross_total,
      currency: row.currency,
      venue_name: row.venue_name,
      inventory_type_name: row.inventory_type_name,
      inventory_type_label_ar: row.inventory_type_label_ar,
      inventory_unit_label: row.inventory_unit_label,
      check_in: row.check_in,
      check_out: row.check_out,
      guests_adults: row.guests_adults,
      guests_children: row.guests_children,
      cancellation_policy_snapshot_json: row.cancellation_policy_snapshot_json,
      guest_snapshot_json: row.guest_snapshot_json,
    }),
  };
}

function consumerPolicyText(raw: unknown): string | null {
  if (raw == null) return null;
  let obj: Record<string, unknown> | null = null;
  if (typeof raw === "string") {
    try {
      const parsed = JSON.parse(raw) as unknown;
      if (parsed && typeof parsed === "object") {
        obj = parsed as Record<string, unknown>;
      } else {
        return raw;
      }
    } catch {
      return raw;
    }
  } else if (typeof raw === "object") {
    obj = raw as Record<string, unknown>;
  }
  if (!obj) return null;
  if (typeof obj.summary === "string" && obj.summary.trim()) return obj.summary;
  if (typeof obj.text === "string" && obj.text.trim()) return obj.text;
  const hours = obj.free_until_hours_before_checkin;
  const feeBps = obj.fee_bps_after;
  if (typeof hours === "number") {
    if (typeof feeBps === "number") {
      return `إلغاء مجاني حتى ${hours} ساعة قبل الوصول؛ بعدها رسم ${feeBps / 100}%`;
    }
    return `إلغاء مجاني حتى ${hours} ساعة قبل الوصول`;
  }
  return null;
}

@Injectable()
export class BookingQuery {
  constructor(private readonly pg: PgService) {}

  async listForConsumer(uid: string): Promise<unknown[]> {
    const res = await this.pg.query(
      `SELECT ${CONSUMER_BOOKING_SELECT}
       ${CONSUMER_BOOKING_FROM}
       WHERE b.consumer_firebase_uid = $1
       ORDER BY b.created_at DESC`,
      [uid],
    );
    return res.rows.map((row) =>
      mapConsumerBookingRow(row as Record<string, unknown>),
    );
  }

  async getForConsumer(uid: string, id: string): Promise<unknown> {
    const res = await this.pg.query(
      `SELECT ${CONSUMER_BOOKING_SELECT}
       ${CONSUMER_BOOKING_FROM}
       WHERE b.id = $1 AND b.consumer_firebase_uid = $2`,
      [id, uid],
    );
    if (!res.rowCount) {
      throw new AppError(ErrorCodes.NOT_FOUND, "Booking not found");
    }
    return mapConsumerBookingRow(res.rows[0] as Record<string, unknown>);
  }

  async pdfForConsumer(
    uid: string,
    id: string,
  ): Promise<{ bytes: Buffer; fileName: string }> {
    const owner = await this.pg.query<{
      consumer_firebase_uid: string;
    }>(`SELECT consumer_firebase_uid FROM bookings WHERE id = $1`, [id]);
    if (!owner.rowCount) {
      throw new AppError(ErrorCodes.NOT_FOUND, "Booking not found");
    }
    if (owner.rows[0].consumer_firebase_uid !== uid) {
      throw new AppError(
        ErrorCodes.FORBIDDEN_BOOKING_OWNERSHIP,
        "Booking document belongs to another user",
      );
    }
    const res = await this.pg.query(
      `SELECT ${CONSUMER_BOOKING_SELECT}
       ${CONSUMER_BOOKING_FROM}
       WHERE b.id = $1`,
      [id],
    );
    if (!res.rowCount) {
      throw new AppError(ErrorCodes.NOT_FOUND, "Booking not found");
    }
    const row = res.rows[0] as Record<string, unknown>;
    const mapped = mapConsumerBookingRow(row);
    const document = mapped.document as { downloadFileName?: string };
    const bytes = await renderBookingDocumentPdf({
      status: row.status,
      payment_status: row.payment_status,
      payment_method: row.payment_method,
      human_code: row.human_code,
      gross_total: row.gross_total,
      currency: row.currency,
      venue_name: row.venue_name,
      inventory_type_name: row.inventory_type_name,
      inventory_type_label_ar: row.inventory_type_label_ar,
      inventory_unit_label: row.inventory_unit_label,
      check_in: row.check_in,
      check_out: row.check_out,
      guests_adults: row.guests_adults,
      guests_children: row.guests_children,
      cancellation_policy_snapshot_json: row.cancellation_policy_snapshot_json,
      guest_snapshot_json: row.guest_snapshot_json,
    });
    if (!isPdfBuffer(bytes)) {
      throw new AppError(ErrorCodes.INTERNAL, "PDF render failed");
    }
    return {
      bytes,
      fileName: document.downloadFileName || "booking.pdf",
    };
  }

  async listForProvider(providerId: string): Promise<unknown[]> {
    const res = await this.pg.query(
      `SELECT id, human_code, status, check_in, check_out, gross_total, currency,
              payment_method, payment_status, venue_id, consumer_firebase_uid,
              confirmed_at, cancelled_at, created_at
       FROM bookings WHERE provider_id = $1 ORDER BY created_at DESC`,
      [providerId],
    );
    return res.rows;
  }

  async getForProvider(providerId: string, id: string): Promise<unknown> {
    const res = await this.pg.query(
      `SELECT id, human_code, status, check_in, check_out, gross_total, currency,
              payment_method, payment_status, venue_id, inventory_type_id, quantity,
              consumer_firebase_uid, hold_id, quote_id, slot_code,
              confirmed_at, cancelled_at, created_at, updated_at
       FROM bookings WHERE id = $1 AND provider_id = $2`,
      [id, providerId],
    );
    if (!res.rowCount) {
      throw new AppError(ErrorCodes.NOT_FOUND, "Booking not found");
    }
    return res.rows[0];
  }
}
