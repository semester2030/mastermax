-- Gate 3B: settlement membership, outbox claim, refund pending path support

CREATE TABLE settlement_items (
  id UUID PRIMARY KEY,
  settlement_id UUID NOT NULL REFERENCES settlements (id),
  provider_receivable_id UUID NOT NULL REFERENCES provider_receivables (id),
  booking_id UUID NOT NULL REFERENCES bookings (id),
  amount_snapshot NUMERIC(12, 2) NOT NULL CHECK (amount_snapshot >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (settlement_id, provider_receivable_id)
);
CREATE UNIQUE INDEX uq_settlement_items_receivable ON settlement_items (provider_receivable_id);
CREATE INDEX idx_settlement_items_settlement ON settlement_items (settlement_id);

-- Outbox multi-instance claim
ALTER TABLE domain_events DROP CONSTRAINT IF EXISTS domain_events_status_check;
ALTER TABLE domain_events
  ADD CONSTRAINT domain_events_status_check
  CHECK (status IN ('pending', 'processing', 'sent', 'failed'));
ALTER TABLE domain_events
  ADD COLUMN IF NOT EXISTS locked_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS locked_by TEXT;

-- Payment late-refund intermediate status (PSP call happens outside DB TX)
ALTER TABLE payments DROP CONSTRAINT IF EXISTS payments_status_check;
ALTER TABLE payments
  ADD CONSTRAINT payments_status_check
  CHECK (status IN (
    'intent', 'pending', 'succeeded', 'failed', 'cancelled',
    'refund_required', 'refunded_after_expiry'
  ));

-- Optional eligibility delay hours on venues (default 0 = eligible after COMPLETED)
ALTER TABLE venues
  ADD COLUMN IF NOT EXISTS receivable_eligibility_delay_hours INT NOT NULL DEFAULT 0
  CHECK (receivable_eligibility_delay_hours >= 0 AND receivable_eligibility_delay_hours <= 720);
