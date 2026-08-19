/**
 * Decode JWT payload without verifying signature.
 * Display / routing hints only — Core still authorizes every request.
 */
export type OperatorJwtPayload = {
  iss?: string;
  aud?: string;
  sub?: string;
  claim?: string;
  onBehalfOfProviderId?: string;
  jti?: string;
  iat?: number;
  exp?: number;
};

export function decodeJwtPayload(token: string): OperatorJwtPayload | null {
  const parts = token.split(".");
  if (parts.length !== 3) return null;
  try {
    const json = Buffer.from(parts[1]!, "base64url").toString("utf8");
    const payload = JSON.parse(json) as OperatorJwtPayload;
    return payload && typeof payload === "object" ? payload : null;
  } catch {
    return null;
  }
}

export function providerIdFromToken(token: string): string | null {
  const payload = decodeJwtPayload(token);
  const id = payload?.onBehalfOfProviderId;
  return typeof id === "string" && id.length > 0 ? id : null;
}
