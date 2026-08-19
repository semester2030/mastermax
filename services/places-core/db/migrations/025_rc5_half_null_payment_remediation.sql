-- 025_rc5_half_null_payment_remediation.sql
-- Gate 9A RC5 residual closure. Forward-only. Immutables: 001–024.
-- Deterministic half-null payment pair remediation for residual rows
-- (e.g. constraint deferred/absent after 024). Never invents PSP financial state.
-- NOTE: Half-null present at 023→024 boundary STOPs at immutable 024
-- (bookings_payment_pair_null_chk ADD fails). Clean or STOP before 024.
-- After remediation, STOP if any half-null remains.

-- 1) Pre-confirm / holding-class: clear both sides (no invented method/status).
UPDATE bookings
SET payment_method = NULL, payment_status = NULL
WHERE (
    (payment_method IS NULL AND payment_status IS NOT NULL)
    OR (payment_method IS NOT NULL AND payment_status IS NULL)
  )
  AND status IN ('HOLDING', 'EXPIRED', 'PENDING_PAYMENT', 'PAYMENT_FAILED');

-- 2) CANCELLED half-null: clear both (VOIDED pair only when PAY_AT_VENUE was complete).
UPDATE bookings
SET payment_method = NULL, payment_status = NULL
WHERE (
    (payment_method IS NULL AND payment_status IS NOT NULL)
    OR (payment_method IS NOT NULL AND payment_status IS NULL)
  )
  AND status = 'CANCELLED';

-- 3) Other statuses half-null → LEGACY_UNSPECIFIED pair (explicit non-PSP legacy).
UPDATE bookings
SET payment_method = 'LEGACY_UNSPECIFIED',
    payment_status = 'LEGACY_UNSPECIFIED'
WHERE (
    (payment_method IS NULL AND payment_status IS NOT NULL)
    OR (payment_method IS NOT NULL AND payment_status IS NULL)
  );

-- 4) STOP if any half-null remains (operator must intervene).
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM bookings
    WHERE (payment_method IS NULL) <> (payment_status IS NULL)
  ) THEN
    RAISE EXCEPTION
      '025 STOP: unresolved half-null payment_method/payment_status rows remain';
  END IF;
END $$;

-- 5) Re-assert pair constraint idempotently (safe if 024 already applied).
ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_payment_pair_null_chk;
ALTER TABLE bookings
  ADD CONSTRAINT bookings_payment_pair_null_chk
  CHECK (
    (payment_method IS NULL AND payment_status IS NULL)
    OR (payment_method IS NOT NULL AND payment_status IS NOT NULL)
  );

COMMENT ON CONSTRAINT bookings_payment_pair_null_chk ON bookings IS
  'RC5: payment_method and payment_status must both be NULL or both set; 025 remediates half-null on upgrade then STOP.';

-- 6) Inventory type DTO parity: label_ar + sort_order (name remains unique code).
ALTER TABLE inventory_types
  ADD COLUMN IF NOT EXISTS label_ar TEXT;
ALTER TABLE inventory_types
  ADD COLUMN IF NOT EXISTS sort_order INT NOT NULL DEFAULT 0;
UPDATE inventory_types SET label_ar = name WHERE label_ar IS NULL OR btrim(label_ar) = '';
ALTER TABLE inventory_types
  ALTER COLUMN label_ar SET DEFAULT '';
ALTER TABLE inventory_types
  ALTER COLUMN label_ar SET NOT NULL;
