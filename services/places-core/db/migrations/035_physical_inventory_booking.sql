-- Physical inventory booking: assign a specific inventory_unit on quote/hold/booking.
-- Occupancy exclusion prevents overlapping stays on the same unit.
-- Does not alter migrations 001–034 or pooled daily-capacity math.

CREATE EXTENSION IF NOT EXISTS btree_gist;

ALTER TABLE quotes
  ADD COLUMN IF NOT EXISTS inventory_unit_id UUID REFERENCES inventory_units (id);

ALTER TABLE booking_holds
  ADD COLUMN IF NOT EXISTS inventory_unit_id UUID REFERENCES inventory_units (id);

ALTER TABLE bookings
  ADD COLUMN IF NOT EXISTS inventory_unit_id UUID REFERENCES inventory_units (id);

CREATE TABLE IF NOT EXISTS inventory_unit_occupancy (
  id UUID PRIMARY KEY,
  inventory_unit_id UUID NOT NULL REFERENCES inventory_units (id),
  hold_id UUID NOT NULL REFERENCES booking_holds (id),
  booking_id UUID REFERENCES bookings (id),
  check_in DATE NOT NULL,
  check_out DATE NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('held', 'booked')),
  CONSTRAINT inventory_unit_occupancy_range
    EXCLUDE USING gist (
      inventory_unit_id WITH =,
      daterange(check_in, check_out, '[)') WITH &&
    )
);

CREATE INDEX IF NOT EXISTS idx_unit_occupancy_hold ON inventory_unit_occupancy (hold_id);
CREATE INDEX IF NOT EXISTS idx_unit_occupancy_unit ON inventory_unit_occupancy (inventory_unit_id, status);

COMMENT ON TABLE inventory_unit_occupancy IS
  'Physical unit stay occupancy. Gist exclusion prevents overlapping holds/bookings on the same unit.';
