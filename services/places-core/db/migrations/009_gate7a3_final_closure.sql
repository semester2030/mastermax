-- Gate 7A.3 — Final migration/capability closure (forward-only)
-- Does not rewrite 006. Complements documented 007 correction + 008.
-- Idempotent under schema_migrations.

-- Ensure created_at exists (may already from 007/008)
ALTER TABLE filter_definitions
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();

-- ---------------------------------------------------------------------------
-- Survivor / merge policy (deterministic, non-destructive):
-- Partition: (key, COALESCE(venue_type,'')) excluding already-archived __dup_ keys.
-- Keep rn=1: prefer active, then earliest created_at, then lowest id::text.
-- Non-survivors: rename key to '<key>__dup_<uuid_without_dashes>', set inactive.
-- Never DELETE custom admin definitions.
-- ---------------------------------------------------------------------------
WITH ranked AS (
  SELECT id,
         ROW_NUMBER() OVER (
           PARTITION BY key, COALESCE(venue_type, '')
           ORDER BY
             CASE WHEN status = 'active' THEN 0 ELSE 1 END,
             created_at ASC NULLS LAST,
             id::text ASC
         ) AS rn
  FROM filter_definitions
  WHERE key NOT LIKE '%__dup_%'
)
UPDATE filter_definitions fd
SET
  key = left(fd.key, 160) || '__dup_' || replace(fd.id::text, '-', ''),
  status = 'inactive'
FROM ranked r
WHERE fd.id = r.id AND r.rn > 1;

-- Recreate unique index safely after full reconciliation (active + inactive)
DROP INDEX IF EXISTS uq_filter_definitions_business_key;
CREATE UNIQUE INDEX IF NOT EXISTS uq_filter_definitions_business_key
  ON filter_definitions (key, (COALESCE(venue_type, '')));

-- room_type remains inactive (no handler)
UPDATE filter_definitions SET status = 'inactive' WHERE key = 'room_type' AND status = 'active';

COMMENT ON INDEX uq_filter_definitions_business_key IS
  'Gate 7A.3: unique after archive-rename of duplicate business keys; survivors preferred active then earliest created_at.';
