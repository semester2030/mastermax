-- Gate PRE-DEVICE REV2 — Migration 020 (non-destructive to 001–019).
-- FOR NO KEY UPDATE on venue locks; image caps pending+approved; approved-only cover uniques;
-- idempotency scope; media soft-delete + CF delete outbox; completed_media_id ON DELETE SET NULL.

-- 1) Venue locks: FOR NO KEY UPDATE (avoids blocking concurrent FK/key updates on venues).
CREATE OR REPLACE FUNCTION places_lock_venues_for_media_denorm(id_a UUID, id_b UUID)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
  first_id UUID;
  second_id UUID;
BEGIN
  IF id_a IS NULL AND id_b IS NULL THEN
    RETURN;
  END IF;
  IF id_a IS NULL THEN
    PERFORM 1 FROM venues WHERE id = id_b FOR NO KEY UPDATE;
    RETURN;
  END IF;
  IF id_b IS NULL OR id_a = id_b THEN
    PERFORM 1 FROM venues WHERE id = id_a FOR NO KEY UPDATE;
    RETURN;
  END IF;
  IF id_a < id_b THEN
    first_id := id_a;
    second_id := id_b;
  ELSE
    first_id := id_b;
    second_id := id_a;
  END IF;
  PERFORM 1 FROM venues WHERE id = first_id FOR NO KEY UPDATE;
  PERFORM 1 FROM venues WHERE id = second_id FOR NO KEY UPDATE;
END;
$$;

CREATE OR REPLACE FUNCTION places_lock_venues_ordered(ids UUID[])
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
  vid UUID;
BEGIN
  IF ids IS NULL OR array_length(ids, 1) IS NULL THEN
    RETURN;
  END IF;
  FOR vid IN
    SELECT DISTINCT x FROM unnest(ids) AS t(x) WHERE x IS NOT NULL ORDER BY 1
  LOOP
    PERFORM 1 FROM venues WHERE id = vid FOR NO KEY UPDATE;
  END LOOP;
END;
$$;

-- 2) Soft-delete for media (CF object cleanup via outbox; DB wins first).
ALTER TABLE venue_media
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_venue_media_active
  ON venue_media (venue_id, kind, moderation_status)
  WHERE deleted_at IS NULL;

-- 3) Cover uniqueness: approved + not deleted only (pending cover cannot displace approved).
DROP INDEX IF EXISTS uq_venue_media_cover_venue;
DROP INDEX IF EXISTS uq_venue_media_cover_inventory_type;

CREATE UNIQUE INDEX uq_venue_media_cover_venue_approved
  ON venue_media (venue_id)
  WHERE is_cover = TRUE
    AND inventory_type_id IS NULL
    AND kind = 'image'
    AND moderation_status = 'approved'
    AND deleted_at IS NULL;

CREATE UNIQUE INDEX uq_venue_media_cover_inventory_type_approved
  ON venue_media (inventory_type_id)
  WHERE is_cover = TRUE
    AND inventory_type_id IS NOT NULL
    AND kind = 'image'
    AND moderation_status = 'approved'
    AND deleted_at IS NULL;

-- Pending cover uniqueness within pending scope (optional safety).
CREATE UNIQUE INDEX IF NOT EXISTS uq_venue_media_cover_venue_pending
  ON venue_media (venue_id)
  WHERE is_cover = TRUE
    AND inventory_type_id IS NULL
    AND kind = 'image'
    AND moderation_status = 'pending'
    AND deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_venue_media_cover_inventory_type_pending
  ON venue_media (inventory_type_id)
  WHERE is_cover = TRUE
    AND inventory_type_id IS NOT NULL
    AND kind = 'image'
    AND moderation_status = 'pending'
    AND deleted_at IS NULL;

-- 4) Cap 1–30 counts pending + approved (not rejected/deleted) — concurrent-safe under write scope lock.
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

-- Recreate triggers to also fire on deleted_at
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

-- 5) Idempotency scoped by actor + method + route + client key
ALTER TABLE idempotency_keys
  ADD COLUMN IF NOT EXISTS actor_uid TEXT,
  ADD COLUMN IF NOT EXISTS http_method TEXT,
  ADD COLUMN IF NOT EXISTS route_path TEXT;

-- Migrate PK: keep legacy rows under synthetic scope
ALTER TABLE idempotency_keys DROP CONSTRAINT IF EXISTS idempotency_keys_pkey;
UPDATE idempotency_keys
  SET actor_uid = COALESCE(actor_uid, '_legacy'),
      http_method = COALESCE(http_method, '_legacy'),
      route_path = COALESCE(route_path, '_legacy')
WHERE actor_uid IS NULL OR http_method IS NULL OR route_path IS NULL;

ALTER TABLE idempotency_keys
  ALTER COLUMN actor_uid SET NOT NULL,
  ALTER COLUMN http_method SET NOT NULL,
  ALTER COLUMN route_path SET NOT NULL;

ALTER TABLE idempotency_keys
  ADD PRIMARY KEY (actor_uid, http_method, route_path, key);

-- 6) media_upload_sessions.completed_media_id ON DELETE SET NULL
ALTER TABLE media_upload_sessions
  DROP CONSTRAINT IF EXISTS media_upload_sessions_completed_media_id_fkey;

ALTER TABLE media_upload_sessions
  ADD CONSTRAINT media_upload_sessions_completed_media_id_fkey
  FOREIGN KEY (completed_media_id) REFERENCES venue_media (id) ON DELETE SET NULL;

-- 7) Outbox for Cloudflare object deletes (DB soft-delete first; worker deletes CF idempotently)
CREATE TABLE IF NOT EXISTS media_cf_delete_outbox (
  id UUID PRIMARY KEY,
  kind TEXT NOT NULL CHECK (kind IN ('image', 'video')),
  cloudflare_image_id TEXT,
  stream_uid TEXT,
  venue_media_id UUID,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'done', 'failed')),
  attempts INT NOT NULL DEFAULT 0,
  last_error TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  processed_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_media_cf_delete_outbox_pending
  ON media_cf_delete_outbox (status, created_at)
  WHERE status = 'pending';

-- 8) Catalog venue details: optional description (Flutter/Core parity).
ALTER TABLE venues
  ADD COLUMN IF NOT EXISTS description TEXT;
