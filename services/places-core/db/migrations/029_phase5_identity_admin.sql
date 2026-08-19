-- Phase 5: identity / admin / multi-provider auth bindings
-- Forward-only. Does not alter 001–028.

-- Multi-provider operator/provider phone bindings (replaces single-phone env-only model).
CREATE TABLE IF NOT EXISTS auth_provider_identities (
  id UUID PRIMARY KEY,
  phone_hash TEXT NOT NULL,
  provider_id UUID NOT NULL REFERENCES providers (id),
  status TEXT NOT NULL CHECK (status IN ('active', 'disabled', 'pending_kyc')),
  display_label TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (phone_hash, provider_id)
);

CREATE INDEX IF NOT EXISTS idx_auth_provider_identities_phone
  ON auth_provider_identities (phone_hash) WHERE status = 'active';

COMMENT ON TABLE auth_provider_identities IS
  'Phase 5: multi-provider auth bindings by phone_hash. Staging may still use env fallback when empty.';

-- Bind each OTP challenge to the provider being onboarded/acted for.
ALTER TABLE auth_otp_challenges
  ADD COLUMN IF NOT EXISTS provider_id UUID REFERENCES providers (id);

CREATE INDEX IF NOT EXISTS idx_auth_otp_challenges_provider
  ON auth_otp_challenges (provider_id) WHERE consumed_at IS NULL;

-- Durable OTP attempt ledger (survives verify TX rollback).
CREATE TABLE IF NOT EXISTS auth_otp_attempt_events (
  id UUID PRIMARY KEY,
  challenge_id UUID NOT NULL REFERENCES auth_otp_challenges (id),
  attempt_no INT NOT NULL,
  outcome TEXT NOT NULL CHECK (outcome IN ('invalid', 'locked', 'success')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_auth_otp_attempt_events_challenge
  ON auth_otp_attempt_events (challenge_id, created_at DESC);
