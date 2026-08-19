import { createHmac, timingSafeEqual } from "crypto";
import { Injectable, Inject } from "@nestjs/common";
import { APP_CONFIG } from "../../../shared/config/app-config";
import { AppEnv } from "../../../shared/config/env";
import {
  CreateIntentInput,
  CreateIntentResult,
  PaymentPort,
  RefundInput,
  WebhookEnvelope,
} from "../domain/payment.port";

/**
 * Documented OPEN DECISION stub (OD-PSP). Swap adapter only when a real PSP is chosen.
 * Idempotent: pspIntentId derived from paymentId; pspRefundId derived from operationId.
 * Webhook header: X-Stub-Signature = hex HMAC-SHA256 of raw body with STUB_WEBHOOK_SECRET.
 */
@Injectable()
export class PaymentStubAdapter implements PaymentPort {
  readonly pspName = "stub";

  constructor(@Inject(APP_CONFIG) private readonly env: AppEnv) {}

  private assertNotProduction(): void {
    if (this.env.nodeEnv === "production") {
      throw new Error(
        "FATAL: PaymentStubAdapter is forbidden when NODE_ENV=production (fail-closed)",
      );
    }
  }

  async createIntent(input: CreateIntentInput): Promise<CreateIntentResult> {
    this.assertNotProduction();
    const pspIntentId = `stub_pi_${input.paymentId}`;
    return {
      pspIntentId,
      clientSecretOrUrl: `stub://pay/${pspIntentId}`,
    };
  }

  verifySignature(rawBody: string, signature: string | undefined): boolean {
    this.assertNotProduction();
    if (!signature) {
      return false;
    }
    const expected = createHmac("sha256", this.env.stubWebhookSecret)
      .update(rawBody)
      .digest("hex");
    const a = Buffer.from(expected);
    const b = Buffer.from(signature);
    if (a.length !== b.length || !timingSafeEqual(a, b)) {
      return false;
    }
    try {
      const body = JSON.parse(rawBody) as { ts?: number };
      if (typeof body.ts === "number") {
        const skew = Math.abs(Math.floor(Date.now() / 1000) - body.ts);
        if (skew > this.env.webhookMaxSkewSeconds) {
          return false;
        }
      }
    } catch {
      return false;
    }
    return true;
  }

  parseWebhook(rawBody: string): WebhookEnvelope {
    this.assertNotProduction();
    const body = JSON.parse(rawBody) as {
      eventId: string;
      type: WebhookEnvelope["type"];
      pspIntentId: string;
      refundId?: string;
    };
    return { ...body, raw: body };
  }

  async refund(input: RefundInput): Promise<{ pspRefundId: string }> {
    this.assertNotProduction();
    return { pspRefundId: `stub_re_${input.operationId}` };
  }
}
