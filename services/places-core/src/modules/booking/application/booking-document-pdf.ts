import { existsSync } from "node:fs";
import { join } from "node:path";
import PDFDocument from "pdfkit";
import arabicReshaper from "arabic-reshaper";
import bidiFactory from "bidi-js";
import { documentLines } from "./consumer-booking-document";
import type { BookingDocumentRow } from "./consumer-booking-document";

const bidi = bidiFactory();

function reshapeRtl(text: string): string {
  const reshaped = arabicReshaper.convertArabic(String(text ?? ""));
  try {
    const levels = bidi.getEmbeddingLevels(reshaped);
    return bidi.getReorderedString(reshaped, levels);
  } catch {
    return reshaped;
  }
}

function assetPath(...parts: string[]): string {
  return join(process.cwd(), "assets", ...parts);
}

function fontPath(): string {
  const candidates = [
    assetPath("fonts", "NotoNaskhArabic-Regular.ttf"),
    join(__dirname, "../../../../assets/fonts/NotoNaskhArabic-Regular.ttf"),
  ];
  for (const p of candidates) {
    if (existsSync(p)) return p;
  }
  throw new Error("Arabic PDF font missing");
}

function logoPath(): string | null {
  const candidates = [
    assetPath("dar_car_logo.png"),
    join(process.cwd(), "../../assets/images/logos/dar_car_logo.png"),
  ];
  for (const p of candidates) {
    if (existsSync(p)) return p;
  }
  return null;
}

export async function renderBookingDocumentPdf(
  row: BookingDocumentRow,
): Promise<Buffer> {
  const { meta, lines } = documentLines(row);
  const font = fontPath();
  const logo = logoPath();

  const doc = new PDFDocument({
    size: "A4",
    margin: 48,
    info: {
      Title: meta.titleAr,
      Author: "DAR CAR",
      Creator: "DAR CAR Places",
    },
  });
  const chunks: Buffer[] = [];
  doc.on("data", (c: Buffer) => chunks.push(c));
  const done = new Promise<Buffer>((resolve, reject) => {
    doc.on("end", () => resolve(Buffer.concat(chunks)));
    doc.on("error", reject);
  });

  doc.registerFont("Naskh", font);
  if (logo) {
    try {
      doc.image(logo, doc.page.width - 48 - 72, 36, { width: 72, height: 72 });
    } catch {
      // text mark below is enough
    }
  }
  doc.font("Naskh").fontSize(18);
  doc.text(reshapeRtl("DAR CAR"), 48, 48, {
    width: doc.page.width - 96,
    align: "right",
  });
  doc.moveDown(0.4);
  doc.fontSize(16).text(reshapeRtl(meta.titleAr), {
    width: doc.page.width - 96,
    align: "right",
  });
  doc.moveDown(1);
  doc.fontSize(11);
  for (const line of lines) {
    const value = String(line.value ?? "—");
    if (/[A-Za-z0-9]/.test(value) && !/[\u0600-\u06FF]/.test(value)) {
      doc.text(reshapeRtl(`${line.label}: `) + value, {
        width: doc.page.width - 96,
        align: "right",
      });
    } else {
      doc.text(reshapeRtl(`${line.label}: ${value}`), {
        width: doc.page.width - 96,
        align: "right",
      });
    }
    doc.moveDown(0.35);
  }
  doc.moveDown(0.8);
  doc.fontSize(9).fillColor("#444").text(
    reshapeRtl(
      "هذا المستند ليس فاتورة ضريبية. الفاتورة النظامية لا تصدر إلا بعقد وإصدار حقيقي من مقدم الخدمة.",
    ),
    { width: doc.page.width - 96, align: "right" },
  );
  doc.end();
  return done;
}

export function pdfContainsInternalIds(bytes: Buffer): boolean {
  const ascii = bytes.toString("latin1");
  return /firebase|uid-|consumer_firebase/i.test(ascii);
}

export function isPdfBuffer(bytes: Buffer): boolean {
  return bytes.length > 200 && bytes.subarray(0, 5).toString("utf8") === "%PDF-";
}
