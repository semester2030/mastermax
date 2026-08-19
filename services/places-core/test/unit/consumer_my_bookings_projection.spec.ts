import {
  BookingQuery,
  mapConsumerBookingRow,
} from "../../src/modules/booking/application/booking.query";
import { PgService } from "../../src/shared/database/pg.service";
import { AppError } from "../../src/shared/errors/app-error";
import { ErrorCodes } from "../../src/shared/errors/error-codes";

describe("T-MB-DTO consumer my bookings projection", () => {
  const sampleRow = {
    id: "b-1",
    human_code: "DAR-1001",
    status: "CONFIRMED",
    check_in: "2026-09-01",
    check_out: "2026-09-03",
    gross_total: "1200.00",
    currency: "SAR",
    payment_method: "PAY_AT_VENUE",
    payment_status: "DUE_AT_VENUE",
    venue_id: "v-1",
    inventory_type_id: "it-1",
    quantity: 1,
    slot_code: null,
    confirmed_at: "2026-08-17T10:00:00Z",
    cancelled_at: null,
    created_at: "2026-08-17T09:00:00Z",
    updated_at: "2026-08-17T10:00:00Z",
    cancellation_policy_snapshot_json: {
      free_until_hours_before_checkin: 48,
      fee_bps_after: 5000,
    },
    venue_name: "قصر النخيل",
    venue_lat: 24.7,
    venue_lng: 46.7,
    inventory_type_name: "جناح",
    guests_adults: 2,
    guests_children: 1,
    cover_url: "https://cdn.example/cover.jpg",
    has_review: false,
  };

  it("T-MB-DTO-01 maps required Flutter fields + dual keys", () => {
    const mapped = mapConsumerBookingRow(sampleRow);
    expect(mapped.humanCode).toBe("DAR-1001");
    expect(mapped.venueName).toBe("قصر النخيل");
    expect(mapped.coverUrl).toBe("https://cdn.example/cover.jpg");
    expect(mapped.inventoryTypeName).toBe("جناح");
    expect(mapped.dueAtVenueAmount).toBe("1200.00");
    expect(mapped.guests).toEqual({ adults: 2, children: 1 });
    expect(mapped.lat).toBe(24.7);
    expect(mapped.lng).toBe(46.7);
    expect(mapped.hasReview).toBe(false);
    expect(mapped.cancellationPolicySnapshot).toContain("48");
    expect(mapped.commission_bps).toBeUndefined();
    expect(mapped.commission_amount).toBeUndefined();
    expect(mapped.provider_net).toBeUndefined();
    expect(mapped.hold_id).toBeUndefined();
    expect(mapped.quote_id).toBeUndefined();
  });

  it("T-MB-DTO-02 omits dueAtVenueAmount when not PAV due", () => {
    const mapped = mapConsumerBookingRow({
      ...sampleRow,
      payment_method: "CARD",
      payment_status: "SUCCEEDED",
    });
    expect(mapped.dueAtVenueAmount).toBeNull();
  });

  it("list/detail use ownership filter + approved cover SQL", async () => {
    const calls: { sql: string; params: unknown[] }[] = [];
    const pg = {
      query: async (sql: string, params: unknown[]) => {
        calls.push({ sql, params });
        return { rowCount: 1, rows: [sampleRow] };
      },
    } as unknown as PgService;
    const q = new BookingQuery(pg);

    const list = await q.listForConsumer("uid-a");
    expect(list).toHaveLength(1);
    expect((list[0] as { venueName: string }).venueName).toBe("قصر النخيل");
    expect(calls[0].sql).toContain("consumer_firebase_uid");
    expect(calls[0].sql).toContain("moderation_status = 'approved'");
    expect(calls[0].sql).toMatch(/kind = 'image'/);
    expect(calls[0].params).toEqual(["uid-a"]);

    const one = await q.getForConsumer("uid-a", "b-1");
    expect((one as { humanCode: string }).humanCode).toBe("DAR-1001");
    expect(calls[1].params).toEqual(["b-1", "uid-a"]);
  });

  it("getForConsumer 404 when not owner / missing", async () => {
    const pg = {
      query: async () => ({ rowCount: 0, rows: [] }),
    } as unknown as PgService;
    const q = new BookingQuery(pg);
    await expect(q.getForConsumer("uid-b", "b-1")).rejects.toMatchObject({
      code: ErrorCodes.NOT_FOUND,
    } as Partial<AppError>);
  });
});
