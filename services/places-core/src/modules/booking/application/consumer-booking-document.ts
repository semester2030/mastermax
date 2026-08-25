import {
  formatArabicDate,
  formatArabicIssueDate,
  formatArabicMoney,
  guestCountLabel,
} from "./arabic-document-format";
import { GuestSnapshot, readGuestSnapshot } from "./guest-snapshot";

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
  paymentStatusAr: string;
  paymentMethodAr: string;
};

export type BookingDocumentRow = {
  status?: unknown;
  payment_status?: unknown;
  payment_method?: unknown;
  human_code?: unknown;
  gross_total?: unknown;
  currency?: unknown;
  venue_name?: unknown;
  inventory_type_name?: unknown;
  inventory_type_label_ar?: unknown;
  inventory_unit_label?: unknown;
  check_in?: unknown;
  check_out?: unknown;
  guests_adults?: unknown;
  guests_children?: unknown;
  quantity?: unknown;
  cancellation_policy_snapshot_json?: unknown;
  guest_snapshot_json?: unknown;
  guest_snapshot?: unknown;
};

const LEGAL_NOTE =
  "هذا المستند ليس فاتورة ضريبية. الفاتورة النظامية لا تصدر إلا بعقد وإصدار حقيقي من مقدم الخدمة.";

export function resolveDocumentKind(row: BookingDocumentRow): {
  kind: ConsumerBookingDocumentKind;
  titleAr: string;
  paymentStatusAr: string;
  filePrefix: string;
} {
  const status = String(row.status ?? "").toUpperCase();
  const pay = String(row.payment_status ?? "").toUpperCase();
  if (status === "CANCELLED" || pay === "VOIDED") {
    return {
      kind: "CANCELLATION",
      titleAr: "مستند إلغاء",
      paymentStatusAr: "ملغى",
      filePrefix: "cancel",
    };
  }
  if (pay === "COLLECTED_AT_VENUE") {
    return {
      kind: "COLLECTION_RECEIPT",
      titleAr: "إيصال دفع",
      paymentStatusAr: "تم التحصيل عند الوصول",
      filePrefix: "receipt",
    };
  }
  return {
    kind: "CONFIRMATION",
    titleAr: "تأكيد حجز — غير مدفوع",
    paymentStatusAr: "غير مدفوع",
    filePrefix: "confirmation",
  };
}

export function unitTypeLabel(row: BookingDocumentRow): string {
  const type = String(
    row.inventory_type_label_ar || row.inventory_type_name || "",
  ).trim();
  const unit = String(row.inventory_unit_label ?? "").trim();
  if (type && unit) return `${type} · ${unit}`;
  return type || unit || "—";
}

export function policyText(raw: unknown): string {
  if (raw == null) return "—";
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
  if (!obj) return "—";
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
  return "—";
}

export function documentLines(row: BookingDocumentRow): {
  meta: ReturnType<typeof resolveDocumentKind>;
  snapshot: GuestSnapshot | null;
  lines: Array<{ label: string; value: string }>;
} {
  const meta = resolveDocumentKind(row);
  const snapshot = readGuestSnapshot(
    row.guest_snapshot_json ?? row.guest_snapshot,
  );
  const code = String(row.human_code ?? "—");
  const venue = String(row.venue_name ?? "مكان");
  const lines: Array<{ label: string; value: string }> = [
    { label: "اسم العميل", value: snapshot?.bookerFullName ?? "—" },
    { label: "رقم الجوال", value: snapshot?.bookerPhone ?? "—" },
  ];
  if (snapshot?.bookerEmail) {
    lines.push({ label: "البريد الإلكتروني", value: snapshot.bookerEmail });
  }
  if (snapshot?.bookingForOther) {
    lines.push({ label: "اسم الضيف", value: snapshot.guestFullName ?? "—" });
    lines.push({ label: "جوال الضيف", value: snapshot.guestPhone ?? "—" });
  }
  lines.push(
    { label: "المكان", value: venue },
    { label: "نوع الوحدة", value: unitTypeLabel(row) },
    { label: "رقم الحجز", value: code },
    { label: "تاريخ الوصول", value: formatArabicDate(row.check_in) },
    { label: "تاريخ المغادرة", value: formatArabicDate(row.check_out) },
    {
      label: "عدد الضيوف",
      value: guestCountLabel(row.guests_adults, row.guests_children),
    },
    { label: "المبلغ", value: formatArabicMoney(row.gross_total) },
    { label: "طريقة الدفع", value: "الدفع عند الوصول" },
    { label: "حالة الدفع", value: meta.paymentStatusAr },
    { label: "سياسة الإلغاء", value: policyText(row.cancellation_policy_snapshot_json) },
    { label: "تاريخ الإصدار", value: formatArabicIssueDate() },
  );
  return { meta, snapshot, lines };
}

export function mapConsumerBookingDocument(
  row: BookingDocumentRow,
): ConsumerBookingDocument {
  const { meta, lines } = documentLines(row);
  const code = String(row.human_code ?? "booking");
  const body = lines.map((l) => `${l.label}: ${l.value}`).join("\n");
  return {
    kind: meta.kind,
    titleAr: meta.titleAr,
    bodyAr: body,
    downloadFileName: `${meta.filePrefix}-${code}.pdf`,
    downloadText: `${meta.titleAr}\n\n${body}\n\n${LEGAL_NOTE}\n`,
    canDownload: true,
    legalInvoice: false,
    legalInvoiceBlocked: true,
    legalInvoiceNoteAr: LEGAL_NOTE,
    paymentStatusAr: meta.paymentStatusAr,
    paymentMethodAr: "الدفع عند الوصول",
  };
}
