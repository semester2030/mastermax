import assert from "node:assert/strict";
import test from "node:test";
import { buildCoreHeaders } from "../src/lib/core/headers.ts";
import { decodeJwtPayload } from "../src/lib/auth/jwt.ts";

test("buildCoreHeaders sets Idempotency-Key uuid for mutating calls", () => {
  const headers = buildCoreHeaders({
    accessToken: "tok.aaa.bbb",
    idempotent: true,
    hasJsonBody: true,
    correlationId: "corr-1",
  });
  assert.equal(headers["X-Correlation-Id"], "corr-1");
  assert.equal(headers.authorization, "Bearer tok.aaa.bbb");
  assert.equal(headers["Content-Type"], "application/json");
  assert.match(
    headers["Idempotency-Key"] ?? "",
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i,
  );
});

test("buildCoreHeaders never embeds OTP or phone secrets", () => {
  const headers = buildCoreHeaders({
    accessToken: "access",
    idempotent: true,
    hasJsonBody: true,
  });
  const serialized = JSON.stringify(headers);
  assert.equal(serialized.includes("PLACES_OTP"), false);
  assert.equal(serialized.includes("FIXED_CODE"), false);
  assert.equal(serialized.includes("DAR_CAR_INTERNAL_OPERATOR_PHONE"), false);
  assert.equal(serialized.includes("phoneE164"), false);
  assert.equal("otp" in headers, false);
  assert.equal("phone" in headers, false);
});

test("decodeJwtPayload reads onBehalfOfProviderId without secrets", () => {
  const payload = Buffer.from(
    JSON.stringify({
      onBehalfOfProviderId: "11111111-1111-4111-8111-111111111111",
      aud: "places-provider-web",
    }),
  ).toString("base64url");
  const token = `eyJhbGciOiJIUzI1NiJ9.${payload}.sig`;
  const decoded = decodeJwtPayload(token);
  assert.equal(
    decoded?.onBehalfOfProviderId,
    "11111111-1111-4111-8111-111111111111",
  );
  assert.equal(JSON.stringify(decoded).includes("secret"), false);
});
