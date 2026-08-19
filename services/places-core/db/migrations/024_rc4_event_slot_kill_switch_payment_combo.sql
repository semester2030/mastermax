-- 024_rc4_event_slot_kill_switch_payment_combo.sql
-- Gate 9A RC4 corrective. Forward-only. Immutables: 001–023.
-- 1) Fail-closed kill switch for event_slot venue types (palace/hall).
-- 2) Explicit half-null ban on bookings.payment_method/payment_status.
-- Historical bookings remain viewable/cancellable; no table drops.

UPDATE venue_type_capabilities
SET
  enabled_for_discovery = FALSE,
  enabled_for_booking = FALSE,
  enabled_for_provider = FALSE
WHERE venue_type IN ('wedding_palace', 'event_hall')
   OR booking_semantics = 'event_slot';

-- Ban half-null payment pairs (both NULL or both NOT NULL).
ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_payment_pair_null_chk;
ALTER TABLE bookings
  ADD CONSTRAINT bookings_payment_pair_null_chk
  CHECK (
    (payment_method IS NULL AND payment_status IS NULL)
    OR (payment_method IS NOT NULL AND payment_status IS NOT NULL)
  );

-- Strengthen combo CHECK: explicit REJECT half-filled / illegal combos.
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
      WHEN status = 'CANCELLED' AND payment_method = 'PSP_CARD'
        THEN (payment_status IN ('NOT_APPLICABLE', 'CAPTURED', 'VOIDED'))
      WHEN status = 'CANCELLED' AND payment_method = 'LEGACY_UNSPECIFIED'
        THEN (payment_status = 'LEGACY_UNSPECIFIED')
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

COMMENT ON CONSTRAINT bookings_payment_pair_null_chk ON bookings IS
  'RC4: payment_method and payment_status must both be NULL or both set (no half-null).';

COMMENT ON TABLE venue_type_capabilities IS
  'RC4: wedding_palace/event_hall and booking_semantics=event_slot are kill-switched (discovery/booking/provider OFF). Re-enable only via future gate + env PLACES_EVENT_SLOT_ENABLED.';
