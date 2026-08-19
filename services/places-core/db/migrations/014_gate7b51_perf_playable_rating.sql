-- Gate 7B.5.1 — additive perf + index hygiene (non-destructive to 001–013).
--
-- Evidence:
-- 1) best_score / feed evaluate APPROVED_VIDEO_EXISTS per candidate; denormalized
--    has_playable_video (maintained by trigger) preserves EXISTS semantics with
--    cheaper boolean predicate under concurrent load.
-- 2) idx_venues_published_created_at (013) is unused by newest ORDER BY
--    date_trunc('milliseconds', created_at) (non-immutable) — DROP via 014
--    (index-only; data intact). Keep idx_venue_media_playable_video from 013.
-- 3) published rating keyset benefits from composite btree matching
--    ORDER BY weighted_rating DESC NULLS LAST, reviews_count DESC, id ASC.
-- 4) cheapest uses denormalized indicative_starting_price (= MIN approved media hint).
-- 5) best_score_static STORED = rating+reviews+video terms; query adds freshness
--    so ORDER BY remains algebraically identical to locked Gate 7B.3 equation.

ALTER TABLE venues
  ADD COLUMN IF NOT EXISTS has_playable_video BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE venues
  ADD COLUMN IF NOT EXISTS indicative_starting_price NUMERIC(12, 2);

-- Backfill from current playable approved video definition (matches discovery-surface).
UPDATE venues v
SET has_playable_video = EXISTS (
  SELECT 1 FROM venue_media m
  WHERE m.venue_id = v.id
    AND m.kind = 'video'
    AND m.moderation_status = 'approved'
    AND (
      (m.stream_uid IS NOT NULL AND btrim(m.stream_uid) <> '')
      OR (m.url IS NOT NULL AND btrim(m.url) <> '' AND m.url ~* '^https://')
    )
);

UPDATE venues v
SET indicative_starting_price = (
  SELECT MIN(m.starting_price_hint) FROM venue_media m
  WHERE m.venue_id = v.id
    AND m.moderation_status = 'approved'
    AND m.starting_price_hint IS NOT NULL
);

CREATE OR REPLACE FUNCTION places_refresh_venue_playable_video()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  vid UUID;
BEGIN
  vid := COALESCE(NEW.venue_id, OLD.venue_id);
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
  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_venue_media_playable_video ON venue_media;
CREATE TRIGGER trg_venue_media_playable_video
AFTER INSERT OR UPDATE OR DELETE ON venue_media
FOR EACH ROW
EXECUTE FUNCTION places_refresh_venue_playable_video();

-- Drop unused 013 created_at index (newest uses date_trunc — planner cannot match).
DROP INDEX IF EXISTS idx_venues_published_created_at;

CREATE INDEX IF NOT EXISTS idx_venues_published_has_playable_video
  ON venues (id)
  WHERE status = 'published' AND has_playable_video = TRUE;

CREATE INDEX IF NOT EXISTS idx_venues_published_rating_keyset
  ON venues (weighted_rating DESC NULLS LAST, reviews_count DESC, id ASC)
  WHERE status = 'published';

CREATE INDEX IF NOT EXISTS idx_venues_published_indicative_price
  ON venues (indicative_starting_price ASC NULLS LAST, id ASC)
  WHERE status = 'published' AND indicative_starting_price IS NOT NULL;

-- Static portion of locked best_score (freshness remains query-time).
-- Store full precision (no intermediate numeric(8,6)) so final cast matches classic.
ALTER TABLE venues DROP COLUMN IF EXISTS best_score_static;
ALTER TABLE venues
  ADD COLUMN best_score_static NUMERIC
  GENERATED ALWAYS AS (
      0.45 * (LEAST(5::numeric, GREATEST(0::numeric, COALESCE(weighted_rating, 0))) / 5.0)
      + 0.20 * (
        LN(1.0 + LEAST(COALESCE(reviews_count, 0), 500)::numeric) / LN(501.0)
      )
      + 0.10 * CASE WHEN has_playable_video IS TRUE THEN 1.0 ELSE 0.0 END
  ) STORED;

CREATE INDEX IF NOT EXISTS idx_venues_published_best_static
  ON venues (best_score_static DESC NULLS LAST, id ASC)
  WHERE status = 'published';

-- Index-only COUNT(*) for status=published (avoids seq scan under concurrency).
CREATE INDEX IF NOT EXISTS idx_venues_published_id
  ON venues (id)
  WHERE status = 'published';
