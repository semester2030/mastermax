export const SESSION_COOKIE = "places_provider_session";

/** Match Core operator JWT TTL (default 8h Wave1 staging). */
export const SESSION_MAX_AGE_SEC = Number(
  process.env.PLACES_OPERATOR_SESSION_TTL_SEC ?? 28800,
);
