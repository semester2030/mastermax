-- RC4: immutable event_slot time/timezone snapshot on the booking,
-- and video-cap trigger counts pending sessions + pending/approved videos.

ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS slot_start_time TIME NULL;
ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS slot_timezone TEXT NULL;

COMMENT ON COLUMN bookings.slot_start_time IS
  'RC4: event_slot start time frozen at hold/booking create. No-show must use this, never the live template.';
COMMENT ON COLUMN bookings.slot_timezone IS
  'RC4: venue timezone frozen at hold/booking create for the slot instant.';

CREATE OR REPLACE FUNCTION places_enforce_venue_video_cap()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  media_cnt INT;
  sess_cnt INT;
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
  SELECT COUNT(*)::int INTO media_cnt
  FROM venue_media
  WHERE venue_id = NEW.venue_id
    AND kind = 'video'
    AND deleted_at IS NULL
    AND moderation_status IN ('pending', 'approved')
    AND id IS DISTINCT FROM NEW.id;
  SELECT COUNT(*)::int INTO sess_cnt
  FROM media_upload_sessions
  WHERE venue_id = NEW.venue_id
    AND kind = 'video'
    AND status = 'pending'
    AND expires_at >= now();
  IF COALESCE(media_cnt, 0) + COALESCE(sess_cnt, 0) >= 3 THEN
    RAISE EXCEPTION 'VENUE_VIDEO_CAP: max 3 pending sessions + pending/approved videos'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;
