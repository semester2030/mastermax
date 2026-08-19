import { randomUUID } from "node:crypto";

export type CoreRequestHeaders = {
  authorization?: string;
  "Idempotency-Key"?: string;
  "X-Correlation-Id": string;
  "Content-Type"?: string;
};

/** Pure header builder — used by tests; never embeds OTP/phone secrets. */
export function buildCoreHeaders(input: {
  accessToken?: string | null;
  idempotent?: boolean;
  hasJsonBody?: boolean;
  correlationId?: string;
}): CoreRequestHeaders {
  const correlationId = input.correlationId ?? randomUUID();
  const headers: CoreRequestHeaders = {
    "X-Correlation-Id": correlationId,
  };
  if (input.hasJsonBody) {
    headers["Content-Type"] = "application/json";
  }
  if (input.accessToken) {
    headers.authorization = `Bearer ${input.accessToken}`;
  }
  if (input.idempotent) {
    headers["Idempotency-Key"] = randomUUID();
  }
  return headers;
}
