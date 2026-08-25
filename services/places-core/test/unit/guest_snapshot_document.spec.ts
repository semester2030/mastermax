import { BookingQuery } from "../../src/modules/booking/application/booking.query";
import { formatArabicDate } from "../../src/modules/booking/application/arabic-document-format";
import {
  isPdfBuffer,
  pdfContainsInternalIds,
  renderBookingDocumentPdf,
} from "../../src/modules/booking/application/booking-document-pdf";
import {
  documentLines,
  mapConsumerBookingDocument,
} from "../../src/modules/booking/application/consumer-booking-document";
import { parseGuestSnapshot } from "../../src/modules/booking/application/guest-snapshot";
import { PgService } from "../../src/shared/database/pg.service";
import { AppError } from "../../src/shared/errors/app-error";
import { ErrorCodes } from "../../src/shared/errors/error-codes";

const snapshot = {
  bookerFullName: "فائز المختبر",
  bookerPhone: "0501234567",
  bookerEmail: "fayez@example.com",
  bookingForOther: false,
};

const baseRow = {
  status: "CONFIRMED",
  payment_method: "PAY_AT_VENUE",
  human_code: "BKG-2026-000111",
  gross_total: "2400.00",
  currency: "SAR",
  venue_name: "نارسس",
  inventory_type_label_ar: "غرف",
  check_in: "2026-12-10",
  check_out: "2026-12-12",
  guests_adults: 2,
  guests_children: 0,
  guest_snapshot_json: snapshot,
  cancellation_policy_snapshot_json: { summary: "إلغاء مجاني حتى 24 ساعة" },
};

describe("guest snapshot + booking document", () => {
  it("rejects missing booker name and phone", () => {
    expect(() => parseGuestSnapshot({})).toThrow(AppError);
    try {
      parseGuestSnapshot({ bookerPhone: "0501234567" });
    } catch (e) {
      expect((e as AppError).code).toBe(ErrorCodes.VALIDATION_ERROR);
    }
    expect(() =>
      parseGuestSnapshot({ bookerFullName: "فائز المختبر" }),
    ).toThrow(AppError);
  });

  it("requires guest fields when booking for someone else", () => {
    expect(() =>
      parseGuestSnapshot({
        ...snapshot,
        bookingForOther: true,
      }),
    ).toThrow(/الضيف/);
    const ok = parseGuestSnapshot({
      ...snapshot,
      bookingForOther: true,
      guestFullName: "ضيف الاختبار",
      guestPhone: "0555555555",
    });
    expect(ok.guestFullName).toBe("ضيف الاختبار");
  });

  it("stores snapshot fields without uid", () => {
    const parsed = parseGuestSnapshot(snapshot);
    expect(JSON.stringify(parsed)).not.toMatch(/uid|firebase/i);
    expect(parsed.bookerFullName).toBe("فائز المختبر");
  });

  it("canonicalizes Saudi mobiles to +9665 and rejects others", () => {
    expect(parseGuestSnapshot({ ...snapshot, bookerPhone: "0501234567" }).bookerPhone)
      .toBe("+966501234567");
    expect(parseGuestSnapshot({ ...snapshot, bookerPhone: "966501234567" }).bookerPhone)
      .toBe("+966501234567");
    expect(parseGuestSnapshot({ ...snapshot, bookerPhone: "+966501234567" }).bookerPhone)
      .toBe("+966501234567");
    expect(() =>
      parseGuestSnapshot({ ...snapshot, bookerPhone: "0123456789" }),
    ).toThrow(/05xxxxxxxx/);
  });

  it("formats stay dates in Arabic without ISO or clock suffix", () => {
    expect(formatArabicDate("2026-12-10T00:00:00.000Z")).toBe("10 ديسمبر 2026");
    expect(formatArabicDate("2026-12-10")).toBe("10 ديسمبر 2026");
  });

  it("confirmation before collection is unpaid confirmation not tax invoice", () => {
    const doc = mapConsumerBookingDocument({
      ...baseRow,
      payment_status: "DUE_AT_VENUE",
    });
    expect(doc.kind).toBe("CONFIRMATION");
    expect(doc.titleAr).toBe("تأكيد حجز — غير مدفوع");
    expect(doc.downloadFileName).toBe("confirmation-BKG-2026-000111.pdf");
    expect(doc.bodyAr).not.toContain("صادر من Core");
    expect(doc.bodyAr).not.toContain("00:00:00.000Z");
    expect(doc.bodyAr).toContain("ر.س");
    expect(doc.legalInvoice).toBe(false);
    expect(doc.legalInvoiceNoteAr).toContain("ليس فاتورة ضريبية");
  });

  it("becomes payment receipt only after COLLECTED_AT_VENUE", () => {
    const doc = mapConsumerBookingDocument({
      ...baseRow,
      payment_status: "COLLECTED_AT_VENUE",
    });
    expect(doc.kind).toBe("COLLECTION_RECEIPT");
    expect(doc.titleAr).toBe("إيصال دفع");
    expect(doc.titleAr).not.toContain("فاتورة");
    expect(doc.downloadFileName).toContain("receipt");
  });

  it("pdfForConsumer returns 403 when another user asks for the PDF", async () => {
    const pg = {
      query: async (sql: string) => {
        if (sql.includes("SELECT consumer_firebase_uid FROM bookings")) {
          return {
            rowCount: 1,
            rows: [{ consumer_firebase_uid: "owner-uid" }],
          };
        }
        return { rowCount: 1, rows: [baseRow] };
      },
    } as unknown as PgService;
    const q = new BookingQuery(pg);
    await expect(q.pdfForConsumer("other-uid", "b-1")).rejects.toMatchObject({
      code: ErrorCodes.FORBIDDEN_BOOKING_OWNERSHIP,
      httpStatus: 403,
    } as Partial<AppError>);
  });

  it("renders a real PDF without internal ids", async () => {
    const bytes = await renderBookingDocumentPdf({
      ...baseRow,
      payment_status: "DUE_AT_VENUE",
    });
    expect(isPdfBuffer(bytes)).toBe(true);
    expect(pdfContainsInternalIds(bytes)).toBe(false);
    const after = await renderBookingDocumentPdf({
      ...baseRow,
      payment_status: "COLLECTED_AT_VENUE",
    });
    expect(isPdfBuffer(after)).toBe(true);
    const lines = documentLines({
      ...baseRow,
      payment_status: "DUE_AT_VENUE",
    }).lines;
    expect(lines.find((l) => l.label === "رقم الحجز")?.value).toBe(
      "BKG-2026-000111",
    );
    expect(lines.find((l) => l.label === "اسم العميل")?.value).toBe(
      "فائز المختبر",
    );
    expect(lines.some((l) => /uid|01a01d/i.test(l.value))).toBe(false);
  });
});
