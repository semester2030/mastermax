-- PRE-PROVIDER REV4 Batch 1 corrective schema (booking / payments / availability).
-- Idempotent: safe to re-run / merge with peer edits to this file (media agents may append).

-- ---------------------------------------------------------------------------
-- F-REV4-01: Hold idempotency scoped by consumer (not global UNIQUE)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'booking_holds_idempotency_key_key'
      AND conrelid = 'booking_holds'::regclass
  ) THEN
    ALTER TABLE booking_holds DROP CONSTRAINT booking_holds_idempotency_key_key;
  END IF;
END $$;

-- Retire duplicate keys if any (keep earliest row per consumer+key).
UPDATE booking_holds h
SET idempotency_key = h.idempotency_key || '#retired#' || h.id::text
WHERE h.id IN (
  SELECT id FROM (
    SELECT id,
           ROW_NUMBER() OVER (
             PARTITION BY consumer_firebase_uid, idempotency_key
             ORDER BY created_at ASC, id ASC
           ) AS rn
    FROM booking_holds
  ) d
  WHERE d.rn > 1
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_booking_holds_consumer_idempotency
  ON booking_holds (consumer_firebase_uid, idempotency_key);

-- ---------------------------------------------------------------------------
-- F-REV4-09: event_slot support on quote/hold/booking (slot_code)
-- venues.booking_mode already allows event_slot (migration 006).
-- ---------------------------------------------------------------------------
ALTER TABLE quotes
  ADD COLUMN IF NOT EXISTS slot_code TEXT NULL;

ALTER TABLE booking_holds
  ADD COLUMN IF NOT EXISTS slot_code TEXT NULL;

ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS slot_code TEXT NULL;

COMMENT ON COLUMN quotes.slot_code IS
  'event_slot booking: template code (e.g. evening). NULL for nightly/daily.';
COMMENT ON COLUMN booking_holds.slot_code IS
  'Copied from quote at hold create for event_slot stays.';
COMMENT ON COLUMN bookings.slot_code IS
  'Copied from quote/hold for event_slot confirmed stays.';

-- ---------------------------------------------------------------------------
-- F-REV4-04/05: Durable refund actor+key for admin/cancel reclaim safety
-- ---------------------------------------------------------------------------
ALTER TABLE refunds
  ADD COLUMN IF NOT EXISTS actor_uid TEXT NULL;

ALTER TABLE refunds
  ADD COLUMN IF NOT EXISTS idempotency_key TEXT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_refunds_actor_idempotency
  ON refunds (actor_uid, idempotency_key)
  WHERE idempotency_key IS NOT NULL;

-- ===========================================================================
-- MEDIA / CLOUDFLARE (REV4 Batch 2) — F-REV4-12…17
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- F-REV4-15: Unique live Cloudflare assets (non-deleted rows only)
-- Soft-delete duplicates keeping earliest row per id.
-- ---------------------------------------------------------------------------
WITH ranked_img AS (
  SELECT id,
         ROW_NUMBER() OVER (
           PARTITION BY cloudflare_image_id
           ORDER BY created_at ASC NULLS LAST, id ASC
         ) AS rn
  FROM venue_media
  WHERE cloudflare_image_id IS NOT NULL
    AND btrim(cloudflare_image_id) <> ''
    AND deleted_at IS NULL
)
UPDATE venue_media m
SET deleted_at = now(), is_cover = FALSE
FROM ranked_img r
WHERE m.id = r.id AND r.rn > 1;

WITH ranked_stream AS (
  SELECT id,
         ROW_NUMBER() OVER (
           PARTITION BY stream_uid
           ORDER BY created_at ASC NULLS LAST, id ASC
         ) AS rn
  FROM venue_media
  WHERE stream_uid IS NOT NULL
    AND btrim(stream_uid) <> ''
    AND deleted_at IS NULL
)
UPDATE venue_media m
SET deleted_at = now(), is_cover = FALSE
FROM ranked_stream r
WHERE m.id = r.id AND r.rn > 1;

CREATE UNIQUE INDEX IF NOT EXISTS uq_venue_media_live_cloudflare_image_id
  ON venue_media (cloudflare_image_id)
  WHERE cloudflare_image_id IS NOT NULL
    AND btrim(cloudflare_image_id) <> ''
    AND deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_venue_media_live_stream_uid
  ON venue_media (stream_uid)
  WHERE stream_uid IS NOT NULL
    AND btrim(stream_uid) <> ''
    AND deleted_at IS NULL;

-- ---------------------------------------------------------------------------
-- F-REV4-13: Independent image caps 1–30 (pending+approved, non-deleted)
-- Reaffirm venue-level and inventory_type scopes; sessions reserve quota.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION places_enforce_venue_image_cap()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  cnt INT;
BEGIN
  IF NEW.kind <> 'image' OR NEW.inventory_type_id IS NOT NULL THEN
    RETURN NEW;
  END IF;
  IF NEW.deleted_at IS NOT NULL THEN
    RETURN NEW;
  END IF;
  IF NEW.moderation_status NOT IN ('pending', 'approved') THEN
    RETURN NEW;
  END IF;
  SELECT COUNT(*)::int INTO cnt
  FROM venue_media
  WHERE venue_id = NEW.venue_id
    AND kind = 'image'
    AND inventory_type_id IS NULL
    AND deleted_at IS NULL
    AND moderation_status IN ('pending', 'approved')
    AND id IS DISTINCT FROM NEW.id;
  IF cnt >= 30 THEN
    RAISE EXCEPTION 'VENUE_IMAGE_CAP: max 30 pending+approved venue images'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION places_enforce_inventory_type_image_cap()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  cnt INT;
BEGIN
  IF NEW.kind <> 'image' OR NEW.inventory_type_id IS NULL THEN
    RETURN NEW;
  END IF;
  IF NEW.deleted_at IS NOT NULL THEN
    RETURN NEW;
  END IF;
  IF NEW.moderation_status NOT IN ('pending', 'approved') THEN
    RETURN NEW;
  END IF;
  SELECT COUNT(*)::int INTO cnt
  FROM venue_media
  WHERE inventory_type_id = NEW.inventory_type_id
    AND kind = 'image'
    AND deleted_at IS NULL
    AND moderation_status IN ('pending', 'approved')
    AND id IS DISTINCT FROM NEW.id;
  IF cnt >= 30 THEN
    RAISE EXCEPTION 'INVENTORY_TYPE_IMAGE_CAP: max 30 pending+approved images per inventory_type'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_venue_media_image_cap_venue ON venue_media;
CREATE TRIGGER trg_venue_media_image_cap_venue
BEFORE INSERT OR UPDATE OF kind, moderation_status, inventory_type_id, venue_id, deleted_at
ON venue_media
FOR EACH ROW
EXECUTE FUNCTION places_enforce_venue_image_cap();

DROP TRIGGER IF EXISTS trg_venue_media_image_cap_inventory_type ON venue_media;
CREATE TRIGGER trg_venue_media_image_cap_inventory_type
BEFORE INSERT OR UPDATE OF kind, moderation_status, inventory_type_id, deleted_at
ON venue_media
FOR EACH ROW
EXECUTE FUNCTION places_enforce_inventory_type_image_cap();

-- Expire stale pending image sessions in scope (frees quota reservation).
CREATE OR REPLACE FUNCTION places_expire_stale_image_upload_sessions(
  p_venue_id UUID,
  p_inventory_type_id UUID
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
  n INT;
BEGIN
  UPDATE media_upload_sessions
  SET status = 'expired'
  WHERE status = 'pending'
    AND kind = 'image'
    AND expires_at < now()
    AND venue_id = p_venue_id
    AND (
      (p_inventory_type_id IS NULL AND inventory_type_id IS NULL)
      OR (p_inventory_type_id IS NOT NULL AND inventory_type_id = p_inventory_type_id)
    );
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END;
$$;

-- Quota = live media (pending+approved) + non-expired pending upload sessions.
CREATE OR REPLACE FUNCTION places_image_quota_used(
  p_venue_id UUID,
  p_inventory_type_id UUID
)
RETURNS INT
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  media_cnt INT;
  sess_cnt INT;
BEGIN
  IF p_inventory_type_id IS NOT NULL THEN
    SELECT COUNT(*)::int INTO media_cnt
    FROM venue_media
    WHERE inventory_type_id = p_inventory_type_id
      AND kind = 'image'
      AND deleted_at IS NULL
      AND moderation_status IN ('pending', 'approved');
    SELECT COUNT(*)::int INTO sess_cnt
    FROM media_upload_sessions
    WHERE inventory_type_id = p_inventory_type_id
      AND kind = 'image'
      AND status = 'pending'
      AND expires_at >= now();
  ELSE
    SELECT COUNT(*)::int INTO media_cnt
    FROM venue_media
    WHERE venue_id = p_venue_id
      AND inventory_type_id IS NULL
      AND kind = 'image'
      AND deleted_at IS NULL
      AND moderation_status IN ('pending', 'approved');
    SELECT COUNT(*)::int INTO sess_cnt
    FROM media_upload_sessions
    WHERE venue_id = p_venue_id
      AND inventory_type_id IS NULL
      AND kind = 'image'
      AND status = 'pending'
      AND expires_at >= now();
  END IF;
  RETURN COALESCE(media_cnt, 0) + COALESCE(sess_cnt, 0);
END;
$$;

-- ---------------------------------------------------------------------------
-- F-REV4-12 / F-REV4-16: Soft-delete + CF hostname allowlist in denorm playable
-- Exact hosts: imagedelivery.net, upload.imagedelivery.net, customer-*.cloudflarestream.com
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION places_cf_https_url_allowed(u TEXT)
RETURNS BOOLEAN
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT u IS NOT NULL
    AND btrim(u) <> ''
    AND (
      u ~* '^https://imagedelivery\.net/'
      OR u ~* '^https://upload\.imagedelivery\.net/'
      OR u ~* '^https://customer-[a-z0-9-]+\.cloudflarestream\.com/'
    );
$$;

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

DROP TRIGGER IF EXISTS trg_venue_media_playable_video ON venue_media;
CREATE TRIGGER trg_venue_media_playable_video
AFTER INSERT OR UPDATE OR DELETE ON venue_media
FOR EACH ROW
EXECUTE FUNCTION places_refresh_venue_playable_video();

-- One-shot reconcile playable flags under media write lock.
DO $$
DECLARE
  fixed_count integer := 0;
BEGIN
  LOCK TABLE venue_media IN SHARE ROW EXCLUSIVE MODE;

  UPDATE venues v
  SET has_playable_video = sub.playable,
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
  RAISE NOTICE 'REV4_022_MEDIA_DENORM_RECONCILE fixed_rows=%', fixed_count;
END $$;

-- ===========================================================================
-- EVENTS OUTBOX (REV4) — F-REV4-18 claim_token + notification idempotency
-- ===========================================================================

ALTER TABLE domain_events
  ADD COLUMN IF NOT EXISTS claim_token UUID,
  ADD COLUMN IF NOT EXISTS claimed_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_domain_events_claim
  ON domain_events (status, claimed_at)
  WHERE status = 'processing';

-- Idempotent notify by domain event id (outbox payload.eventId).
ALTER TABLE notifications
  ADD COLUMN IF NOT EXISTS source_event_id UUID;

CREATE UNIQUE INDEX IF NOT EXISTS uq_notifications_source_event_id
  ON notifications (source_event_id)
  WHERE source_event_id IS NOT NULL;
