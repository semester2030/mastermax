-- Additive location fields for Google Places pin + stored formatted address.
-- Does not rewrite existing lat/lng/city/district/street/location_source.
-- Does not invent coordinates for legacy rows.

ALTER TABLE venues
  ADD COLUMN IF NOT EXISTS google_place_id TEXT,
  ADD COLUMN IF NOT EXISTS formatted_address TEXT;

ALTER TABLE venues
  DROP CONSTRAINT IF EXISTS venues_google_place_id_len;

ALTER TABLE venues
  ADD CONSTRAINT venues_google_place_id_len
  CHECK (google_place_id IS NULL OR char_length(google_place_id) <= 256);

ALTER TABLE venues
  DROP CONSTRAINT IF EXISTS venues_formatted_address_len;

ALTER TABLE venues
  ADD CONSTRAINT venues_formatted_address_len
  CHECK (formatted_address IS NULL OR char_length(formatted_address) <= 500);
