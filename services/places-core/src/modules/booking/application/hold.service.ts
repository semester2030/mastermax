import { Injectable } from "@nestjs/common";
import { Inject } from "@nestjs/common";
import { PoolClient } from "pg";
import { APP_CONFIG } from "../../../shared/config/app-config";
import { AppEnv } from "../../../shared/config/env";
import { PgService } from "../../../shared/database/pg.service";
import { AppError } from "../../../shared/errors/app-error";
import { ErrorCodes } from "../../../shared/errors/error-codes";
import { newId } from "../../../shared/ids/ids";
import { riyadhTodayIso, stayDates } from "../../../shared/time/stay-dates";
import { metrics } from "../../../shared/observability/metrics";
import { CapacityService } from "../../inventory/application/capacity.service";
import { AvailabilityService } from "../../availability/application/availability.service";
import { AuditService } from "../../audit/application/audit.service";
import { VenueTypeCapabilityPolicy } from "../../filters/application/venue-type-capability.policy";
import { BookingStateMachine } from "../domain/booking-state.machine";
import { BookingLockOrder } from "./booking-lock-order";
import { holdBarrierArrive } from "./hold-barrier";
import {
  ConsumerPaymentOptions,
  resolveConsumerPaymentOptions,
} from "./consumer-payment-options";
import {
  guestSnapshotJson,
  parseGuestSnapshot,
} from "./guest-snapshot";

@Injectable()
export class HoldService {
  constructor(
    private readonly pg: PgService,
    @Inject(APP_CONFIG) private readonly env: AppEnv,
    private readonly capacity: CapacityService,
    private readonly availability: AvailabilityService,
    private readonly sm: BookingStateMachine,
    private readonly audit: AuditService,
    private readonly caps: VenueTypeCapabilityPolicy,
  ) {}

  async create(
    input: {
      uid: string;
      quoteId: string;
      quantity: number;
      guestSnapshot: unknown;
      idempotencyKey: string;
      correlationId: string;
    },
    client?: PoolClient,
  ): Promise<{
    holdId: string;
    expiresAt: string;
    status: string;
    bookingId: string;
    slotCode: string | null;
    inventoryUnitId?: string | null;
    paymentOptions: ConsumerPaymentOptions;
  }> {
    const run = async (c: PoolClient) => {
      // F-V3-010 lock-order fix: acquire parent venue locks BEFORE any hold/quote
      // row lock, matching the canonical BookingLockOrder (1: non-locking id
      // lookup → 2: venue FOR UPDATE → 4: hold FOR UPDATE → quote → capacity).
      // The competing expiry path locks venue→hold in the same order, so
      // create-vs-expiry can no longer invert locks and deadlock.
      //
      // Step 1 — non-locking lookup to determine the venue id(s) to lock first.
      // Includes the incoming quote's venue AND (if a reused idempotency key
      // points at an existing hold) that hold's quote venue, so both parents are
      // locked in one deterministic id-ordered pass.
      const quotePeek = await c.query<{
        venue_id: string;
        inventory_type_id: string;
      }>(
        `SELECT venue_id, inventory_type_id FROM quotes WHERE id = $1`,
        [input.quoteId],
      );
      if (!quotePeek.rowCount) {
        throw new AppError(ErrorCodes.NOT_FOUND, "Quote not found");
      }
      const priorPeek = await c.query<{ venue_id: string | null }>(
        `SELECT q.venue_id
         FROM booking_holds h
         LEFT JOIN quotes q ON q.id = h.quote_id
         WHERE h.consumer_firebase_uid = $1 AND h.idempotency_key = $2`,
        [input.uid, input.idempotencyKey],
      );
      const venueIdsToLock = [quotePeek.rows[0].venue_id];
      if (priorPeek.rowCount && priorPeek.rows[0].venue_id) {
        venueIdsToLock.push(priorPeek.rows[0].venue_id);
      }

      // RC4: race barrier inside TX immediately before the first FOR UPDATE.
      await holdBarrierArrive();
      // Step 2 — lock all involved venues FOR UPDATE in fixed id order.
      await BookingLockOrder.lockVenues(c, venueIdsToLock);
      // Physical: lock inventory_units after venue and before hold / occupancy,
      // matching cancel / expiry / PAV (BookingLockOrder).
      await BookingLockOrder.lockUnitsForType(
        c,
        quotePeek.rows[0].inventory_type_id,
      );

      // Step 3 — only now take the hold (idempotency) row lock, then the quote.
      // F-REV4-01/02: scoped by consumer+key; expired HTTP + new quote → new hold.
      const prior = await c.query<{
        id: string;
        status: string;
        expires_at: Date;
        consumer_firebase_uid: string;
        quote_id: string;
      }>(
        `SELECT id, status, expires_at, consumer_firebase_uid, quote_id
         FROM booking_holds
         WHERE consumer_firebase_uid = $1 AND idempotency_key = $2
         FOR UPDATE`,
        [input.uid, input.idempotencyKey],
      );
      if (prior.rowCount) {
        const existing = prior.rows[0];
        if (existing.quote_id === input.quoteId) {
          const booking = await c.query<{ id: string }>(
            `SELECT id FROM bookings WHERE hold_id = $1`,
            [existing.id],
          );
          const slot = await c.query<{ slot_code: string | null }>(
            `SELECT slot_code FROM booking_holds WHERE id = $1`,
            [existing.id],
          );
          const provider = await c.query<{ provider_id: string }>(
            `SELECT provider_id FROM venues WHERE id = $1`,
            [quotePeek.rows[0].venue_id],
          );
          return {
            holdId: existing.id,
            expiresAt: new Date(existing.expires_at).toISOString(),
            status: existing.status,
            bookingId: booking.rows[0]?.id ?? "",
            slotCode: slot.rows[0]?.slot_code ?? null,
            paymentOptions: resolveConsumerPaymentOptions(
              provider.rows[0]?.provider_id,
            ),
          };
        }
        // Different quote under same key (HTTP TTL expired → new operation): vacate key.
        await c.query(
          `UPDATE booking_holds
           SET idempotency_key = idempotency_key || '#retired#' || id::text
           WHERE id = $1`,
          [existing.id],
        );
      }
      const quote = await c.query<{
        id: string;
        status: string;
        expires_at: Date;
        venue_id: string;
        inventory_type_id: string;
        check_in: string;
        check_out: string;
        quantity: number;
        consumer_firebase_uid: string;
        gross_total: string;
        commission_bps: number;
        commission_amount: string;
        provider_net: string;
        slot_code: string | null;
        inventory_unit_id: string | null;
      }>(
        `SELECT q.id, q.status, q.expires_at, q.venue_id, q.inventory_type_id,
                q.check_in::text, q.check_out::text, q.quantity, q.consumer_firebase_uid,
                q.gross_total::text, q.commission_bps, q.commission_amount::text, q.provider_net::text,
                q.slot_code, q.inventory_unit_id
         FROM quotes q WHERE q.id = $1 FOR UPDATE`,
        [input.quoteId],
      );
      if (!quote.rowCount) {
        throw new AppError(ErrorCodes.NOT_FOUND, "Quote not found");
      }
      const q = quote.rows[0];
      if (q.consumer_firebase_uid !== input.uid) {
        throw new AppError(
          ErrorCodes.FORBIDDEN_PROVIDER_SCOPE,
          "Quote belongs to another user",
        );
      }
      if (q.status !== "open" || new Date(q.expires_at) <= new Date()) {
        throw new AppError(ErrorCodes.QUOTE_EXPIRED, "Quote expired");
      }
      if (q.quantity !== input.quantity) {
        throw new AppError(
          ErrorCodes.VALIDATION_ERROR,
          "Quantity must match quote",
        );
      }
      const guestSnapshot = parseGuestSnapshot(input.guestSnapshot);
      const guestSnapshotPayload = guestSnapshotJson(guestSnapshot);
      const venue = await c.query<{
        booking_mode: "nightly" | "daily" | "event_slot";
        hold_ttl_seconds: number;
        provider_id: string;
        cancellation_policy_json: unknown;
        venue_type: string;
        status: string;
        timezone: string;
      }>(
        "SELECT booking_mode, hold_ttl_seconds, provider_id, cancellation_policy_json, venue_type, status, timezone FROM venues WHERE id = $1",
        [q.venue_id],
      );
      if (!venue.rowCount) {
        throw new AppError(ErrorCodes.NOT_FOUND, "Venue not found");
      }
      // Re-check booking capability at conversion boundary (fail-closed)
      await this.caps.requireBookingEnabled(venue.rows[0].venue_type, c);
      this.caps.requireEventSlotPathAllowed(venue.rows[0].booking_mode);

      // Venue is already locked FOR UPDATE in step 2 (BookingLockOrder.lockVenues);
      // event_slot templates/slots are locked further below before capacity.
      // F-V3-010: re-check tenancy after Quote (published venue + active provider).
      const venueFresh = await c.query<{
        status: string;
        provider_id: string;
        booking_mode: "nightly" | "daily" | "event_slot";
        hold_ttl_seconds: number;
        cancellation_policy_json: unknown;
        venue_type: string;
        timezone: string;
      }>(
        `SELECT status, provider_id, booking_mode, hold_ttl_seconds, cancellation_policy_json, venue_type, timezone
         FROM venues WHERE id = $1`,
        [q.venue_id],
      );
      if (!venueFresh.rowCount || venueFresh.rows[0].status !== "published") {
        throw new AppError(
          ErrorCodes.VALIDATION_ERROR,
          "Venue is not published",
        );
      }
      const provider = await c.query<{ status: string }>(
        `SELECT status FROM providers WHERE id = $1`,
        [venueFresh.rows[0].provider_id],
      );
      if (!provider.rowCount || provider.rows[0].status !== "active") {
        throw new AppError(
          ErrorCodes.VALIDATION_ERROR,
          "Provider is not active",
        );
      }
      const inv = await c.query<{
        status: string;
        inventory_model: "pooled" | "physical";
      }>(
        `SELECT status, inventory_model FROM inventory_types WHERE id = $1`,
        [q.inventory_type_id],
      );
      if (!inv.rowCount || inv.rows[0].status !== "active") {
        throw new AppError(
          ErrorCodes.VALIDATION_ERROR,
          "Inventory type is not active",
        );
      }
      const isPhysical = inv.rows[0].inventory_model === "physical";
      if (isPhysical) {
        if (venueFresh.rows[0].booking_mode === "event_slot") {
          throw new AppError(
            ErrorCodes.VALIDATION_ERROR,
            "Physical inventory is not valid for event_slot",
            { reason: "physical_event_slot" },
          );
        }
        if (input.quantity !== 1 || q.quantity !== 1) {
          throw new AppError(
            ErrorCodes.VALIDATION_ERROR,
            "Physical inventory quantity must be 1",
            { reason: "physical_quantity" },
          );
        }
        if (!q.inventory_unit_id) {
          throw new AppError(
            ErrorCodes.VALIDATION_ERROR,
            "Physical unit required",
            { reason: "physical_unit_required" },
          );
        }
      }
      // Use locked venue row fields for the rest of the transaction.
      venue.rows[0] = {
        booking_mode: venueFresh.rows[0].booking_mode,
        hold_ttl_seconds: venueFresh.rows[0].hold_ttl_seconds,
        provider_id: venueFresh.rows[0].provider_id,
        cancellation_policy_json: venueFresh.rows[0].cancellation_policy_json,
        venue_type: venueFresh.rows[0].venue_type,
        status: venueFresh.rows[0].status,
        timezone: venueFresh.rows[0].timezone,
      };

      if (venue.rows[0].booking_mode === "event_slot") {
        if (!q.slot_code) {
          throw new AppError(ErrorCodes.VALIDATION_ERROR, "slotCode required");
        }
        if (input.quantity !== 1) {
          throw new AppError(
            ErrorCodes.VALIDATION_ERROR,
            "event_slot quantity must be 1",
          );
        }
        await BookingLockOrder.lockTemplatesForVenue(c, q.venue_id);
        const slots = await BookingLockOrder.lockSlotInventoryForVenueDate(
          c,
          q.venue_id,
          q.check_in,
        );
        const target = slots.find((s) => s.code === q.slot_code);
        if (!target || target.status !== "open") {
          throw new AppError(
            ErrorCodes.SLOT_OR_CAPACITY_CONFLICT,
            "Slot not open",
          );
        }
        if (target.template_status !== "active") {
          throw new AppError(
            ErrorCodes.VALIDATION_ERROR,
            "event_slot template is not active",
          );
        }
        if (target.inventory_type_id !== q.inventory_type_id) {
          throw new AppError(
            ErrorCodes.VALIDATION_ERROR,
            "event_slot template inventory_type_id mismatch",
          );
        }
        for (const other of slots) {
          if (other.id === target.id) continue;
          if (
            BookingLockOrder.timesOverlap(
              target.start_time,
              target.end_time,
              other.start_time,
              other.end_time,
            ) &&
            (other.status === "held" || other.status === "booked")
          ) {
            throw new AppError(
              ErrorCodes.SLOT_OR_CAPACITY_CONFLICT,
              "Overlapping slot held/booked",
            );
          }
        }
        // stash target id + immutable slot instant on quote path via local
        (q as { _slotInventoryId?: string })._slotInventoryId = target.id;
        (q as { _slotStartTime?: string })._slotStartTime = target.start_time;
        (q as { _slotTimezone?: string })._slotTimezone =
          venue.rows[0].timezone || "Asia/Riyadh";
      }

      const dates = stayDates(
        venue.rows[0].booking_mode,
        q.check_in,
        q.check_out,
      );
      const ttl = Math.min(
        venue.rows[0].hold_ttl_seconds || this.env.holdTtlSeconds,
        Math.max(
          300,
          Math.floor((new Date(q.expires_at).getTime() - Date.now()) / 1000),
        ),
      );
      const expiresAt = new Date(Date.now() + ttl * 1000);
      // Phase 7 RC2: event_slot capacity lives solely in event_slot_inventory.
      // It must NOT consume inventory_daily_capacity or apply nightly/daily
      // availability rules (those belong to nightly/daily modes only).
      const isEventSlot = venue.rows[0].booking_mode === "event_slot";
      if (!isEventSlot) {
        const open = await this.availability.datesOpenUnderRules(
          q.inventory_type_id,
          dates,
          c,
        );
        if (!open) {
          throw new AppError(
            ErrorCodes.AVAILABILITY_CHANGED,
            "Dates closed under availability rules",
          );
        }
        if (isPhysical) {
          await BookingLockOrder.lockInventoryType(c, q.inventory_type_id);
          const free = await this.capacity.listAvailablePhysicalUnits(
            q.inventory_type_id,
            q.check_in,
            q.check_out,
            dates,
            c,
          );
          if (!free.some((u) => u.id === q.inventory_unit_id)) {
            metrics.inc("hold_conflict");
            throw new AppError(
              ErrorCodes.AVAILABILITY_CHANGED,
              "Inventory no longer available",
            );
          }
        }
        try {
          await this.capacity.lockAndHold(
            q.inventory_type_id,
            dates,
            input.quantity,
            c,
          );
        } catch (err) {
          metrics.inc("hold_conflict");
          throw err;
        }
      }
      const holdId = newId();
      const bookingId = newId();
      const human = await c.query<{ n: string }>(
        "SELECT nextval('booking_code_seq')::text AS n",
      );
      const year = new Date().getUTCFullYear();
      const code = `BKG-${year}-${human.rows[0].n.padStart(6, "0")}`;
      await c.query(
        `UPDATE quotes SET guest_snapshot_json = $2::jsonb WHERE id = $1`,
        [q.id, guestSnapshotPayload],
      );
      await c.query(
        `INSERT INTO booking_holds (
           id, quote_id, inventory_type_id, consumer_firebase_uid, quantity,
           check_in, check_out, status, expires_at, extensions, idempotency_key, slot_code,
           inventory_unit_id, guest_snapshot_json
         ) VALUES ($1,$2,$3,$4,$5,$6::date,$7::date,'ACTIVE',$8,0,$9,$10,$11,$12::jsonb)`,
        [
          holdId,
          q.id,
          q.inventory_type_id,
          input.uid,
          input.quantity,
          q.check_in,
          q.check_out,
          expiresAt.toISOString(),
          input.idempotencyKey,
          q.slot_code,
          q.inventory_unit_id,
          guestSnapshotPayload,
        ],
      );
      const slotInventoryId = (q as { _slotInventoryId?: string })._slotInventoryId;
      if (slotInventoryId) {
        const slotUpd = await c.query(
          `UPDATE event_slot_inventory
           SET status = 'held', hold_id = $2
           WHERE id = $1 AND status = 'open' AND hold_id IS NULL AND booking_id IS NULL`,
          [slotInventoryId, holdId],
        );
        if (slotUpd.rowCount !== 1) {
          throw new AppError(
            ErrorCodes.SLOT_OR_CAPACITY_CONFLICT,
            "Slot hold CAS failed",
          );
        }
      }
      await c.query(`UPDATE quotes SET status = 'consumed' WHERE id = $1`, [
        q.id,
      ]);
      await c.query(
        `INSERT INTO bookings (
           id, hold_id, quote_id, venue_id, provider_id, inventory_type_id,
           consumer_firebase_uid, human_code, status, quantity, check_in, check_out,
           gross_total, commission_bps, commission_amount, provider_net,
           cancellation_policy_snapshot_json, slot_code, slot_start_time, slot_timezone,
           inventory_unit_id, guest_snapshot_json
         ) VALUES (
           $1,$2,$3,$4,$5,$6,$7,$8,'HOLDING',$9,$10::date,$11::date,$12,$13,$14,$15,$16::jsonb,$17,$18::time,$19,$20,$21::jsonb
         )`,
        [
          bookingId,
          holdId,
          q.id,
          q.venue_id,
          venue.rows[0].provider_id,
          q.inventory_type_id,
          input.uid,
          code,
          input.quantity,
          q.check_in,
          q.check_out,
          q.gross_total,
          q.commission_bps,
          q.commission_amount,
          q.provider_net,
          JSON.stringify(venue.rows[0].cancellation_policy_json),
          q.slot_code,
          (q as { _slotStartTime?: string })._slotStartTime ?? null,
          (q as { _slotTimezone?: string })._slotTimezone ?? null,
          q.inventory_unit_id,
          guestSnapshotPayload,
        ],
      );
      const nightItems = await c.query<{
        date: string;
        amount: string;
        qty: number;
      }>(
        `SELECT date::text, amount::text, qty FROM quote_items WHERE quote_id = $1 AND kind = 'night'`,
        [q.id],
      );
      for (const ni of nightItems.rows) {
        await c.query(
          `INSERT INTO booking_items (id, booking_id, inventory_type_id, date, quantity, night_amount)
           VALUES ($1,$2,$3,$4::date,$5,$6)`,
          [newId(), bookingId, q.inventory_type_id, ni.date, ni.qty, ni.amount],
        );
      }
      if (isPhysical && q.inventory_unit_id) {
        await this.capacity.occupyPhysicalUnit(
          {
            unitId: q.inventory_unit_id,
            holdId,
            bookingId,
            checkIn: q.check_in,
            checkOut: q.check_out,
          },
          c,
        );
      }
      await this.sm.transition(c, {
        bookingId,
        from: "",
        to: "HOLDING",
        actorUid: input.uid,
        actorRole: "consumer",
        correlationId: input.correlationId,
        eventName: "hold.created",
        eventPayload: { holdId },
      });
      metrics.inc("hold_success");
      return {
        holdId,
        expiresAt: expiresAt.toISOString(),
        status: "ACTIVE",
        bookingId,
        slotCode: q.slot_code,
        inventoryUnitId: q.inventory_unit_id,
        paymentOptions: resolveConsumerPaymentOptions(venue.rows[0].provider_id),
      };
    };
    if (client) {
      return run(client);
    }
    return this.pg.tx(run);
  }

  /**
   * Expire ACTIVE holds past expires_at.
   * Atomic claim: status=ACTIVE AND expires_at<=now() (extended holds survive).
   * Lock order: venue → templates → slots → hold → booking → capacity.
   */
  async expireDue(): Promise<number> {
    const due = await this.pg.query<{ id: string }>(
      `SELECT h.id FROM booking_holds h
       WHERE h.status = 'ACTIVE' AND h.expires_at <= now()
       ORDER BY h.expires_at ASC
       LIMIT 50`,
    );
    let n = 0;
    for (const row of due.rows) {
      const expired = await this.expireOne(row.id);
      if (expired) {
        n += 1;
      }
    }
    return n;
  }

  async expireOne(holdId: string): Promise<boolean> {
    return this.pg.tx(async (c) => {
      // Non-locking peek for venue/date (needed for lock order before claim)
      const peek = await c.query<{
        venue_id: string;
        check_in: string;
        booking_mode: "nightly" | "daily" | "event_slot";
        inventory_type_id: string;
        quantity: number;
        check_out: string;
      }>(
        `SELECT v.id AS venue_id, h.check_in::text, v.booking_mode,
                h.inventory_type_id, h.quantity, h.check_out::text
         FROM booking_holds h
         JOIN inventory_types t ON t.id = h.inventory_type_id
         JOIN venues v ON v.id = t.venue_id
         WHERE h.id = $1`,
        [holdId],
      );
      if (!peek.rowCount) {
        return false;
      }
      const p = peek.rows[0];
      await BookingLockOrder.lockVenue(c, p.venue_id);
      await BookingLockOrder.lockUnitsForType(c, p.inventory_type_id);
      if (p.booking_mode === "event_slot") {
        await BookingLockOrder.lockTemplatesForVenue(c, p.venue_id);
        await BookingLockOrder.lockSlotInventoryForVenueDate(
          c,
          p.venue_id,
          p.check_in,
        );
      }
      // RC6: lock hold then booking before claim (unified order).
      await BookingLockOrder.lockHold(c, holdId);
      await BookingLockOrder.lockBookingByHold(c, holdId).catch(() => undefined);

      // Atomic claim — refuses extended holds (expires_at moved past now)
      const still = await c.query<{
        id: string;
        inventory_type_id: string;
        quantity: number;
        check_in: string;
        check_out: string;
      }>(
        `UPDATE booking_holds
         SET status = 'EXPIRED'
         WHERE id = $1
           AND status = 'ACTIVE'
           AND expires_at <= now()
         RETURNING id, inventory_type_id, quantity, check_in::text, check_out::text`,
        [holdId],
      );
      if (!still.rowCount) {
        return false;
      }
      const h = still.rows[0];
      if (p.booking_mode === "event_slot") {
        // Phase 7 RC2: event_slot capacity is only event_slot_inventory —
        // it never held daily capacity, so there is nothing to release there.
        await c.query(
          `UPDATE event_slot_inventory
           SET status = 'open', hold_id = NULL
           WHERE hold_id = $1 AND status = 'held'`,
          [holdId],
        );
      } else {
        // F-V2-006 partial: restore only unconsumed (future) held days.
        const today = riyadhTodayIso();
        const dates = stayDates(p.booking_mode, h.check_in, h.check_out).filter(
          (d) => d >= today,
        );
        await this.capacity.releaseHeld(
          h.inventory_type_id,
          dates,
          h.quantity,
          c,
        );
        await this.capacity.releasePhysicalOccupancy(holdId, c);
      }
      const booking = await c.query<{ id: string; status: string }>(
        `SELECT id, status FROM bookings WHERE hold_id = $1`,
        [holdId],
      );
      if (
        booking.rowCount &&
        (booking.rows[0].status === "HOLDING" ||
          booking.rows[0].status === "PENDING_PAYMENT" ||
          booking.rows[0].status === "PAYMENT_FAILED")
      ) {
        await this.sm.transition(c, {
          bookingId: booking.rows[0].id,
          from: booking.rows[0].status as
            | "HOLDING"
            | "PENDING_PAYMENT"
            | "PAYMENT_FAILED",
          to: "EXPIRED",
          actorUid: "system",
          actorRole: "system",
          correlationId: "hold-expiry-worker",
          eventName: "hold.expired",
          eventPayload: { holdId },
        });
      } else {
        await this.audit.write(
          {
            actorUid: "system",
            actorRole: "system",
            entityType: "hold",
            entityId: holdId,
            after: { status: "EXPIRED" },
            correlationId: "hold-expiry-worker",
          },
          c,
        );
      }
      return true;
    });
  }

  async extendOnce(
    holdId: string,
    uid: string,
  ): Promise<{ expiresAt: string }> {
    return this.pg.tx(async (c) => {
      const peek = await c.query<{
        venue_id: string;
        booking_mode: "nightly" | "daily" | "event_slot";
        check_in: string;
      }>(
        `SELECT v.id AS venue_id, v.booking_mode, h.check_in::text
         FROM booking_holds h
         JOIN inventory_types t ON t.id = h.inventory_type_id
         JOIN venues v ON v.id = t.venue_id
         WHERE h.id = $1`,
        [holdId],
      );
      if (!peek.rowCount) {
        throw new AppError(ErrorCodes.NOT_FOUND, "Hold not found");
      }
      await BookingLockOrder.lockVenue(c, peek.rows[0].venue_id);
      if (peek.rows[0].booking_mode === "event_slot") {
        await BookingLockOrder.lockTemplatesForVenue(c, peek.rows[0].venue_id);
        await BookingLockOrder.lockSlotInventoryForVenueDate(
          c,
          peek.rows[0].venue_id,
          peek.rows[0].check_in,
        );
      }
      await BookingLockOrder.lockHold(c, holdId);

      const hold = await c.query<{
        status: string;
        extensions: number;
        expires_at: Date;
        consumer_firebase_uid: string;
      }>(
        `SELECT status, extensions, expires_at, consumer_firebase_uid FROM booking_holds WHERE id = $1`,
        [holdId],
      );
      if (!hold.rowCount || hold.rows[0].consumer_firebase_uid !== uid) {
        throw new AppError(ErrorCodes.NOT_FOUND, "Hold not found");
      }
      const pay = await c.query(
        `SELECT 1 FROM payments WHERE hold_id = $1 AND status = 'pending'`,
        [holdId],
      );
      if (
        hold.rows[0].status !== "ACTIVE" ||
        hold.rows[0].extensions >= 1 ||
        !pay.rowCount
      ) {
        throw new AppError(
          ErrorCodes.VALIDATION_ERROR,
          "Hold cannot be extended",
        );
      }
      const next = new Date(
        new Date(hold.rows[0].expires_at).getTime() + 6 * 60 * 1000,
      );
      await c.query(
        `UPDATE booking_holds SET expires_at = $2, extensions = 1 WHERE id = $1`,
        [holdId, next.toISOString()],
      );
      return { expiresAt: next.toISOString() };
    });
  }
}
