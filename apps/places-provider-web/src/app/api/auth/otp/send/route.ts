import { NextResponse } from "next/server";
import { z } from "zod";
import { CoreApiError, sendOtp } from "@/lib/core/client";
import { normalizePhoneE164 } from "@/lib/auth/phone";
import { authMessageAr } from "@/lib/core/messages";

const bodySchema = z.object({
  phoneE164: z.string().min(6).max(20),
});

export async function POST(request: Request) {
  try {
    const json = await request.json();
    const parsed = bodySchema.parse(json);
    const phoneE164 = normalizePhoneE164(parsed.phoneE164);
    if (!phoneE164) {
      return NextResponse.json(
        { ok: false, error: "رقم الجوال غير صالح" },
        { status: 400 },
      );
    }
    const result = await sendOtp(phoneE164);
    return NextResponse.json({ ok: true, challengeId: result.challengeId });
  } catch (error) {
    if (error instanceof z.ZodError) {
      return NextResponse.json(
        { ok: false, error: "رقم الجوال غير صالح (E.164)" },
        { status: 400 },
      );
    }
    if (error instanceof CoreApiError) {
      return NextResponse.json(
        { ok: false, error: authMessageAr(error.message) },
        { status: error.status },
      );
    }
    return NextResponse.json(
      { ok: false, error: "تعذّر إرسال رمز التحقق" },
      { status: 502 },
    );
  }
}
