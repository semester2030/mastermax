-- Gate 3A hardening constraints
CREATE UNIQUE INDEX IF NOT EXISTS uq_settlements_provider_period
  ON settlements (provider_id, period_start, period_end);

CREATE UNIQUE INDEX IF NOT EXISTS uq_payouts_settlement
  ON payouts (settlement_id);
