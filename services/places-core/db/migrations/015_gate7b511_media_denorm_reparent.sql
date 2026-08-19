-- Gate 7B.5.1.1 — fix venue_media denorm trigger for re-parent (non-destructive to 001–014).
--
-- Bug: 014 refreshed only COALESCE(NEW.venue_id, OLD.venue_id). On UPDATE that moves
-- media from venue A → B, A was never refreshed and kept stale has_playable_video /
-- indicative_starting_price (best_score_static follows has_playable_video as GENERATED).

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

CREATE OR REPLACE FUNCTION places_refresh_venue_playable_video()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'UPDATE'
     AND NEW.venue_id IS DISTINCT FROM OLD.venue_id THEN
    PERFORM places_refresh_venue_media_denorm(OLD.venue_id);
    PERFORM places_refresh_venue_media_denorm(NEW.venue_id);
  ELSE
    PERFORM places_refresh_venue_media_denorm(COALESCE(NEW.venue_id, OLD.venue_id));
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_venue_media_playable_video ON venue_media;
CREATE TRIGGER trg_venue_media_playable_video
AFTER INSERT OR UPDATE OR DELETE ON venue_media
FOR EACH ROW
EXECUTE FUNCTION places_refresh_venue_playable_video();
