-- Phase 4: PAV ops + DAR commission receivables + payment CHECKs + migration checksums
-- Forward-only. Does not alter 001–027.

-- ---------------------------------------------------------------------------
-- 1) Migration checksum support (schema_migrations.checksum)
-- ---------------------------------------------------------------------------
ALTER TABLE schema_migrations
  ADD COLUMN IF NOT EXISTS checksum TEXT;

COMMENT ON COLUMN schema_migrations.checksum IS
  'SHA-256 hex of migration file contents at apply time. Runner rejects later content drift.';

-- ---------------------------------------------------------------------------
-- 2) Payment status: COLLECTED_AT_VENUE for PAV operational cycle
-- ---------------------------------------------------------------------------
ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_payment_status_chk;
ALTER TABLE bookings
  ADD CONSTRAINT bookings_payment_status_chk CHECK (
    payment_status IS NULL
    OR payment_status IN (
      'DUE_AT_VENUE',
      'COLLECTED_AT_VENUE',
      'VOIDED',
      'NOT_APPLICABLE',
      'CAPTURED',
      'LEGACY_UNSPECIFIED'
    )
  );

-- ---------------------------------------------------------------------------
-- 3) Payment combo CHECK for PAV lifecycle (collect / active / complete / no-show)
-- ---------------------------------------------------------------------------
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
      WHEN status = 'CONFIRMED' AND payment_method = 'PAY_AT_VENUE'
        THEN (payment_status IN ('DUE_AT_VENUE', 'COLLECTED_AT_VENUE'))
      WHEN status IN ('ACTIVE', 'COMPLETED') AND payment_method = 'PAY_AT_VENUE'
        THEN (payment_status = 'COLLECTED_AT_VENUE')
      WHEN status = 'NO_SHOW' AND payment_method = 'PAY_AT_VENUE'
        THEN (payment_status = 'VOIDED')
      WHEN status IN (
        'DISPUTED', 'REFUND_PENDING', 'REFUNDED'
      ) AND payment_method = 'PAY_AT_VENUE'
        THEN (payment_status IN ('DUE_AT_VENUE', 'COLLECTED_AT_VENUE', 'VOIDED'))
      WHEN payment_method = 'LEGACY_UNSPECIFIED'
        THEN (payment_status = 'LEGACY_UNSPECIFIED')
      WHEN payment_method = 'PSP_CARD'
        THEN (payment_status IN ('NOT_APPLICABLE', 'CAPTURED'))
      ELSE FALSE
    END
  );

COMMENT ON CONSTRAINT bookings_payment_combo_chk ON bookings IS
  'Phase 4: PAV CONFIRMED may be DUE or COLLECTED; ACTIVE/COMPLETED require COLLECTED; NO_SHOW/CANCELLED PAV = VOIDED.';

-- ---------------------------------------------------------------------------
-- 4) Canonical DAR commission receivables (PAV: provider collected gross;
--    DAR is owed commission — NEVER a provider_receivable / provider payout)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dar_commission_receivables (
  id UUID PRIMARY KEY,
  booking_id UUID NOT NULL REFERENCES bookings (id),
  provider_id UUID NOT NULL REFERENCES providers (id),
  amount NUMERIC(12, 2) NOT NULL CHECK (amount >= 0),
  currency TEXT NOT NULL CHECK (currency = 'SAR'),
  status TEXT NOT NULL CHECK (
    status IN ('pending_completion', 'due', 'pending_transfer', 'paid', 'voided')
  ),
  collected_at TIMESTAMPTZ,
  due_at TIMESTAMPTZ,
  external_transfer_ref TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT dar_commission_receivables_paid_requires_transfer_chk CHECK (
    status <> 'paid' OR (external_transfer_ref IS NOT NULL AND length(trim(external_transfer_ref)) > 0)
  )
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_dar_commission_receivables_booking
  ON dar_commission_receivables (booking_id);

CREATE INDEX IF NOT EXISTS idx_dar_commission_receivables_provider_status
  ON dar_commission_receivables (provider_id, status);

COMMENT ON TABLE dar_commission_receivables IS
  'Phase 4: DAR commission owed by provider after PAV collect. Amount = booking.commission_amount snapshot (never recalculated).';

-- ---------------------------------------------------------------------------
-- 5) Settlements: allow pending_transfer (no stub_paid path in application)
-- ---------------------------------------------------------------------------
ALTER TABLE settlements DROP CONSTRAINT IF EXISTS settlements_status_check;
ALTER TABLE settlements DROP CONSTRAINT IF EXISTS settlements_status_chk;
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'settlements'::regclass AND contype = 'c'
      AND pg_get_constraintdef(oid) ILIKE '%status%'
  ) THEN
    -- Drop any remaining status CHECK by name discovery
    PERFORM 1;
  END IF;
END $$;

-- Recreate a permissive-enough status check if the table uses one from 001.
ALTER TABLE settlements DROP CONSTRAINT IF EXISTS settlements_status_check;
ALTER TABLE settlements
  DROP CONSTRAINT IF EXISTS settlements_status_chk;

-- 001 used: CHECK (status IN ('draft', 'approved', 'paid'))
-- Discover and replace:
DO $$
DECLARE
  cname text;
BEGIN
  FOR cname IN
    SELECT conname FROM pg_constraint
    WHERE conrelid = 'settlements'::regclass AND contype = 'c'
      AND pg_get_constraintdef(oid) ILIKE '%draft%'
  LOOP
    EXECUTE format('ALTER TABLE settlements DROP CONSTRAINT %I', cname);
  END LOOP;
  ALTER TABLE settlements
    ADD CONSTRAINT settlements_status_chk
    CHECK (status IN ('draft', 'approved', 'pending_transfer', 'paid', 'stale'));
END $$;

-- ---------------------------------------------------------------------------
-- 6) Reinforce SAR-only + default rate-plan uniqueness (idempotent with 027)
-- ---------------------------------------------------------------------------
ALTER TABLE rate_plans DROP CONSTRAINT IF EXISTS rate_plans_currency_sar_chk;
ALTER TABLE rate_plans
  ADD CONSTRAINT rate_plans_currency_sar_chk CHECK (currency = 'SAR');

CREATE UNIQUE INDEX IF NOT EXISTS uq_rate_plans_one_active_default
  ON rate_plans (inventory_type_id)
  WHERE is_default = TRUE AND status = 'active';

-- Physical inventory remains fail-closed for booking (app-enforced; document here).
COMMENT ON TABLE inventory_types IS
  'Phase 4: physical inventory_model remains non-bookable (fail-closed) until its dedicated phase.';
