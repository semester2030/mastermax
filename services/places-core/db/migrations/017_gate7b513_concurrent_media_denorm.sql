-- Gate 7B.5.1.3 — concurrency-safe venue_media denorm (non-destructive to 001–016).
--
-- 015/016 refresh A+B and reconcile stale rows, but concurrent media writes can race:
-- two DELETEs of the last playable clips may each see the other row still present and
-- leave has_playable_video=true. Fix: lock affected venues in stable UUID order
-- (FOR UPDATE), then recompute in a subsequent statement against the updated snapshot.
-- Re-parent always locks min(id), max(id) to avoid deadlock.

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
      AND (
        (m.stream_uid IS NOT NULL AND btrim(m.stream_uid) <> '')
        OR (m.url IS NOT NULL AND btrim(m.url) <> '' AND m.url ~* '^https://')
      )
  ),
  indicative_starting_price = (
    SELECT MIN(m.starting_price_hint) FROM venue_media m
    WHERE m.venue_id = vid
      AND m.moderation_status = 'approved'
      AND m.starting_price_hint IS NOT NULL
  )
  WHERE id = vid;
END;
$$;

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
    PERFORM 1 FROM venues WHERE id = id_b FOR UPDATE;
    RETURN;
  END IF;
  IF id_b IS NULL OR id_a = id_b THEN
    PERFORM 1 FROM venues WHERE id = id_a FOR UPDATE;
    RETURN;
  END IF;
  -- Stable UUID order prevents A↔B re-parent deadlock.
  IF id_a < id_b THEN
    first_id := id_a;
    second_id := id_b;
  ELSE
    first_id := id_b;
    second_id := id_a;
  END IF;
  PERFORM 1 FROM venues WHERE id = first_id FOR UPDATE;
  PERFORM 1 FROM venues WHERE id = second_id FOR UPDATE;
END;
$$;

CREATE OR REPLACE FUNCTION places_refresh_venue_playable_video()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  vid_old UUID;
  vid_new UUID;
BEGIN
  IF TG_OP = 'DELETE' THEN
    vid_old := OLD.venue_id;
    vid_new := NULL;
  ELSIF TG_OP = 'INSERT' THEN
    vid_old := NULL;
    vid_new := NEW.venue_id;
  ELSE
    vid_old := OLD.venue_id;
    vid_new := NEW.venue_id;
  END IF;

  -- 1) Lock venues first (ordered).
  PERFORM places_lock_venues_for_media_denorm(vid_old, vid_new);

  -- 2) Recompute in subsequent statements so EXISTS/MIN see post-write snapshot.
  IF TG_OP = 'UPDATE' AND vid_old IS DISTINCT FROM vid_new THEN
    PERFORM places_refresh_venue_media_denorm(vid_old);
    PERFORM places_refresh_venue_media_denorm(vid_new);
  ELSE
    PERFORM places_refresh_venue_media_denorm(COALESCE(vid_new, vid_old));
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_venue_media_playable_video ON venue_media;
CREATE TRIGGER trg_venue_media_playable_video
AFTER INSERT OR UPDATE OR DELETE ON venue_media
FOR EACH ROW
EXECUTE FUNCTION places_refresh_venue_playable_video();

-- Migration-time reconcile: block concurrent venue_media writers, then set-based fix.
DO $$
DECLARE
  fixed_count integer := 0;
  t0 timestamptz := clock_timestamp();
  elapsed_ms numeric;
BEGIN
  -- SHARE ROW EXCLUSIVE: blocks concurrent writers to venue_media (and conflicting locks).
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
          AND (
            (m.stream_uid IS NOT NULL AND btrim(m.stream_uid) <> '')
            OR (m.url IS NOT NULL AND btrim(m.url) <> '' AND m.url ~* '^https://')
          )
      ) AS playable,
      (
        SELECT MIN(m.starting_price_hint) FROM venue_media m
        WHERE m.venue_id = v2.id
          AND m.moderation_status = 'approved'
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
  RAISE NOTICE 'GATE7B513_RECONCILE fixed_rows=% elapsed_ms=% lock=SHARE_ROW_EXCLUSIVE_venue_media rollback=none',
    fixed_count, elapsed_ms;
END $$;
