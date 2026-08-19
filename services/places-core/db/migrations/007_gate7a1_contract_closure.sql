-- Gate 7A.1 — Filter Engine Correctness & Contract Closure
-- Additive / non-destructive. Does NOT rewrite 006 history.
-- Local/Test: applied via migrate.ts. No production places-core deploy known at authoring time;
-- still shipped as forward migration for safety.

-- ---------------------------------------------------------------------------
-- Amenity tri-state SSOT on venue_amenity_links
-- ---------------------------------------------------------------------------
ALTER TABLE venue_amenity_links
  ADD COLUMN IF NOT EXISTS state TEXT NOT NULL DEFAULT 'UNKNOWN'
    CHECK (state IN ('AVAILABLE', 'NOT_AVAILABLE', 'UNKNOWN'));

UPDATE venue_amenity_links SET state = CASE
  WHEN lower(coalesce(value, '')) IN ('true', 'yes', 'available', '1') THEN 'AVAILABLE'
  WHEN lower(coalesce(value, '')) IN ('false', 'no', 'not_available', '0') THEN 'NOT_AVAILABLE'
  WHEN value IS NULL OR trim(value) = '' THEN 'AVAILABLE'
  ELSE 'UNKNOWN'
END;

-- Re-backfill from legacy with explicit tri-state (preserve existing link rows)
INSERT INTO venue_amenity_links (id, venue_id, amenity_code, scope, value, state)
SELECT gen_random_uuid(), va.venue_id, va.key, 'venue', va.value,
  CASE
    WHEN lower(coalesce(va.value, '')) IN ('true', 'yes', 'available', '1') THEN 'AVAILABLE'
    WHEN lower(coalesce(va.value, '')) IN ('false', 'no', 'not_available', '0') THEN 'NOT_AVAILABLE'
    WHEN va.value IS NULL OR trim(va.value) = '' THEN 'UNKNOWN'
    ELSE 'UNKNOWN'
  END
FROM venue_amenities va
JOIN amenity_catalog ac ON ac.code = va.key
ON CONFLICT DO NOTHING;

CREATE INDEX IF NOT EXISTS idx_venue_amenity_links_available
  ON venue_amenity_links (amenity_code, venue_id)
  WHERE state = 'AVAILABLE';

-- ---------------------------------------------------------------------------
-- Filter definitions: business key + deactivate unimplemented ACTIVE filters
-- ---------------------------------------------------------------------------
ALTER TABLE filter_definitions
  ADD COLUMN IF NOT EXISTS options_source TEXT NOT NULL DEFAULT 'static'
    CHECK (options_source IN ('static', 'dynamic', 'none'));

-- ---------------------------------------------------------------------------
-- GATE 7A.3 DOCUMENTED CORRECTION (before any permanent deploy of failing form):
-- Unique index covers BOTH active and inactive rows. Merely setting status=inactive
-- on duplicates still leaves colliding business keys. Survivor policy:
--   prefer status=active, then earliest created_at, then lowest id::text.
-- Non-survivors are ARCHIVED by renaming key → key__dup_<id> (no DELETE).
-- See docs/places_core_gate7a3/MIGRATION_009_UPGRADE_PROOF.md
-- ---------------------------------------------------------------------------
ALTER TABLE filter_definitions
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();

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

-- Unique business key: (key, venue_type_scope) where NULL venue_type → ''
CREATE UNIQUE INDEX IF NOT EXISTS uq_filter_definitions_business_key
  ON filter_definitions (key, (COALESCE(venue_type, '')));

-- Deactivate filters without real handlers (no silent UI filters)
UPDATE filter_definitions
SET status = 'inactive'
WHERE key IN ('room_type')
  AND status = 'active';

-- size_sqm + inventory_kind stay active — handlers implemented in Gate 7A.1
-- City options: dynamic from published venues (not hardcoded Riyadh/Jeddah/Dammam)
UPDATE filter_definitions
SET options_json = '[]'::jsonb,
    options_source = 'dynamic'
WHERE key = 'city' AND venue_type IS NULL;

UPDATE filter_definitions
SET options_source = 'dynamic'
WHERE key = 'district' AND venue_type IS NULL;

-- ---------------------------------------------------------------------------
-- Intents: only ACTIVE if fully expandable to implemented filters
-- ---------------------------------------------------------------------------
UPDATE intent_presets SET status = 'inactive'
WHERE code IN ('weekend', 'luxury', 'budget', 'long_stay');

-- Remove silent guestsMax overwrite payloads; keep amenities / guestsMin only
UPDATE intent_presets
SET expands_to_jsonb = '{"amenities":["honeymoon","privacy"],"guestsMin":2}'::jsonb
WHERE code = 'honeymoon';

UPDATE intent_presets
SET expands_to_jsonb = '{"amenities":["long_stay"]}'::jsonb,
    status = 'inactive'
WHERE code = 'long_stay';

COMMENT ON TABLE event_slot_inventory IS
  'Gate 7A.1: UNIQUE(template,date) is NOT full overlap protection. Wedding/Event BOOKING_NOT_READY — follow-up for window overlap, holds, races, pricing.';

COMMENT ON COLUMN venue_type_capabilities.enabled_for_booking IS
  'When false: block NEW quote/hold/payment for that type. Existing bookings remain viewable/cancellable. wedding_palace/event_hall = DISCOVERY_READY + BOOKING_NOT_READY until dedicated gate.';
