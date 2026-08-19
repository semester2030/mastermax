-- Gate 7B.5.1.2 — reconcile stale denorm columns (non-destructive to 001–015).
--
-- 015 fixed the re-parent trigger for the future but did not repair rows already
-- left stale by 014 (media moved A→B without refreshing A).
-- Set-based UPDATE with IS DISTINCT FROM; no DELETE / DROP of data.
-- best_score_static is GENERATED and follows has_playable_video automatically.

DO $$
DECLARE
  fixed_count integer := 0;
  t0 timestamptz := clock_timestamp();
  elapsed_ms numeric;
BEGIN
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

  RAISE NOTICE 'GATE7B512_RECONCILE fixed_rows=% elapsed_ms=% lock=ROW_EXCLUSIVE_UPDATE rollback=none',
    fixed_count, elapsed_ms;
END $$;
