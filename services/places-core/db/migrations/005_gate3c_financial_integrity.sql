-- Gate 3C: eligible_at, settlement stale, refund claim columns

ALTER TABLE provider_receivables
  ADD COLUMN IF NOT EXISTS eligible_at TIMESTAMPTZ;

-- eligible requires eligible_at; other statuses may keep historical eligible_at
ALTER TABLE provider_receivables DROP CONSTRAINT IF EXISTS provider_receivables_eligible_at_chk;
ALTER TABLE provider_receivables
  ADD CONSTRAINT provider_receivables_eligible_at_chk
  CHECK (status <> 'eligible' OR eligible_at IS NOT NULL);

CREATE INDEX IF NOT EXISTS idx_provider_receivables_eligible
  ON provider_receivables (provider_id, status, eligible_at);

-- Settlement may be marked stale when snapshot fails pay-time revalidation
ALTER TABLE settlements DROP CONSTRAINT IF EXISTS settlements_status_check;
ALTER TABLE settlements
  ADD CONSTRAINT settlements_status_check
  CHECK (status IN ('draft', 'approved', 'paid', 'stale'));

-- Refund multi-instance claim
ALTER TABLE refunds DROP CONSTRAINT IF EXISTS refunds_status_check;
ALTER TABLE refunds
  ADD CONSTRAINT refunds_status_check
  CHECK (status IN ('pending', 'processing', 'completed', 'failed'));

ALTER TABLE refunds
  ADD COLUMN IF NOT EXISTS locked_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS locked_by TEXT,
  ADD COLUMN IF NOT EXISTS attempt_count INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_error TEXT,
  ADD COLUMN IF NOT EXISTS next_attempt_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_refunds_claim
  ON refunds (status, created_at);
