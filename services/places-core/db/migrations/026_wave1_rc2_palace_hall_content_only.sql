-- 026_wave1_rc2_palace_hall_content_only.sql
-- Wave1 RC2: allow provider create of wedding_palace / event_hall for
-- content + media only. Discovery and booking stay OFF.
-- event_slot booking path remains gated by PLACES_EVENT_SLOT_ENABLED (fail-closed).
-- Forward-only. Does not rewrite 001–025.

UPDATE venue_type_capabilities
SET
  enabled_for_provider = TRUE,
  enabled_for_discovery = FALSE,
  enabled_for_booking = FALSE
WHERE venue_type IN ('wedding_palace', 'event_hall');

COMMENT ON TABLE venue_type_capabilities IS
  'Wave1 RC2: palace/hall enabled_for_provider=TRUE for content+media; discovery/booking remain OFF. event_slot booking stays fail-closed via PLACES_EVENT_SLOT_ENABLED.';
