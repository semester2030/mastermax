-- Phase 6 RC2: atomic video quota enforcement (F-V2-015 gap closure).
-- Videos are venue-scoped. Quota counts pending+approved venue_media videos plus
-- non-expired pending video upload sessions, mirroring the image quota model.
-- Cap = MEDIA_LIMITS.maxVideosPerScope (3). Enforced both at the application
-- layer (atomic reserve-before-mint) and by a DB trigger (fail-closed).

-- Quota = live videos (pending+approved) + non-expired pending video sessions.
CREATE OR REPLACE FUNCTION places_video_quota_used(p_venue_id UUID)
RETURNS INT
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  media_cnt INT;
  sess_cnt INT;
BEGIN
  SELECT COUNT(*)::int INTO media_cnt
  FROM venue_media
  WHERE venue_id = p_venue_id
    AND kind = 'video'
    AND deleted_at IS NULL
    AND moderation_status IN ('pending', 'approved');
  SELECT COUNT(*)::int INTO sess_cnt
  FROM media_upload_sessions
  WHERE venue_id = p_venue_id
    AND kind = 'video'
    AND status = 'pending'
    AND expires_at >= now();
  RETURN COALESCE(media_cnt, 0) + COALESCE(sess_cnt, 0);
END;
$$;

-- Expire stale pending video sessions in scope (frees quota reservation).
CREATE OR REPLACE FUNCTION places_expire_stale_video_upload_sessions(p_venue_id UUID)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
  n INT;
BEGIN
  UPDATE media_upload_sessions
  SET status = 'expired'
  WHERE status = 'pending'
    AND kind = 'video'
    AND expires_at < now()
    AND venue_id = p_venue_id;
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END;
$$;

-- Fail-closed DB trigger: never allow > 3 pending+approved videos per venue.
CREATE OR REPLACE FUNCTION places_enforce_venue_video_cap()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  cnt INT;
BEGIN
  IF NEW.kind <> 'video' THEN
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
    AND kind = 'video'
    AND deleted_at IS NULL
    AND moderation_status IN ('pending', 'approved')
    AND id IS DISTINCT FROM NEW.id;
  IF cnt >= 3 THEN
    RAISE EXCEPTION 'VENUE_VIDEO_CAP: max 3 pending+approved venue videos'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_venue_media_video_cap_venue ON venue_media;
CREATE TRIGGER trg_venue_media_video_cap_venue
BEFORE INSERT OR UPDATE OF kind, moderation_status, venue_id, deleted_at
ON venue_media
FOR EACH ROW
EXECUTE FUNCTION places_enforce_venue_video_cap();
