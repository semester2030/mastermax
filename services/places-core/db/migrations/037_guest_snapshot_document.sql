-- Guest/booker snapshot for Places bookings (document + hold).
-- Additive only. Does not touch 001–036. No DROP/TRUNCATE.

ALTER TABLE quotes
  ADD COLUMN IF NOT EXISTS guest_snapshot_json jsonb;

ALTER TABLE booking_holds
  ADD COLUMN IF NOT EXISTS guest_snapshot_json jsonb;

ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS guest_snapshot_json jsonb;
