import { Injectable } from "@nestjs/common";
import { Inject } from "@nestjs/common";
import { APP_CONFIG } from "../../../shared/config/app-config";
import { AppEnv } from "../../../shared/config/env";
import { PgService } from "../../../shared/database/pg.service";
import { AppError } from "../../../shared/errors/app-error";
import { ErrorCodes } from "../../../shared/errors/error-codes";
import { newId } from "../../../shared/ids/ids";
import { OutboxService } from "../../../shared/events/outbox.service";
import { VenueTypeCapabilityPolicy } from "../../filters/application/venue-type-capability.policy";
import {
  ConsumerPaymentOptions,
  resolveConsumerPaymentOptions,
} from "../../booking/application/consumer-payment-options";
import { PricingEngine, QuoteInput } from "./pricing.engine";

export interface QuoteDto {
  quoteId: string;
  currency: string;
  items: unknown[];
  subtotal: string;
  extrasTotal: string;
  discountTotal: string;
  taxTotal: string;
  grossTotal: string;
  expiresAt: string;
  pricingVersion: string;
  slotCode: string | null;
  bookingMode: "nightly" | "daily" | "event_slot";
  paymentOptions: ConsumerPaymentOptions;
  inventoryUnitId: string | null;
}

@Injectable()
export class QuoteService {
  constructor(
    private readonly engine: PricingEngine,
    private readonly pg: PgService,
    @Inject(APP_CONFIG) private readonly env: AppEnv,
    private readonly outbox: OutboxService,
    private readonly caps: VenueTypeCapabilityPolicy,
  ) {}

  async create(uid: string, input: QuoteInput): Promise<QuoteDto> {
    const venue = await this.pg.query<{
      venue_type: string;
      provider_id: string;
    }>(
      `SELECT venue_type, provider_id FROM venues WHERE id = $1`,
      [input.venueId],
    );
    if (!venue.rowCount) {
      throw new AppError(ErrorCodes.NOT_FOUND, "Venue not found");
    }
    await this.caps.requireBookingEnabled(venue.rows[0].venue_type);
    const modeRow = await this.pg.query<{ booking_mode: string }>(
      `SELECT booking_mode FROM venues WHERE id = $1`,
      [input.venueId],
    );
    this.caps.requireEventSlotPathAllowed(modeRow.rows[0].booking_mode);
    const calc = await this.engine.compute(input);
    const id = newId();
    const expires = new Date(Date.now() + this.env.quoteTtlSeconds * 1000);
    await this.pg.tx(async (c) => {
      await c.query(
        `INSERT INTO quotes (
           id, consumer_firebase_uid, venue_id, inventory_type_id, check_in, check_out,
           quantity, guests_adults, guests_children, currency, subtotal, extras_total,
           discount_total, tax_total, gross_total, commission_bps, commission_amount,
           provider_net, pricing_version, expires_at, status, slot_code, inventory_unit_id
         ) VALUES (
           $1,$2,$3,$4,$5::date,$6::date,$7,$8,$9,'SAR',$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,'open',$20,$21
         )`,
        [
          id,
          uid,
          input.venueId,
          input.inventoryTypeId,
          input.checkIn,
          input.checkOut,
          input.quantity,
          input.guestsAdults,
          input.guestsChildren,
          calc.subtotal,
          calc.extrasTotal,
          calc.discountTotal,
          calc.taxTotal,
          calc.grossTotal,
          calc.commissionBps,
          calc.commissionAmount,
          calc.providerNet,
          calc.pricingVersion,
          expires.toISOString(),
          calc.slotCode,
          input.inventoryUnitId ?? null,
        ],
      );
      for (const item of calc.items) {
        await c.query(
          `INSERT INTO quote_items (id, quote_id, kind, date, label, amount, qty)
           VALUES ($1,$2,$3,$4::date,$5,$6,$7)`,
          [
            newId(),
            id,
            item.kind,
            item.date,
            item.label,
            item.amount,
            item.qty,
          ],
        );
      }
      await this.outbox.enqueue("quote.created", { quoteId: id, uid }, c);
    });
    return {
      quoteId: id,
      currency: "SAR",
      items: calc.items,
      subtotal: calc.subtotal,
      extrasTotal: calc.extrasTotal,
      discountTotal: calc.discountTotal,
      taxTotal: calc.taxTotal,
      grossTotal: calc.grossTotal,
      expiresAt: expires.toISOString(),
      pricingVersion: calc.pricingVersion,
      slotCode: calc.slotCode,
      bookingMode: calc.bookingMode,
      paymentOptions: resolveConsumerPaymentOptions(venue.rows[0].provider_id),
      inventoryUnitId: input.inventoryUnitId ?? null,
    };
  }
}
