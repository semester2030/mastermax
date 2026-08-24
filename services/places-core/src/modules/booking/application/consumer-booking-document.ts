export type ConsumerBookingDocumentKind =
  | "CONFIRMATION"
  | "COLLECTION_RECEIPT"
  | "CANCELLATION";

export type ConsumerBookingDocument = {
  kind: ConsumerBookingDocumentKind;
  titleAr: string;
  bodyAr: string;
  downloadFileName: string;
  downloadText: string;
  canDownload: boolean;
  legalInvoice: false;
  legalInvoiceBlocked: boolean;
  legalInvoiceNoteAr: string;
};

const LEGAL_NOTE =
  "الفاتورة النظامية يصدرها مقدم الخدمة عند الدفع ما لم يوجد عقد إصدار حقيقي في Core. هذا المستند ليس فاتورة ضريبية.";

export function mapConsumerBookingDocument(row: {
  status?: unknown;
  payment_status?: unknown;
  payment_method?: unknown;
  human_code?: unknown;
  gross_total?: unknown;
  currency?: unknown;
  venue_name?: unknown;
}): ConsumerBookingDocument {
  const status = String(row.status ?? "").toUpperCase();
  const pay = String(row.payment_status ?? "").toUpperCase();
  const method = String(row.payment_method ?? "").toUpperCase();
  const code = String(row.human_code ?? "—");
  const amount = String(row.gross_total ?? "—");
  const currency = String(row.currency ?? "SAR");
  const venue = String(row.venue_name ?? "مكان");

  if (status === "CANCELLED" || pay === "VOIDED") {
    const body = `مستند إلغاء صادر من Core. رمز ${code} · ${venue}. لا إيصال دفع ولا فاتورة تحصيل.`;
    return base("CANCELLATION", "مستند إلغاء", body, `cancel-${code}.txt`);
  }

  if (method === "PAY_AT_VENUE" && pay === "COLLECTED_AT_VENUE") {
    const body = `إيصال تحصيل عند الوصول صادر من Core. رمز ${code} · حُصّل ${amount} ${currency} في ${venue}.`;
    return base(
      "COLLECTION_RECEIPT",
      "إيصال تحصيل عند الوصول",
      `${body}\n${LEGAL_NOTE}`,
      `receipt-${code}.txt`,
    );
  }

  const body =
    method === "PAY_AT_VENUE" && pay === "DUE_AT_VENUE"
      ? `تأكيد حجز صادر من Core. رمز ${code} · ${amount} ${currency} مستحق عند الوصول في ${venue}. لم يُحصّل بعد.`
      : `تأكيد حجز صادر من Core. رمز ${code} · ${venue}. لا إيصال تحصيل بعد.`;
  return base(
    "CONFIRMATION",
    "تأكيد الحجز",
    `${body}\n${LEGAL_NOTE}`,
    `confirmation-${code}.txt`,
  );
}

function base(
  kind: ConsumerBookingDocumentKind,
  titleAr: string,
  bodyAr: string,
  downloadFileName: string,
): ConsumerBookingDocument {
  return {
    kind,
    titleAr,
    bodyAr,
    downloadFileName,
    downloadText: `${titleAr}\n\n${bodyAr}\n`,
    canDownload: true,
    legalInvoice: false,
    legalInvoiceBlocked: true,
    legalInvoiceNoteAr: LEGAL_NOTE,
  };
}
