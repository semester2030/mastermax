-- Phase 3: inventory truth hardening (F-V2-008 / F-V3-011 partial)
-- Forward-only. Does not alter 001–026.

-- (1) Currency preflight: FAIL-CLOSED. Never silently rewrite historical rows.
--     If any rate_plans row is non-SAR, abort the migration so an operator
--     resolves it explicitly before SAR is enforced.
DO $$
DECLARE
  bad_count integer;
BEGIN
  SELECT count(*) INTO bad_count
  FROM rate_plans
  WHERE currency IS DISTINCT FROM 'SAR';
  IF bad_count > 0 THEN
    RAISE EXCEPTION
      'Migration 027 preflight failed: % rate_plans row(s) have a non-SAR currency. Resolve manually before applying (no silent conversion).',
      bad_count;
  END IF;
END $$;

-- (2) Duplicate active-default: explicit, deterministic repair before the
--     unique index is created (otherwise index creation would fail opaquely).
--     Keep the lowest id per inventory type as the active default; demote the rest.
DO $$
DECLARE
  dup_types integer;
BEGIN
  SELECT count(*) INTO dup_types FROM (
    SELECT inventory_type_id
    FROM rate_plans
    WHERE is_default = TRUE AND status = 'active'
    GROUP BY inventory_type_id
    HAVING count(*) > 1
  ) d;
  IF dup_types > 0 THEN
    RAISE NOTICE 'Migration 027: demoting duplicate active defaults for % inventory type(s).', dup_types;
    UPDATE rate_plans rp
    SET is_default = FALSE
    WHERE rp.is_default = TRUE
      AND rp.status = 'active'
      AND rp.id NOT IN (
        SELECT DISTINCT ON (inventory_type_id) id
        FROM rate_plans
        WHERE is_default = TRUE AND status = 'active'
        ORDER BY inventory_type_id, id ASC
      );
  END IF;
END $$;

-- (3) At most one active default rate plan per inventory type (concurrent create race).
CREATE UNIQUE INDEX IF NOT EXISTS uq_rate_plans_one_active_default
  ON rate_plans (inventory_type_id)
  WHERE is_default = TRUE AND status = 'active';

-- (4) Enforce SAR as the only supported currency for rate plans in Wave1.
--     Preflight (1) guarantees existing rows already satisfy this CHECK.
ALTER TABLE rate_plans DROP CONSTRAINT IF EXISTS rate_plans_currency_sar_chk;
ALTER TABLE rate_plans
  ADD CONSTRAINT rate_plans_currency_sar_chk CHECK (currency = 'SAR');
