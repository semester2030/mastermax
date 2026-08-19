export const BookingStatuses = [
  "HOLDING",
  "PENDING_PAYMENT",
  "CONFIRMED",
  "ACTIVE",
  "COMPLETED",
  "CANCELLED",
  "PAYMENT_FAILED",
  "EXPIRED",
  "REFUND_PENDING",
  "REFUNDED",
  "NO_SHOW",
  "DISPUTED",
] as const;

export type BookingStatus = (typeof BookingStatuses)[number];

export const HoldStatuses = [
  "ACTIVE",
  "CONVERTED",
  "EXPIRED",
  "RELEASED",
] as const;
export type HoldStatus = (typeof HoldStatuses)[number];

const ALLOWED: Record<string, BookingStatus[]> = {
  "": ["HOLDING"],
  HOLDING: ["PENDING_PAYMENT", "CONFIRMED", "EXPIRED", "CANCELLED"],
  PENDING_PAYMENT: ["CONFIRMED", "EXPIRED", "PAYMENT_FAILED"],
  CONFIRMED: [
    "ACTIVE",
    "COMPLETED",
    "CANCELLED",
    "REFUND_PENDING",
    "NO_SHOW",
    "DISPUTED",
  ],
  ACTIVE: ["COMPLETED", "CANCELLED", "REFUND_PENDING", "DISPUTED"],
  COMPLETED: ["REFUND_PENDING", "DISPUTED"],
  REFUND_PENDING: ["REFUNDED", "DISPUTED"],
  // Retry: PAYMENT_FAILED → PENDING_PAYMENT while hold still ACTIVE (payment.service).
  PAYMENT_FAILED: ["EXPIRED", "PENDING_PAYMENT"],
  CANCELLED: ["REFUND_PENDING"],
  EXPIRED: [],
  REFUNDED: [],
  NO_SHOW: ["DISPUTED", "REFUND_PENDING"],
  DISPUTED: ["REFUND_PENDING"],
};

export function canTransition(
  from: BookingStatus | "",
  to: BookingStatus,
): boolean {
  return (ALLOWED[from] ?? []).includes(to);
}
