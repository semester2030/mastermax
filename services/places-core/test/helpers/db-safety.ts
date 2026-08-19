/**
 * Destructive DB safety for Jest / migration harnesses.
 * Staging (`places_core_test`) and any non-`*_ci` database are hard-refused.
 */
import { Pool } from "pg";

export function dbNameFromDatabaseUrl(url: string): string {
  const u = new URL(url);
  return decodeURIComponent((u.pathname || "/").replace(/^\//, "")).toLowerCase();
}

/**
 * Only databases whose name ends with `_ci` may be DROP SCHEMA / TRUNCATE / reset.
 * Throws synchronously — never returns for staging or production-like names.
 */
export function assertCiDatabaseUrl(url = process.env.DATABASE_URL): string {
  if (!url?.trim()) {
    throw new Error("REFUSED: DATABASE_URL required for destructive DB ops");
  }
  const name = dbNameFromDatabaseUrl(url);
  if (!name) {
    throw new Error("REFUSED: empty database name in DATABASE_URL");
  }
  if (name === "places_core_test") {
    throw new Error(
      "REFUSED: places_core_test is Wave1 staging — Jest must use places_core_ci",
    );
  }
  if (name.includes("prod") || name.includes("production")) {
    throw new Error(`REFUSED: production-like database "${name}"`);
  }
  if (!name.endsWith("_ci")) {
    throw new Error(
      `REFUSED: destructive DB ops only on databases ending with _ci (got "${name}")`,
    );
  }
  return url;
}

/** DROP SCHEMA public CASCADE — refused unless DATABASE_URL ends with `_ci`. */
export async function dropPublicSchemaForCi(
  pool: Pool,
  url = process.env.DATABASE_URL,
): Promise<void> {
  assertCiDatabaseUrl(url);
  await pool.query("DROP SCHEMA public CASCADE; CREATE SCHEMA public;");
}
