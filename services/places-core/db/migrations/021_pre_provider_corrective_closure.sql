-- Gate PRE-PROVIDER REV3 — Migration 021 (non-destructive to 001–020).
-- Corrective closure: NULL-unit availability uniqueness, payments.current_attempt_id,
-- soft-delete-aware media denorm, CF delete outbox claim columns.

-- ---------------------------------------------------------------------------
-- 1) Type-level availability_overrides uniqueness (PG UNIQUE treats NULL ≠ NULL)
-- ---------------------------------------------------------------------------
-- Dedupe duplicates keeping oldest (by created order ≈ ctid / id).
WITH ranked AS (
  SELECT id,
         ROW_NUMBER() OVER (
           PARTITION BY inventory_type_id, date, kind
           ORDER BY id
         ) AS rn
  FROM availability_overrides
  WHERE inventory_unit_id IS NULL
)
DELETE FROM availability_overrides a
USING ranked r
WHERE a.id = r.id AND r.rn > 1;

CREATE UNIQUE INDEX IF NOT EXISTS uq_availability_overrides_type_date_kind_null_unit
  ON availability_overrides (inventory_type_id, date, kind)
  WHERE inventory_unit_id IS NULL;

-- ---------------------------------------------------------------------------
-- 2) payments.current_attempt_id (payment attempt identity for webhooks)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'payment_attempts'
  ) AND EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'payments'
  ) THEN
    ALTER TABLE payments
      ADD COLUMN IF NOT EXISTS current_attempt_id UUID REFERENCES payment_attempts (id);
  END IF;
END $$;

-- ---------------------------------------------------------------------------
-- 3) Soft-delete-aware denorm refresh (017 body + deleted_at IS NULL)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION places_refresh_venue_media_denorm(vid UUID)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
  IF vid IS NULL THEN
    RETURN;
  END IF;
  UPDATE venues
  SET has_playable_video = EXISTS (
    SELECT 1 FROM venue_media m
    WHERE m.venue_id = vid
      AND m.kind = 'video'
      AND m.moderation_status = 'approved'
      AND m.deleted_at IS NULL
      AND (
        (m.stream_uid IS NOT NULL AND btrim(m.stream_uid) <> '')
        OR (m.url IS NOT NULL AND btrim(m.url) <> '' AND m.url ~* '^https://')
      )
  ),
  indicative_starting_price = (
    SELECT MIN(m.starting_price_hint) FROM venue_media m
    WHERE m.venue_id = vid
      AND m.moderation_status = 'approved'
      AND m.deleted_at IS NULL
      AND m.starting_price_hint IS NOT NULL
  )
  WHERE id = vid;
END;
$$;

-- 017 trigger is AFTER INSERT OR UPDATE OR DELETE (no OF list) — UPDATE of deleted_at
-- already fires denorm. Reaffirm trigger exists for soft-delete path.
DROP TRIGGER IF EXISTS trg_venue_media_playable_video ON venue_media;
CREATE TRIGGER trg_venue_media_playable_video
AFTER INSERT OR UPDATE OR DELETE ON venue_media
FOR EACH ROW
EXECUTE FUNCTION places_refresh_venue_playable_video();

-- Reconcile all venues under media write lock.
DO $$
DECLARE
  fixed_count integer := 0;
  t0 timestamptz := clock_timestamp();
  elapsed_ms numeric;
BEGIN
  LOCK TABLE venue_media IN SHARE ROW EXCLUSIVE MODE;

  UPDATE venues v
  SET
    has_playable_video = sub.playable,
    indicative_starting_price = sub.price
  FROM (
    SELECT
      v2.id,
      EXISTS (
        SELECT 1 FROM venue_media m
        WHERE m.venue_id = v2.id
          AND m.kind = 'video'
          AND m.moderation_status = 'approved'
          AND m.deleted_at IS NULL
          AND (
            (m.stream_uid IS NOT NULL AND btrim(m.stream_uid) <> '')
            OR (m.url IS NOT NULL AND btrim(m.url) <> '' AND m.url ~* '^https://')
          )
      ) AS playable,
      (
        SELECT MIN(m.starting_price_hint) FROM venue_media m
        WHERE m.venue_id = v2.id
          AND m.moderation_status = 'approved'
          AND m.deleted_at IS NULL
          AND m.starting_price_hint IS NOT NULL
      ) AS price
    FROM venues v2
  ) sub
  WHERE v.id = sub.id
    AND (
      v.has_playable_video IS DISTINCT FROM sub.playable
      OR v.indicative_starting_price IS DISTINCT FROM sub.price
    );

  GET DIAGNOSTICS fixed_count = ROW_COUNT;
  elapsed_ms := ROUND(EXTRACT(EPOCH FROM (clock_timestamp() - t0)) * 1000.0, 3);
  RAISE NOTICE 'REV3_021_DENORM_RECONCILE fixed_rows=% elapsed_ms=%',
    fixed_count, elapsed_ms;
END $$;

-- Explicit per-venue refresh (same result; documents call-site requirement).
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN SELECT id FROM venues LOOP
    PERFORM places_refresh_venue_media_denorm(r.id);
  END LOOP;
END $$;

-- ---------------------------------------------------------------------------
-- 4) media_cf_delete_outbox claim / backoff columns (crash-safe worker)
-- ---------------------------------------------------------------------------
ALTER TABLE media_cf_delete_outbox
  ADD COLUMN IF NOT EXISTS claimed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS claim_token UUID,
  ADD COLUMN IF NOT EXISTS next_attempt_at TIMESTAMPTZ;

-- attempts already in 020; ensure present for older partial applies
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'media_cf_delete_outbox'
      AND column_name = 'attempts'
  ) THEN
    ALTER TABLE media_cf_delete_outbox
      ADD COLUMN attempts INT NOT NULL DEFAULT 0;
  END IF;
END $$;

UPDATE media_cf_delete_outbox
SET next_attempt_at = COALESCE(next_attempt_at, created_at)
WHERE status = 'pending' AND next_attempt_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_media_cf_delete_outbox_claim
  ON media_cf_delete_outbox (status, next_attempt_at)
  WHERE status = 'pending';
