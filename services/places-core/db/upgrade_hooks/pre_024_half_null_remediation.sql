-- Shared half-null payment pair remediation (RC6).
-- Invoked by migrate runners IMMEDIATELY BEFORE applying 024 so that
-- 023→024→025 upgrades with dirty half-null data succeed deterministically.
-- Never invents PSP financial state. Safe no-op when columns absent or clean.
-- NOT a numbered schema_migrations entry — upgrade tooling only.

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'bookings' AND column_name = 'payment_method'
  ) THEN
    RETURN;
  END IF;

  -- Pre-confirm / holding-class: clear both sides.
  UPDATE bookings
  SET payment_method = NULL, payment_status = NULL
  WHERE (
      (payment_method IS NULL AND payment_status IS NOT NULL)
      OR (payment_method IS NOT NULL AND payment_status IS NULL)
    )
    AND status IN ('HOLDING', 'EXPIRED', 'PENDING_PAYMENT', 'PAYMENT_FAILED');

  -- CANCELLED half-null: clear both.
  UPDATE bookings
  SET payment_method = NULL, payment_status = NULL
  WHERE (
      (payment_method IS NULL AND payment_status IS NOT NULL)
      OR (payment_method IS NOT NULL AND payment_status IS NULL)
    )
    AND status = 'CANCELLED';

  -- Remaining half-null → LEGACY_UNSPECIFIED pair (explicit non-PSP legacy).
  UPDATE bookings
  SET payment_method = 'LEGACY_UNSPECIFIED',
      payment_status = 'LEGACY_UNSPECIFIED'
  WHERE (
      (payment_method IS NULL AND payment_status IS NOT NULL)
      OR (payment_method IS NOT NULL AND payment_status IS NULL)
    );

  IF EXISTS (
    SELECT 1 FROM bookings
    WHERE (payment_method IS NULL) <> (payment_status IS NULL)
  ) THEN
    RAISE EXCEPTION
      'RC6 pre-024 STOP: unresolved half-null payment_method/payment_status rows remain';
  END IF;
END $$;
