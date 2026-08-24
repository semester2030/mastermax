-- Convert legacy physical types that are actually pooled categories.
-- Candidate: physical, quantity_total > 1, zero inventory_units, no unit occupancy.
-- Does not invent unit names. Does not touch 001–035 or types that have real units.
-- Idempotent: re-apply updates 0 rows. Quantity, occupancy, rates, media unchanged.

WITH candidates AS (
  SELECT t.id, t.inventory_model, t.quantity_total, t.name, t.label_ar, t.venue_id, t.status
  FROM inventory_types t
  WHERE t.inventory_model = 'physical'
    AND t.quantity_total > 1
    AND NOT EXISTS (
      SELECT 1 FROM inventory_units u WHERE u.inventory_type_id = t.id
    )
    AND NOT EXISTS (
      SELECT 1
      FROM inventory_unit_occupancy o
      JOIN inventory_units u ON u.id = o.inventory_unit_id
      WHERE u.inventory_type_id = t.id
    )
),
updated AS (
  UPDATE inventory_types t
  SET inventory_model = 'pooled'
  FROM candidates c
  WHERE t.id = c.id
    AND t.inventory_model = 'physical'
  RETURNING t.id, t.venue_id, t.name, t.label_ar, t.quantity_total, t.status
)
INSERT INTO audit_logs (
  id, actor_uid, actor_role, entity_type, entity_id,
  before_json, after_json, reason, correlation_id
)
SELECT
  gen_random_uuid(),
  'migration-036',
  'operator',
  'inventory_type',
  u.id::text,
  jsonb_build_object(
    'inventory_model', 'physical',
    'quantity_total', u.quantity_total,
    'name', u.name,
    'label_ar', u.label_ar,
    'status', u.status
  ),
  jsonb_build_object(
    'inventory_model', 'pooled',
    'quantity_total', u.quantity_total,
    'name', u.name,
    'label_ar', u.label_ar,
    'status', u.status,
    'venue_id', u.venue_id
  ),
  'legacy_physical_to_pooled',
  '036_pooled_inventory_semantics'
FROM updated u;

COMMENT ON COLUMN inventory_types.inventory_model IS
  'pooled = identical units by count (type name + quantity). physical = independently named units only.';
