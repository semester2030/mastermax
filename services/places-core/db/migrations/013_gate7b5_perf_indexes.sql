-- Gate 7B.5 — additive performance indexes (evidence-backed).
-- Non-destructive. Does not modify 001–012.
--
-- Evidence (places_core_perf, dataset g7b5-v1, 52k venues):
-- 1) sort=newest spilled to external merge (Temp Written Blocks=1326) at limit≤50
--    with no usable published+created_at index (date_trunc(timestamptz) is not IMMUTABLE,
--    so expression index matching ORDER BY cannot be created; btree on created_at is the
--    additive substitute the planner can use for ordering/limit).
-- 2) best_score / search_rank evaluate APPROVED_VIDEO_EXISTS per candidate via Seq Scan
--    on venue_media; partial playable-video index targets that EXISTS.

CREATE INDEX IF NOT EXISTS idx_venues_published_created_at
  ON venues (created_at DESC NULLS LAST, id ASC)
  WHERE status = 'published';

CREATE INDEX IF NOT EXISTS idx_venue_media_playable_video
  ON venue_media (venue_id)
  WHERE kind = 'video'
    AND moderation_status = 'approved'
    AND (
      (stream_uid IS NOT NULL AND btrim(stream_uid) <> '')
      OR (url IS NOT NULL AND btrim(url) <> '' AND url ~* '^https://')
    );
