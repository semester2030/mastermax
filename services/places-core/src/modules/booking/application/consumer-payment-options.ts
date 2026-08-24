export type ConsumerPaymentOptions = {
  payAtVenue: boolean;
  availableMethods: string[];
};

/** Same runtime gate as Pay-at-Venue confirm (env + optional provider allowlist). */
export function resolveConsumerPaymentOptions(providerId?: string | null): ConsumerPaymentOptions {
  const enabled = process.env.PLACES_PAY_AT_VENUE_ENABLED === "true";
  const allowlist = (process.env.PLACES_PAY_AT_VENUE_PROVIDER_ALLOWLIST ?? "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
  const allowlisted =
    allowlist.length === 0 ||
    (typeof providerId === "string" &&
      providerId.length > 0 &&
      allowlist.includes(providerId));
  const payAtVenue = enabled && allowlisted;
  return {
    payAtVenue,
    availableMethods: payAtVenue ? ["PAY_AT_VENUE"] : [],
  };
}
