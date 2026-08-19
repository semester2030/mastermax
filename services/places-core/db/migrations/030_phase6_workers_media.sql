-- Phase 6: worker heartbeats + CF delete failure alerts + rejected retention index
-- Forward-only. Does not alter 001–029.

CREATE TABLE IF NOT EXISTS worker_heartbeats (
  worker_name TEXT NOT NULL,
  instance_id TEXT NOT NULL,
  last_tick_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_error TEXT,
  meta_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (worker_name, instance_id)
);

COMMENT ON TABLE worker_heartbeats IS
  'Phase 6: independent worker process health/lease observability (F-V3-005).';

ALTER TABLE media_cf_delete_outbox
  ADD COLUMN IF NOT EXISTS alerted_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_media_cf_delete_failed_alert
  ON media_cf_delete_outbox (status, alerted_at)
  WHERE status = 'failed';

ALTER TABLE venue_media
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_venue_media_rejected_retention
  ON venue_media (moderation_status, updated_at)
  WHERE moderation_status = 'rejected' AND deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_media_upload_sessions_orphan
  ON media_upload_sessions (status, expires_at)
  WHERE status = 'pending';
