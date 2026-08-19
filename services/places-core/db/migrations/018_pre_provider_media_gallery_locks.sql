-- Gate PRE-PROVIDER FINAL CLOSURE — Migration 018 (non-destructive to 001–017).
-- Media gallery caps (venue-level + inventory_type-level), cover uniqueness,
-- ordered multi-venue lock helper, and farm as independent venue type.
-- wedding_palace / event_hall remain kill-switched (not auto-enabled here).

INSERT INTO venue_type_capabilities (
  venue_type, label_ar, label_en, enabled_for_discovery, enabled_for_booking,
  enabled_for_provider, enabled_for_admin, booking_semantics, sort_order
) VALUES
  ('farm', 'مزارع', 'Farm', TRUE, TRUE, TRUE, TRUE, 'accommodation', 85)
ON CONFLICT (venue_type) DO NOTHING;

-- Cover flag for approved images (Provider Web contracts later).
ALTER TABLE venue_media
  ADD COLUMN IF NOT EXISTS is_cover BOOLEAN NOT NULL DEFAULT FALSE;

-- At most one cover image per venue scope (inventory_type_id IS NULL).
CREATE UNIQUE INDEX IF NOT EXISTS uq_venue_media_cover_venue
  ON venue_media (venue_id)
  WHERE is_cover = TRUE AND inventory_type_id IS NULL AND kind = 'image';

-- At most one cover image per inventory_type scope.
CREATE UNIQUE INDEX IF NOT EXISTS uq_venue_media_cover_inventory_type
  ON venue_media (inventory_type_id)
  WHERE is_cover = TRUE AND inventory_type_id IS NOT NULL AND kind = 'image';

-- Supporting index for gallery reads (approved images ordered).
CREATE INDEX IF NOT EXISTS idx_venue_media_gallery_venue
  ON venue_media (venue_id, sort_order, id)
  WHERE kind = 'image' AND moderation_status = 'approved' AND inventory_type_id IS NULL;

CREATE INDEX IF NOT EXISTS idx_venue_media_gallery_inventory_type
  ON venue_media (inventory_type_id, sort_order, id)
  WHERE kind = 'image' AND moderation_status = 'approved' AND inventory_type_id IS NOT NULL;

-- Enforce max 30 approved images per venue (venue-level gallery).
CREATE OR REPLACE FUNCTION places_enforce_venue_image_cap()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  cnt INT;
BEGIN
  IF NEW.kind <> 'image' OR NEW.moderation_status <> 'approved' OR NEW.inventory_type_id IS NOT NULL THEN
    RETURN NEW;
  END IF;
  SELECT COUNT(*)::int INTO cnt
  FROM venue_media
  WHERE venue_id = NEW.venue_id
    AND kind = 'image'
    AND moderation_status = 'approved'
    AND inventory_type_id IS NULL
    AND id IS DISTINCT FROM NEW.id;
  IF cnt >= 30 THEN
    RAISE EXCEPTION 'VENUE_IMAGE_CAP: max 30 approved venue images'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_venue_media_image_cap_venue ON venue_media;
CREATE TRIGGER trg_venue_media_image_cap_venue
BEFORE INSERT OR UPDATE OF kind, moderation_status, inventory_type_id, venue_id
ON venue_media
FOR EACH ROW
EXECUTE FUNCTION places_enforce_venue_image_cap();

-- Enforce max 30 approved images per inventory_type (not per physical unit/room).
CREATE OR REPLACE FUNCTION places_enforce_inventory_type_image_cap()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  cnt INT;
BEGIN
  IF NEW.kind <> 'image' OR NEW.moderation_status <> 'approved' OR NEW.inventory_type_id IS NULL THEN
    RETURN NEW;
  END IF;
  SELECT COUNT(*)::int INTO cnt
  FROM venue_media
  WHERE inventory_type_id = NEW.inventory_type_id
    AND kind = 'image'
    AND moderation_status = 'approved'
    AND id IS DISTINCT FROM NEW.id;
  IF cnt >= 30 THEN
    RAISE EXCEPTION 'INVENTORY_TYPE_IMAGE_CAP: max 30 approved images per inventory_type'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_venue_media_image_cap_inventory_type ON venue_media;
CREATE TRIGGER trg_venue_media_image_cap_inventory_type
BEFORE INSERT OR UPDATE OF kind, moderation_status, inventory_type_id
ON venue_media
FOR EACH ROW
EXECUTE FUNCTION places_enforce_inventory_type_image_cap();

-- Lock an arbitrary set of venue IDs in ascending UUID order (deadlock-safe).
-- Extends 017 two-id helper for multi-venue media ops / concurrent tests.
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
    PERFORM 1 FROM venues WHERE id = vid FOR UPDATE;
  END LOOP;
END;
$$;

-- Provider media write helper: lock venue then inventory_type parent venue (same id) stably.
CREATE OR REPLACE FUNCTION places_lock_media_write_scope(p_venue_id UUID, p_inventory_type_id UUID)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
  inv_venue UUID;
BEGIN
  IF p_inventory_type_id IS NOT NULL THEN
    SELECT venue_id INTO inv_venue FROM inventory_types WHERE id = p_inventory_type_id;
    IF inv_venue IS NULL THEN
      RAISE EXCEPTION 'inventory_type not found' USING ERRCODE = 'foreign_key_violation';
    END IF;
    IF p_venue_id IS NOT NULL AND inv_venue <> p_venue_id THEN
      RAISE EXCEPTION 'inventory_type does not belong to venue' USING ERRCODE = 'check_violation';
    END IF;
    PERFORM places_lock_venues_ordered(ARRAY[LEAST(p_venue_id, inv_venue), GREATEST(p_venue_id, inv_venue)]);
  ELSIF p_venue_id IS NOT NULL THEN
    PERFORM places_lock_venues_ordered(ARRAY[p_venue_id]);
  END IF;
END;
$$;
