import { cookies } from "next/headers";
import { SESSION_COOKIE, SESSION_MAX_AGE_SEC } from "@/lib/auth/constants";
import { decodeJwtPayload, providerIdFromToken } from "@/lib/auth/jwt";

export async function getSessionToken(): Promise<string | null> {
  const jar = await cookies();
  return jar.get(SESSION_COOKIE)?.value ?? null;
}

export async function getSessionProviderId(): Promise<string | null> {
  const token = await getSessionToken();
  if (!token) return null;
  return providerIdFromToken(token);
}

export async function getSessionClaims() {
  const token = await getSessionToken();
  if (!token) return null;
  return decodeJwtPayload(token);
}

export async function setSessionCookie(accessToken: string): Promise<void> {
  const jar = await cookies();
  const claims = decodeJwtPayload(accessToken);
  const maxAge =
    claims?.exp && claims?.iat
      ? Math.max(60, claims.exp - claims.iat)
      : SESSION_MAX_AGE_SEC;

  jar.set(SESSION_COOKIE, accessToken, {
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    path: "/",
    maxAge,
  });
}

export async function clearSessionCookie(): Promise<void> {
  const jar = await cookies();
  jar.set(SESSION_COOKIE, "", {
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    path: "/",
    maxAge: 0,
  });
}
