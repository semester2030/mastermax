-- 023_pay_at_venue_event_slot_gate9a.sql
-- Gate 9A root-cause closure. Forward-only. Immutables: 001–022.
-- HOLDING keeps payment_method/payment_status NULL.
-- Pay-at-Venue confirm: single-row UPDATE → CONFIRMED + PAY_AT_VENUE + DUE_AT_VENUE.

ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS payment_method TEXT NULL,
  ADD COLUMN IF NOT EXISTS payment_status TEXT NULL;

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_payment_method_chk;
ALTER TABLE bookings
  ADD CONSTRAINT bookings_payment_method_chk
  CHECK (
    payment_method IS NULL
    OR payment_method IN ('PAY_AT_VENUE', 'PSP_CARD', 'LEGACY_UNSPECIFIED')
  );

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_payment_status_chk;
ALTER TABLE bookings
  ADD CONSTRAINT bookings_payment_status_chk
  CHECK (
    payment_status IS NULL
    OR payment_status IN (
      'DUE_AT_VENUE', 'VOIDED', 'NOT_APPLICABLE', 'CAPTURED', 'LEGACY_UNSPECIFIED'
    )
  );

UPDATE bookings
SET payment_method = 'LEGACY_UNSPECIFIED',
    payment_status = 'LEGACY_UNSPECIFIED'
WHERE payment_method IS NULL
  AND payment_status IS NULL
  AND status NOT IN ('HOLDING', 'EXPIRED', 'PENDING_PAYMENT', 'PAYMENT_FAILED');

ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_payment_combo_chk;
ALTER TABLE bookings
  ADD CONSTRAINT bookings_payment_combo_chk CHECK (
    CASE
      WHEN status IN ('HOLDING', 'EXPIRED', 'PENDING_PAYMENT', 'PAYMENT_FAILED')
        THEN (payment_method IS NULL AND payment_status IS NULL)
      WHEN status = 'CANCELLED' AND payment_method IS NULL
        THEN (payment_status IS NULL)
      WHEN status = 'CANCELLED' AND payment_method = 'PAY_AT_VENUE'
        THEN (payment_status = 'VOIDED')
      WHEN status IN (
        'CONFIRMED', 'ACTIVE', 'COMPLETED', 'NO_SHOW',
        'DISPUTED', 'REFUND_PENDING', 'REFUNDED'
      ) AND payment_method = 'PAY_AT_VENUE'
        THEN (payment_status = 'DUE_AT_VENUE')
      WHEN payment_method = 'LEGACY_UNSPECIFIED'
        THEN (payment_status = 'LEGACY_UNSPECIFIED')
      WHEN payment_method = 'PSP_CARD'
        THEN (payment_status IN ('NOT_APPLICABLE', 'CAPTURED'))
      ELSE FALSE
    END
  );

CREATE INDEX IF NOT EXISTS idx_bookings_pay_at_venue
  ON bookings (provider_id, payment_method, payment_status)
  WHERE payment_method = 'PAY_AT_VENUE';

ALTER TABLE venue_media
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

ALTER TABLE venue_media DROP CONSTRAINT IF EXISTS venue_media_rejection_reason_len_chk;
ALTER TABLE venue_media
  ADD CONSTRAINT venue_media_rejection_reason_len_chk
  CHECK (rejection_reason IS NULL OR char_length(rejection_reason) <= 500);

CREATE UNIQUE INDEX IF NOT EXISTS uq_inventory_types_id_venue
  ON inventory_types (id, venue_id);

ALTER TABLE event_slot_templates
  ADD COLUMN IF NOT EXISTS inventory_type_id UUID NULL;

UPDATE event_slot_templates t
SET inventory_type_id = sub.id
FROM (
  SELECT DISTINCT ON (venue_id) id, venue_id
  FROM inventory_types
  ORDER BY venue_id, id
) AS sub
WHERE t.venue_id = sub.venue_id
  AND t.inventory_type_id IS NULL;

-- Active templates that still lack inventory_type_id or base_price cannot satisfy Wave1 SSOT.
UPDATE event_slot_templates
SET status = 'inactive'
WHERE status = 'active'
  AND (inventory_type_id IS NULL OR base_price IS NULL);

ALTER TABLE event_slot_templates DROP CONSTRAINT IF EXISTS event_slot_templates_inventory_type_venue_fk;
ALTER TABLE event_slot_templates
  ADD CONSTRAINT event_slot_templates_inventory_type_venue_fk
  FOREIGN KEY (inventory_type_id, venue_id)
  REFERENCES inventory_types (id, venue_id)
  DEFERRABLE INITIALLY IMMEDIATE;

ALTER TABLE event_slot_templates DROP CONSTRAINT IF EXISTS event_slot_templates_base_price_active_chk;
ALTER TABLE event_slot_templates
  ADD CONSTRAINT event_slot_templates_base_price_active_chk
  CHECK (
    status <> 'active'
    OR (base_price IS NOT NULL AND base_price >= 0 AND inventory_type_id IS NOT NULL)
  );

ALTER TABLE event_slot_inventory DROP CONSTRAINT IF EXISTS event_slot_inventory_hold_fk;
ALTER TABLE event_slot_inventory
  ADD CONSTRAINT event_slot_inventory_hold_fk
  FOREIGN KEY (hold_id) REFERENCES booking_holds (id);

ALTER TABLE event_slot_inventory DROP CONSTRAINT IF EXISTS event_slot_inventory_status_refs_chk;
ALTER TABLE event_slot_inventory
  ADD CONSTRAINT event_slot_inventory_status_refs_chk CHECK (
    (status = 'open' AND hold_id IS NULL AND booking_id IS NULL)
    OR (status = 'held' AND hold_id IS NOT NULL AND booking_id IS NULL)
    OR (status = 'booked' AND booking_id IS NOT NULL AND hold_id IS NULL)
    OR (status = 'blocked' AND booking_id IS NULL)
  );

CREATE TABLE IF NOT EXISTS auth_otp_challenges (
  id UUID PRIMARY KEY,
  phone_hash TEXT NOT NULL,
  otp_hash TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  attempts INT NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  locked_until TIMESTAMPTZ,
  consumed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_auth_otp_challenges_expires
  ON auth_otp_challenges (expires_at);

CREATE TABLE IF NOT EXISTS auth_sessions (
  jti UUID PRIMARY KEY,
  subject_id TEXT NOT NULL,
  claim TEXT NOT NULL CHECK (claim = 'placesInternalOperator'),
  on_behalf_of_provider_id UUID NOT NULL REFERENCES providers (id),
  expires_at TIMESTAMPTZ NOT NULL,
  revoked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_auth_sessions_subject
  ON auth_sessions (subject_id, expires_at);

-- Media CAS version for moderation/cover/delete/reorder races (Gate 9A).
ALTER TABLE venue_media
  ADD COLUMN IF NOT EXISTS cas_version INT NOT NULL DEFAULT 0;

