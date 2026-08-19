-- Gate 7B.3.5 — Event slot Template ↔ Venue integrity (non-destructive).
-- Fails loudly if existing rows violate template.venue_id = inventory.venue_id.
-- Does not rewrite or delete inconsistent data.

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM event_slot_inventory esi
    JOIN event_slot_templates est ON est.id = esi.slot_template_id
    WHERE esi.venue_id IS DISTINCT FROM est.venue_id
  ) THEN
    RAISE EXCEPTION
      'Gate 7B.3.5 migration 012 blocked: event_slot_inventory.venue_id must equal event_slot_templates.venue_id (cross-venue rows present; fix data explicitly before migrate)';
  END IF;
END $$;

-- Enable composite FK (id, venue_id) → templates
ALTER TABLE event_slot_templates
  DROP CONSTRAINT IF EXISTS event_slot_templates_id_venue_unique;
ALTER TABLE event_slot_templates
  ADD CONSTRAINT event_slot_templates_id_venue_unique UNIQUE (id, venue_id);

ALTER TABLE event_slot_inventory
  DROP CONSTRAINT IF EXISTS event_slot_inventory_template_same_venue;
ALTER TABLE event_slot_inventory
  ADD CONSTRAINT event_slot_inventory_template_same_venue
  FOREIGN KEY (slot_template_id, venue_id)
  REFERENCES event_slot_templates (id, venue_id);
