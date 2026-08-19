CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE providers (
  id UUID PRIMARY KEY,
  legal_name TEXT NOT NULL,
  display_name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('individual', 'company')),
  status TEXT NOT NULL CHECK (status IN ('pending', 'active', 'suspended', 'rejected')),
  iban_encrypted TEXT,
  vat_number TEXT,
  firebase_owner_uid TEXT NOT NULL UNIQUE,
  commission_bps_override INT CHECK (commission_bps_override IS NULL OR (commission_bps_override >= 0 AND commission_bps_override <= 10000)),
  settlement_mode TEXT NOT NULL DEFAULT 'weekly_batch' CHECK (settlement_mode IN ('weekly_batch', 'per_booking')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_providers_status ON providers (status);

CREATE TABLE provider_users (
  id UUID PRIMARY KEY,
  provider_id UUID NOT NULL REFERENCES providers (id),
  firebase_uid TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('owner', 'manager', 'front_desk', 'finance', 'content', 'pricing')),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'disabled')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (provider_id, firebase_uid)
);
CREATE INDEX idx_provider_users_uid ON provider_users (firebase_uid);

CREATE TABLE provider_roles (
  id UUID PRIMARY KEY,
  provider_user_id UUID NOT NULL REFERENCES provider_users (id),
  permission_key TEXT NOT NULL,
  UNIQUE (provider_user_id, permission_key)
);

CREATE TABLE venues (
  id UUID PRIMARY KEY,
  provider_id UUID NOT NULL REFERENCES providers (id),
  name TEXT NOT NULL,
  venue_type TEXT NOT NULL,
  booking_mode TEXT NOT NULL CHECK (booking_mode IN ('nightly', 'daily')),
  status TEXT NOT NULL CHECK (status IN ('draft', 'published', 'suspended')),
  lat DOUBLE PRECISION,
  lng DOUBLE PRECISION,
  city TEXT,
  timezone TEXT NOT NULL DEFAULT 'Asia/Riyadh',
  check_in_time TEXT,
  check_out_time TEXT,
  min_stay INT NOT NULL DEFAULT 1 CHECK (min_stay >= 1),
  max_stay INT CHECK (max_stay IS NULL OR max_stay >= min_stay),
  hold_ttl_seconds INT NOT NULL DEFAULT 720 CHECK (hold_ttl_seconds BETWEEN 300 AND 1200),
  cancellation_policy_json JSONB NOT NULL DEFAULT '{"free_until_hours_before_checkin":48,"fee_bps_after":5000}'::jsonb,
  filter_values_jsonb JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_venues_status_type_city ON venues (status, venue_type, city);
CREATE INDEX idx_venues_filters ON venues USING GIN (filter_values_jsonb);

CREATE TABLE inventory_types (
  id UUID PRIMARY KEY,
  venue_id UUID NOT NULL REFERENCES venues (id),
  name TEXT NOT NULL,
  inventory_model TEXT NOT NULL CHECK (inventory_model IN ('pooled', 'physical')),
  base_occupancy INT NOT NULL DEFAULT 2 CHECK (base_occupancy >= 1),
  max_occupancy INT NOT NULL DEFAULT 4 CHECK (max_occupancy >= base_occupancy),
  extra_guest_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
  quantity_total INT NOT NULL CHECK (quantity_total >= 0),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (venue_id, name)
);

CREATE TABLE venue_media (
  id UUID PRIMARY KEY,
  venue_id UUID NOT NULL REFERENCES venues (id),
  inventory_type_id UUID REFERENCES inventory_types (id),
  provider_id UUID NOT NULL REFERENCES providers (id),
  kind TEXT NOT NULL CHECK (kind IN ('video', 'image')),
  stream_uid TEXT,
  url TEXT,
  cover_url TEXT,
  purpose TEXT,
  moderation_status TEXT NOT NULL DEFAULT 'pending' CHECK (moderation_status IN ('pending', 'approved', 'rejected')),
  duration_seconds INT,
  sort_order INT NOT NULL DEFAULT 0,
  category TEXT,
  ranking_metadata_jsonb JSONB NOT NULL DEFAULT '{}'::jsonb,
  starting_price_hint NUMERIC(12, 2),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_venue_media_venue ON venue_media (venue_id, moderation_status, sort_order);

CREATE TABLE venue_amenities (
  id UUID PRIMARY KEY,
  venue_id UUID NOT NULL REFERENCES venues (id),
  key TEXT NOT NULL,
  value TEXT,
  UNIQUE (venue_id, key)
);

CREATE TABLE inventory_units (
  id UUID PRIMARY KEY,
  inventory_type_id UUID NOT NULL REFERENCES inventory_types (id),
  label TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('active', 'maintenance', 'oos', 'blocked')),
  UNIQUE (inventory_type_id, label)
);

CREATE TABLE availability_rules (
  id UUID PRIMARY KEY,
  inventory_type_id UUID NOT NULL REFERENCES inventory_types (id),
  dow_mask INT NOT NULL DEFAULT 127,
  is_open BOOLEAN NOT NULL DEFAULT TRUE,
  effective_from DATE,
  effective_to DATE
);

CREATE TABLE availability_overrides (
  id UUID PRIMARY KEY,
  inventory_type_id UUID NOT NULL REFERENCES inventory_types (id),
  inventory_unit_id UUID REFERENCES inventory_units (id),
  date DATE NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('block', 'open', 'maintenance')),
  reason TEXT,
  UNIQUE (inventory_type_id, inventory_unit_id, date, kind)
);

CREATE TABLE inventory_daily_capacity (
  id UUID PRIMARY KEY,
  inventory_type_id UUID NOT NULL REFERENCES inventory_types (id),
  date DATE NOT NULL,
  capacity INT NOT NULL CHECK (capacity >= 0),
  held INT NOT NULL DEFAULT 0 CHECK (held >= 0),
  booked INT NOT NULL DEFAULT 0 CHECK (booked >= 0),
  blocked INT NOT NULL DEFAULT 0 CHECK (blocked >= 0),
  available INT GENERATED ALWAYS AS (capacity - held - booked - blocked) STORED,
  CONSTRAINT inventory_buckets_fit CHECK (held + booked + blocked <= capacity),
  UNIQUE (inventory_type_id, date)
);
CREATE INDEX idx_daily_capacity_type_date ON inventory_daily_capacity (inventory_type_id, date);

CREATE TABLE rate_plans (
  id UUID PRIMARY KEY,
  inventory_type_id UUID NOT NULL REFERENCES inventory_types (id),
  name TEXT NOT NULL,
  currency TEXT NOT NULL DEFAULT 'SAR',
  is_default BOOLEAN NOT NULL DEFAULT TRUE,
  status TEXT NOT NULL DEFAULT 'active'
);

CREATE TABLE rate_rules (
  id UUID PRIMARY KEY,
  rate_plan_id UUID NOT NULL REFERENCES rate_plans (id),
  kind TEXT NOT NULL CHECK (kind IN ('base', 'weekday', 'weekend', 'date_range')),
  amount NUMERIC(12, 2) NOT NULL CHECK (amount >= 0),
  date_from DATE,
  date_to DATE,
  priority INT NOT NULL DEFAULT 0
);

CREATE TABLE extras (
  id UUID PRIMARY KEY,
  venue_id UUID NOT NULL REFERENCES venues (id),
  name TEXT NOT NULL,
  amount NUMERIC(12, 2) NOT NULL CHECK (amount >= 0),
  per TEXT NOT NULL CHECK (per IN ('stay', 'night', 'guest')),
  status TEXT NOT NULL DEFAULT 'active'
);

CREATE TABLE promo_codes (
  id UUID PRIMARY KEY,
  provider_id UUID REFERENCES providers (id),
  code TEXT NOT NULL UNIQUE,
  kind TEXT NOT NULL CHECK (kind IN ('percent', 'amount')),
  value NUMERIC(12, 2) NOT NULL CHECK (value >= 0),
  status TEXT NOT NULL DEFAULT 'active'
);

CREATE TABLE quotes (
  id UUID PRIMARY KEY,
  consumer_firebase_uid TEXT NOT NULL,
  venue_id UUID NOT NULL REFERENCES venues (id),
  inventory_type_id UUID NOT NULL REFERENCES inventory_types (id),
  check_in DATE NOT NULL,
  check_out DATE NOT NULL,
  quantity INT NOT NULL DEFAULT 1 CHECK (quantity >= 1),
  guests_adults INT NOT NULL DEFAULT 1,
  guests_children INT NOT NULL DEFAULT 0,
  currency TEXT NOT NULL DEFAULT 'SAR',
  subtotal NUMERIC(12, 2) NOT NULL,
  extras_total NUMERIC(12, 2) NOT NULL DEFAULT 0,
  discount_total NUMERIC(12, 2) NOT NULL DEFAULT 0,
  tax_total NUMERIC(12, 2) NOT NULL DEFAULT 0,
  gross_total NUMERIC(12, 2) NOT NULL,
  commission_bps INT NOT NULL,
  commission_amount NUMERIC(12, 2) NOT NULL,
  provider_net NUMERIC(12, 2) NOT NULL,
  pricing_version TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('open', 'consumed', 'expired')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_quotes_consumer ON quotes (consumer_firebase_uid, created_at DESC);

CREATE TABLE quote_items (
  id UUID PRIMARY KEY,
  quote_id UUID NOT NULL REFERENCES quotes (id),
  kind TEXT NOT NULL CHECK (kind IN ('night', 'extra', 'discount', 'fee')),
  date DATE,
  label TEXT NOT NULL,
  amount NUMERIC(12, 2) NOT NULL,
  qty INT NOT NULL DEFAULT 1
);

CREATE TABLE booking_holds (
  id UUID PRIMARY KEY,
  quote_id UUID NOT NULL UNIQUE REFERENCES quotes (id),
  inventory_type_id UUID NOT NULL REFERENCES inventory_types (id),
  consumer_firebase_uid TEXT NOT NULL,
  quantity INT NOT NULL CHECK (quantity >= 1),
  check_in DATE NOT NULL,
  check_out DATE NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('ACTIVE', 'CONVERTED', 'EXPIRED', 'RELEASED')),
  expires_at TIMESTAMPTZ NOT NULL,
  extensions INT NOT NULL DEFAULT 0 CHECK (extensions >= 0 AND extensions <= 1),
  idempotency_key TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_holds_expiry ON booking_holds (status, expires_at);

CREATE SEQUENCE booking_code_seq START 1;

CREATE TABLE bookings (
  id UUID PRIMARY KEY,
  hold_id UUID UNIQUE REFERENCES booking_holds (id),
  quote_id UUID NOT NULL REFERENCES quotes (id),
  venue_id UUID NOT NULL REFERENCES venues (id),
  provider_id UUID NOT NULL REFERENCES providers (id),
  inventory_type_id UUID NOT NULL REFERENCES inventory_types (id),
  consumer_firebase_uid TEXT NOT NULL,
  human_code TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL,
  quantity INT NOT NULL,
  check_in DATE NOT NULL,
  check_out DATE NOT NULL,
  currency TEXT NOT NULL DEFAULT 'SAR',
  gross_total NUMERIC(12, 2) NOT NULL,
  commission_bps INT NOT NULL,
  commission_amount NUMERIC(12, 2) NOT NULL,
  provider_net NUMERIC(12, 2) NOT NULL,
  cancellation_policy_snapshot_json JSONB NOT NULL,
  confirmed_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_bookings_provider ON bookings (provider_id, status);
CREATE INDEX idx_bookings_consumer ON bookings (consumer_firebase_uid, created_at DESC);

CREATE TABLE booking_items (
  id UUID PRIMARY KEY,
  booking_id UUID NOT NULL REFERENCES bookings (id),
  inventory_type_id UUID NOT NULL REFERENCES inventory_types (id),
  date DATE NOT NULL,
  quantity INT NOT NULL,
  night_amount NUMERIC(12, 2) NOT NULL
);

CREATE TABLE booking_guests (
  id UUID PRIMARY KEY,
  booking_id UUID NOT NULL REFERENCES bookings (id),
  name TEXT NOT NULL,
  phone TEXT
);

CREATE TABLE payments (
  id UUID PRIMARY KEY,
  booking_id UUID REFERENCES bookings (id),
  hold_id UUID NOT NULL REFERENCES booking_holds (id),
  quote_id UUID NOT NULL REFERENCES quotes (id),
  status TEXT NOT NULL CHECK (status IN ('intent', 'pending', 'succeeded', 'failed', 'cancelled', 'refunded_after_expiry')),
  amount NUMERIC(12, 2) NOT NULL,
  currency TEXT NOT NULL DEFAULT 'SAR',
  psp_name TEXT NOT NULL,
  psp_intent_id TEXT UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE payment_attempts (
  id UUID PRIMARY KEY,
  payment_id UUID NOT NULL REFERENCES payments (id),
  status TEXT NOT NULL,
  psp_attempt_id TEXT,
  error_code TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE refunds (
  id UUID PRIMARY KEY,
  payment_id UUID NOT NULL REFERENCES payments (id),
  booking_id UUID NOT NULL REFERENCES bookings (id),
  amount NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
  reason TEXT NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('full', 'partial', 'customer_cancel', 'provider_cancel', 'operational', 'failed_service', 'dispute', 'after_expiry')),
  status TEXT NOT NULL CHECK (status IN ('pending', 'completed', 'failed')),
  psp_refund_id TEXT UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE ledger_entries (
  id UUID PRIMARY KEY,
  booking_id UUID REFERENCES bookings (id),
  payment_id UUID,
  provider_id UUID REFERENCES providers (id),
  amount NUMERIC(12, 2) NOT NULL CHECK (amount >= 0),
  currency TEXT NOT NULL DEFAULT 'SAR',
  direction TEXT NOT NULL CHECK (direction IN ('debit', 'credit')),
  type TEXT NOT NULL CHECK (type IN (
    'customer_payment', 'dar_commission', 'provider_receivable', 'refund',
    'payout', 'settlement', 'adjustment', 'fee', 'reversal'
  )),
  status TEXT NOT NULL DEFAULT 'posted' CHECK (status = 'posted'),
  reference TEXT,
  created_by TEXT NOT NULL,
  idempotency_key TEXT NOT NULL UNIQUE,
  correlation_id TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_ledger_booking ON ledger_entries (booking_id);
CREATE INDEX idx_ledger_provider ON ledger_entries (provider_id, created_at);

CREATE TABLE commissions (
  id UUID PRIMARY KEY,
  booking_id UUID NOT NULL UNIQUE REFERENCES bookings (id),
  ledger_entry_id UUID NOT NULL REFERENCES ledger_entries (id),
  amount NUMERIC(12, 2) NOT NULL,
  bps INT NOT NULL
);

CREATE TABLE provider_receivables (
  id UUID PRIMARY KEY,
  booking_id UUID NOT NULL UNIQUE REFERENCES bookings (id),
  provider_id UUID NOT NULL REFERENCES providers (id),
  amount NUMERIC(12, 2) NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('pending', 'eligible', 'held', 'paid', 'adjusted')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE settlements (
  id UUID PRIMARY KEY,
  provider_id UUID NOT NULL REFERENCES providers (id),
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  gross NUMERIC(12, 2) NOT NULL DEFAULT 0,
  commission NUMERIC(12, 2) NOT NULL DEFAULT 0,
  refunds NUMERIC(12, 2) NOT NULL DEFAULT 0,
  net NUMERIC(12, 2) NOT NULL DEFAULT 0,
  status TEXT NOT NULL CHECK (status IN ('draft', 'approved', 'paid')),
  mode TEXT NOT NULL CHECK (mode IN ('weekly_batch', 'per_booking')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE payouts (
  id UUID PRIMARY KEY,
  settlement_id UUID NOT NULL REFERENCES settlements (id),
  provider_id UUID NOT NULL REFERENCES providers (id),
  amount NUMERIC(12, 2) NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('stub_pending', 'stub_paid', 'failed')),
  iban_fingerprint TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE reviews (
  id UUID PRIMARY KEY,
  booking_id UUID NOT NULL UNIQUE REFERENCES bookings (id),
  venue_id UUID NOT NULL REFERENCES venues (id),
  consumer_firebase_uid TEXT NOT NULL,
  rating INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  body TEXT,
  status TEXT NOT NULL DEFAULT 'published',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE notifications (
  id UUID PRIMARY KEY,
  event_name TEXT NOT NULL,
  channel TEXT NOT NULL,
  target_uid TEXT,
  payload_json JSONB NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE audit_logs (
  id UUID PRIMARY KEY,
  actor_uid TEXT NOT NULL,
  actor_role TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  before_json JSONB,
  after_json JSONB,
  reason TEXT,
  correlation_id TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE webhook_events (
  id UUID PRIMARY KEY,
  psp_name TEXT NOT NULL,
  provider_event_id TEXT NOT NULL,
  payload_hash TEXT NOT NULL,
  processed_at TIMESTAMPTZ,
  status TEXT NOT NULL,
  UNIQUE (psp_name, provider_event_id)
);

CREATE TABLE idempotency_keys (
  key TEXT PRIMARY KEY,
  request_hash TEXT NOT NULL,
  response_code INT NOT NULL,
  response_body JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ
);

CREATE TABLE filter_definitions (
  id UUID PRIMARY KEY,
  key TEXT NOT NULL,
  venue_type TEXT,
  label_ar TEXT NOT NULL,
  value_type TEXT NOT NULL,
  operator TEXT NOT NULL,
  indexed BOOLEAN NOT NULL DEFAULT FALSE,
  options_json JSONB,
  UNIQUE (key, venue_type)
);

CREATE TABLE domain_events (
  id UUID PRIMARY KEY,
  name TEXT NOT NULL,
  payload_json JSONB NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('pending', 'sent', 'failed')),
  attempts INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_domain_events_status ON domain_events (status, created_at);

CREATE FUNCTION prevent_ledger_mutation() RETURNS trigger AS $$
BEGIN
  RAISE EXCEPTION 'ledger_entries are append-only';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_ledger_no_update
  BEFORE UPDATE OR DELETE ON ledger_entries
  FOR EACH ROW EXECUTE FUNCTION prevent_ledger_mutation();

CREATE FUNCTION prevent_audit_delete() RETURNS trigger AS $$
BEGIN
  RAISE EXCEPTION 'audit_logs cannot be deleted';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit_no_delete
  BEFORE DELETE ON audit_logs
  FOR EACH ROW EXECUTE FUNCTION prevent_audit_delete();

CREATE FUNCTION prevent_quote_money_update() RETURNS trigger AS $$
BEGIN
  IF NEW.subtotal IS DISTINCT FROM OLD.subtotal
     OR NEW.gross_total IS DISTINCT FROM OLD.gross_total
     OR NEW.commission_amount IS DISTINCT FROM OLD.commission_amount
     OR NEW.provider_net IS DISTINCT FROM OLD.provider_net THEN
    RAISE EXCEPTION 'quote money fields are immutable';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_quote_money_immutable
  BEFORE UPDATE ON quotes
  FOR EACH ROW EXECUTE FUNCTION prevent_quote_money_update();
