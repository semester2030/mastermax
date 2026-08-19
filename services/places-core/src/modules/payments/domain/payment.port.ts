export interface CreateIntentInput {
  /** Stable payment row id — REAL PSP adapters MUST use as idempotency key. */
  paymentId: string;
  operationId: string;
  amount: string;
  currency: string;
  holdId: string;
}

export interface CreateIntentResult {
  pspIntentId: string;
  clientSecretOrUrl: string;
}

export interface RefundInput {
  pspIntentId: string;
  amount: string;
  /** Stable refund row id — REAL PSP adapters MUST use as idempotency key. */
  operationId: string;
}

export interface WebhookEnvelope {
  eventId: string;
  type: "payment.succeeded" | "payment.failed" | "refund.completed";
  pspIntentId: string;
  refundId?: string;
  raw: unknown;
}

/**
 * REAL PSP ADAPTER MUST SUPPORT IDEMPOTENT CREATE OR RECONCILIATION.
 * createIntent / refund MUST NOT create duplicate PSP side-effects when called
 * twice with the same operationId/paymentId.
 */
export interface PaymentPort {
  readonly pspName: string;
  createIntent(input: CreateIntentInput): Promise<CreateIntentResult>;
  verifySignature(rawBody: string, signature: string | undefined): boolean;
  parseWebhook(rawBody: string): WebhookEnvelope;
  refund(input: RefundInput): Promise<{ pspRefundId: string }>;
}

export const PAYMENT_PORT = Symbol("PAYMENT_PORT");
