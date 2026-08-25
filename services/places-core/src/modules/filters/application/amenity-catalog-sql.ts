/** Parse Core amenity_catalog seed rows from migration 006 SQL. */
export function parseAmenityCatalogIconKeysFromSql(sql: string): string[] {
  const keys = new Set<string>();
  const re =
    /gen_random_uuid\(\),\s*'([^']+)',\s*'[^']+',\s*'[^']+',\s*'([^']+)',\s*ARRAY/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(sql)) !== null) {
    keys.add(m[2]);
  }
  return [...keys].sort();
}
