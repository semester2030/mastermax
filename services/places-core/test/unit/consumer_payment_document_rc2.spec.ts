import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { resolveConsumerPaymentOptions } from "../../src/modules/booking/application/consumer-payment-options";
import { mapConsumerBookingDocument } from "../../src/modules/booking/application/consumer-booking-document";
import { mapConsumerBookingRow } from "../../src/modules/booking/application/booking.query";
import { parseAmenityCatalogIconKeysFromSql } from "../../src/modules/filters/application/amenity-catalog-sql";

describe("RC2 Core payment options + documents + amenity catalog", () => {
  const prevEnabled = process.env.PLACES_PAY_AT_VENUE_ENABLED;
  const prevAllow = process.env.PLACES_PAY_AT_VENUE_PROVIDER_ALLOWLIST;

  afterEach(() => {
    process.env.PLACES_PAY_AT_VENUE_ENABLED = prevEnabled;
    process.env.PLACES_PAY_AT_VENUE_PROVIDER_ALLOWLIST = prevAllow;
  });

  it("T-RC2-PAV-01 quote/hold contract payAtVenue true when Core enabled", () => {
    process.env.PLACES_PAY_AT_VENUE_ENABLED = "true";
    process.env.PLACES_PAY_AT_VENUE_PROVIDER_ALLOWLIST = "";
    const opts = resolveConsumerPaymentOptions("prov-1");
    expect(opts.payAtVenue).toBe(true);
    expect(opts.availableMethods).toEqual(["PAY_AT_VENUE"]);
  });

  it("T-RC2-PAV-02 payAtVenue false when Core disabled", () => {
    process.env.PLACES_PAY_AT_VENUE_ENABLED = "false";
    const opts = resolveConsumerPaymentOptions("prov-1");
    expect(opts.payAtVenue).toBe(false);
    expect(opts.availableMethods).toEqual([]);
  });

  it("T-RC2-DOC-01 confirmation before collection", () => {
    const doc = mapConsumerBookingDocument({
      status: "CONFIRMED",
      payment_method: "PAY_AT_VENUE",
      payment_status: "DUE_AT_VENUE",
      human_code: "PLC-1",
      gross_total: "100.00",
      currency: "SAR",
      venue_name: "فندق",
    });
    expect(doc.kind).toBe("CONFIRMATION");
    expect(doc.titleAr).toBe("تأكيد حجز — غير مدفوع");
    expect(doc.canDownload).toBe(true);
    expect(doc.legalInvoice).toBe(false);
    expect(doc.downloadFileName).toContain(".pdf");
    expect(doc.downloadText).toContain("PLC-1");
    expect(doc.downloadText).not.toContain("صادر من Core");
    expect(doc.legalInvoiceNoteAr).toContain("ليس فاتورة ضريبية");
  });

  it("T-RC2-DOC-02 collection receipt after COLLECTED_AT_VENUE", () => {
    const doc = mapConsumerBookingDocument({
      status: "CONFIRMED",
      payment_method: "PAY_AT_VENUE",
      payment_status: "COLLECTED_AT_VENUE",
      human_code: "PLC-2",
      gross_total: "100.00",
      currency: "SAR",
      venue_name: "فندق",
    });
    expect(doc.kind).toBe("COLLECTION_RECEIPT");
    expect(doc.titleAr).toBe("إيصال دفع");
    expect(doc.downloadFileName).toContain("receipt");
  });

  it("T-RC2-DOC-03 cancellation after CANCELLED/VOIDED", () => {
    const doc = mapConsumerBookingDocument({
      status: "CANCELLED",
      payment_method: "PAY_AT_VENUE",
      payment_status: "VOIDED",
      human_code: "PLC-3",
      venue_name: "فندق",
    });
    expect(doc.kind).toBe("CANCELLATION");
    expect(doc.titleAr).toBe("مستند إلغاء");
    expect(doc.bodyAr).toContain("ملغى");
  });

  it("T-RC2-DOC-04 booking projection includes Core document", () => {
    const mapped = mapConsumerBookingRow({
      id: "b-1",
      human_code: "DAR-9",
      status: "CONFIRMED",
      payment_method: "PAY_AT_VENUE",
      payment_status: "DUE_AT_VENUE",
      gross_total: "10.00",
      currency: "SAR",
      venue_name: "مكان",
    });
    expect((mapped.document as { kind: string }).kind).toBe("CONFIRMATION");
  });

  it("T-RC2-ICON-01 every amenity_catalog icon_key from Core SQL is present", () => {
    const sql = readFileSync(
      resolve(
        process.cwd(),
        "db/migrations/006_gate7a_filter_engine.sql",
      ),
      "utf8",
    );
    const keys = parseAmenityCatalogIconKeysFromSql(sql);
    expect(keys.length).toBeGreaterThan(10);
    expect(keys).toContain("wifi");
    expect(keys).toContain("local_parking");
  });
});
