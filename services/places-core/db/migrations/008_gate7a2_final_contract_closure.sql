-- Gate 7A.2 — Final filter contract closure (forward-only; does not rewrite 006/007)
-- Idempotent under schema_migrations (file applied once). Statements use IF NOT EXISTS / safe UPDATEs.

-- ---------------------------------------------------------------------------
-- Amenity tri-state: ONE conversion table for existing links AND legacy backfill
-- explicit true-like → AVAILABLE
-- explicit false-like → NOT_AVAILABLE
-- NULL / blank / unrecognized → UNKNOWN
-- ---------------------------------------------------------------------------
UPDATE venue_amenity_links SET state = CASE
  WHEN lower(trim(coalesce(value, ''))) IN ('true', 'yes', 'available', '1') THEN 'AVAILABLE'
  WHEN lower(trim(coalesce(value, ''))) IN ('false', 'no', 'not_available', '0') THEN 'NOT_AVAILABLE'
  ELSE 'UNKNOWN'
END;

INSERT INTO venue_amenity_links (id, venue_id, amenity_code, scope, value, state)
SELECT gen_random_uuid(), va.venue_id, va.key, 'venue', va.value,
  CASE
    WHEN lower(trim(coalesce(va.value, ''))) IN ('true', 'yes', 'available', '1') THEN 'AVAILABLE'
    WHEN lower(trim(coalesce(va.value, ''))) IN ('false', 'no', 'not_available', '0') THEN 'NOT_AVAILABLE'
    ELSE 'UNKNOWN'
  END
FROM venue_amenities va
JOIN amenity_catalog ac ON ac.code = va.key
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- filter_definitions business-key uniqueness with deterministic duplicate merge
-- Survivor policy: keep the row with earliest created_at, then lowest id::text.
-- Prefer keeping status='active' if mixed; never DELETE custom inactive admin rows
-- unless they are exact key duplicates of another survivor.
-- ---------------------------------------------------------------------------
ALTER TABLE filter_definitions
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();

-- Gate 7A.3 note: incomplete "deactivate-only" reconcile is insufficient for a unique
-- index that covers inactive rows. Non-survivors are archived by key rename (no DELETE).
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

DROP INDEX IF EXISTS uq_filter_definitions_business_key;
CREATE UNIQUE INDEX IF NOT EXISTS uq_filter_definitions_business_key
  ON filter_definitions (key, (COALESCE(venue_type, '')));

-- Ensure room_type stays inactive (no handler)
UPDATE filter_definitions SET status = 'inactive' WHERE key = 'room_type' AND status = 'active';

COMMENT ON COLUMN venue_amenity_links.state IS
  'Gate 7A.2 SSOT tri-state: AVAILABLE|NOT_AVAILABLE|UNKNOWN. NULL/blank/unrecognized => UNKNOWN. Filter matches AVAILABLE only.';
