import { NextResponse } from "next/server";
import { z } from "zod";
import {
  clearSessionCookie,
  getSessionClaims,
  getSessionToken,
  setSessionCookie,
} from "@/lib/auth/session";
import { CoreApiError, logoutCore, verifyOtp } from "@/lib/core/client";
import { authMessageAr } from "@/lib/core/messages";

const verifySchema = z.object({
  challengeId: z.string().min(8),
  code: z.string().regex(/^\d{4,8}$/),
});

export async function POST(request: Request) {
  try {
    const json = await request.json();
    const { challengeId, code } = verifySchema.parse(json);
    const result = await verifyOtp({ challengeId, code });
    await setSessionCookie(result.accessToken);
    return NextResponse.json({
      ok: true,
      onBehalfOfProviderId: result.onBehalfOfProviderId,
      expiresInSec: result.expiresInSec,
    });
  } catch (error) {
    if (error instanceof z.ZodError) {
      return NextResponse.json(
        { ok: false, error: "بيانات التحقق غير صالحة" },
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
      { ok: false, error: "تعذّر إنشاء الجلسة" },
      { status: 502 },
    );
  }
}

export async function GET() {
  const claims = await getSessionClaims();
  if (!claims) {
    return NextResponse.json(
      { ok: false, authenticated: false },
      { status: 401 },
    );
  }
  return NextResponse.json({
    ok: true,
    authenticated: true,
    onBehalfOfProviderId: claims.onBehalfOfProviderId ?? null,
    exp: claims.exp ?? null,
  });
}

export async function DELETE() {
  const token = await getSessionToken();
  if (token) {
    try {
      await logoutCore(token);
    } catch {
      // Still clear local cookie even if Core logout fails.
    }
  }
  await clearSessionCookie();
  return NextResponse.json({ ok: true, signedOut: true });
}
