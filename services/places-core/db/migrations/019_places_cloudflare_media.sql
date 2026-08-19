-- Gate PRE-PROVIDER — Cloudflare Images/Stream reuse (non-destructive to 001–018).
-- Proven DAR CAR pattern (functions/index.js createImagesDirectUpload + Stream direct_upload):
--   client gets short-lived uploadURL → PUT/POST bytes to Cloudflare → Core stores ids only.
-- No parallel object storage. No Firebase blob storage for Places media.

ALTER TABLE venue_media
  ADD COLUMN IF NOT EXISTS cloudflare_image_id TEXT;

CREATE INDEX IF NOT EXISTS idx_venue_media_cf_image
  ON venue_media (cloudflare_image_id)
  WHERE cloudflare_image_id IS NOT NULL;

-- Pending direct-upload sessions for orphan cleanup (upload without complete).
CREATE TABLE IF NOT EXISTS media_upload_sessions (
  id UUID PRIMARY KEY,
  provider_id UUID NOT NULL REFERENCES providers (id),
  venue_id UUID NOT NULL REFERENCES venues (id),
  inventory_type_id UUID REFERENCES inventory_types (id),
  kind TEXT NOT NULL CHECK (kind IN ('image', 'video')),
  cloudflare_image_id TEXT,
  stream_uid TEXT,
  images_hash TEXT,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'completed', 'expired', 'orphaned_cleaned')),
  created_by_uid TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  completed_media_id UUID REFERENCES venue_media (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_media_upload_sessions_expiry
  ON media_upload_sessions (status, expires_at)
  WHERE status = 'pending';
