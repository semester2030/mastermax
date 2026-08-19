import { Injectable } from "@nestjs/common";
import { AppError } from "../../../shared/errors/app-error";
import { ErrorCodes } from "../../../shared/errors/error-codes";
import { SendOtpSmsInput, SmsPort } from "../domain/sms.port";

/**
 * Production SMS adapter. Requires PLACES_SMS_WEBHOOK_URL (HTTP POST JSON).
 * Fail-closed when misconfigured — never silently skips delivery.
 */
@Injectable()
export class SmsHttpAdapter implements SmsPort {
  readonly providerName = "http";

  async sendOtpSms(input: SendOtpSmsInput): Promise<{ messageId: string }> {
    const url = (process.env.PLACES_SMS_WEBHOOK_URL ?? "").trim();
    const token = (process.env.PLACES_SMS_WEBHOOK_TOKEN ?? "").trim();
    if (!url) {
      throw new AppError(
        ErrorCodes.INTERNAL,
        "PLACES_SMS_WEBHOOK_URL required for production OTP SMS",
        undefined,
        true,
      );
    }
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), 8_000);
    try {
      const res = await fetch(url, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          ...(token ? { authorization: `Bearer ${token}` } : {}),
        },
        body: JSON.stringify({
          phoneE164: input.phoneE164,
          code: input.code,
          challengeId: input.challengeId,
          correlationId: input.correlationId,
          purpose: "places_otp",
        }),
        signal: ctrl.signal,
      });
      if (!res.ok) {
        throw new AppError(
          ErrorCodes.INTERNAL,
          `OTP SMS provider returned HTTP ${res.status}`,
          { status: res.status },
          true,
        );
      }
      const body = (await res.json().catch(() => ({}))) as { messageId?: string };
      return { messageId: body.messageId ?? `http_sms_${input.challengeId}` };
    } finally {
      clearTimeout(timer);
    }
  }
}
