import { Injectable } from "@nestjs/common";
import { AppError } from "../../../shared/errors/app-error";
import { ErrorCodes } from "../../../shared/errors/error-codes";
import {
  CreateIntentInput,
  CreateIntentResult,
  PaymentPort,
  RefundInput,
  WebhookEnvelope,
} from "../domain/payment.port";

/**
 * Phase 4 production-safe PaymentPort when PAYMENT_PROVIDER=pav_only.
 * Fail-closed: every PSP surface (intent / webhook / refund / capture) rejects
 * with a fixed error and performs ZERO side effects (no DB writes here).
 */
@Injectable()
export class PavOnlyPaymentAdapter implements PaymentPort {
  readonly pspName = "pav_only";

  private refuse(op: string): never {
    throw new AppError(
      ErrorCodes.PAYMENT_REQUIRED,
      `PAYMENT_PROVIDER=pav_only refuses PSP operation: ${op}`,
      { provider: "pav_only", operation: op },
    );
  }

  async createIntent(_input: CreateIntentInput): Promise<CreateIntentResult> {
    this.refuse("createIntent");
  }

  verifySignature(
    _rawBody: string,
    _signature: string | undefined,
  ): boolean {
    this.refuse("verifySignature");
  }

  parseWebhook(_rawBody: string): WebhookEnvelope {
    this.refuse("parseWebhook");
  }

  async refund(_input: RefundInput): Promise<{ pspRefundId: string }> {
    this.refuse("refund");
  }
}
