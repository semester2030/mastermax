-- Phase 7: event_slot provider ops support indexes.
-- Capabilities for wedding_palace / event_hall remain OFF by default
-- (enabled_for_discovery/booking stay false until external Phase 8 approval).
-- Forward-only. Does not alter 001–030.

CREATE INDEX IF NOT EXISTS idx_event_slot_inventory_venue_date_status
  ON event_slot_inventory (venue_id, slot_date, status);

CREATE INDEX IF NOT EXISTS idx_event_slot_templates_venue_active
  ON event_slot_templates (venue_id, status)
  WHERE status = 'active';

COMMENT ON INDEX idx_event_slot_inventory_venue_date_status IS
  'Phase 7: slot availability / overlap lookups. Caps stay OFF until external approval.';
