-- Gate 7A — Advanced Filter Engine (additive)
-- Extends Places Core; does not replace booking/hold/payment tables.

-- ---------------------------------------------------------------------------
-- Venue discovery / attribute columns
-- ---------------------------------------------------------------------------
ALTER TABLE venues
  ADD COLUMN IF NOT EXISTS district TEXT,
  ADD COLUMN IF NOT EXISTS verified BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS stars INT CHECK (stars IS NULL OR stars BETWEEN 1 AND 5),
  ADD COLUMN IF NOT EXISTS bedrooms INT CHECK (bedrooms IS NULL OR bedrooms >= 0),
  ADD COLUMN IF NOT EXISTS bathrooms INT CHECK (bathrooms IS NULL OR bathrooms >= 0),
  ADD COLUMN IF NOT EXISTS beds INT CHECK (beds IS NULL OR beds >= 0),
  ADD COLUMN IF NOT EXISTS capacity INT CHECK (capacity IS NULL OR capacity >= 1),
  ADD COLUMN IF NOT EXISTS size_sqm NUMERIC(12, 2),
  ADD COLUMN IF NOT EXISTS rating_average NUMERIC(4, 2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS reviews_count INT NOT NULL DEFAULT 0 CHECK (reviews_count >= 0),
  ADD COLUMN IF NOT EXISTS weighted_rating NUMERIC(4, 2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS rating_sum INT NOT NULL DEFAULT 0 CHECK (rating_sum >= 0),
  ADD COLUMN IF NOT EXISTS has_active_offer BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS filter_data_completeness NUMERIC(5, 2) NOT NULL DEFAULT 0
    CHECK (filter_data_completeness >= 0 AND filter_data_completeness <= 100),
  ADD COLUMN IF NOT EXISTS attributes_jsonb JSONB NOT NULL DEFAULT '{}'::jsonb;

CREATE INDEX IF NOT EXISTS idx_venues_district ON venues (district) WHERE district IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_venues_verified ON venues (verified) WHERE verified = TRUE;
CREATE INDEX IF NOT EXISTS idx_venues_stars ON venues (stars) WHERE stars IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_venues_bedrooms ON venues (bedrooms) WHERE bedrooms IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_venues_weighted_rating ON venues (weighted_rating DESC);
CREATE INDEX IF NOT EXISTS idx_venues_rating_average ON venues (rating_average DESC);
CREATE INDEX IF NOT EXISTS idx_venues_geo ON venues (lat, lng) WHERE lat IS NOT NULL AND lng IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_venues_attributes ON venues USING GIN (attributes_jsonb);

-- Event/slot booking mode (additive; nightly/daily preserved)
ALTER TABLE venues DROP CONSTRAINT IF EXISTS venues_booking_mode_check;
ALTER TABLE venues
  ADD CONSTRAINT venues_booking_mode_check
  CHECK (booking_mode IN ('nightly', 'daily', 'event_slot'));

-- ---------------------------------------------------------------------------
-- Venue type capability controls
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS venue_type_capabilities (
  venue_type TEXT PRIMARY KEY,
  label_ar TEXT NOT NULL,
  label_en TEXT NOT NULL,
  enabled_for_discovery BOOLEAN NOT NULL DEFAULT TRUE,
  enabled_for_booking BOOLEAN NOT NULL DEFAULT TRUE,
  enabled_for_provider BOOLEAN NOT NULL DEFAULT TRUE,
  enabled_for_admin BOOLEAN NOT NULL DEFAULT TRUE,
  booking_semantics TEXT NOT NULL DEFAULT 'accommodation'
    CHECK (booking_semantics IN ('accommodation', 'event_slot')),
  sort_order INT NOT NULL DEFAULT 100,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO venue_type_capabilities (
  venue_type, label_ar, label_en, enabled_for_discovery, enabled_for_booking,
  enabled_for_provider, enabled_for_admin, booking_semantics, sort_order
) VALUES
  ('hotel', 'فنادق', 'Hotel', TRUE, TRUE, TRUE, TRUE, 'accommodation', 10),
  ('hotel_apartment', 'شقق فندقية', 'Hotel Apartment', TRUE, TRUE, TRUE, TRUE, 'accommodation', 20),
  ('serviced_apartment', 'شقق مفروشة', 'Serviced Apartment', TRUE, TRUE, TRUE, TRUE, 'accommodation', 30),
  ('apartment', 'شقق', 'Apartment', TRUE, TRUE, TRUE, TRUE, 'accommodation', 40),
  ('chalet', 'شاليهات', 'Chalet', TRUE, TRUE, TRUE, TRUE, 'accommodation', 50),
  ('rest_house', 'استراحات', 'Rest House', TRUE, TRUE, TRUE, TRUE, 'accommodation', 60),
  ('resort', 'منتجعات', 'Resort', TRUE, TRUE, TRUE, TRUE, 'accommodation', 70),
  ('villa', 'فلل', 'Villa', TRUE, TRUE, TRUE, TRUE, 'accommodation', 80),
  ('wedding_palace', 'قصور أفراح', 'Wedding Palace', FALSE, FALSE, TRUE, TRUE, 'event_slot', 90),
  ('event_hall', 'قاعات مناسبات', 'Event Hall', FALSE, FALSE, TRUE, TRUE, 'event_slot', 100)
ON CONFLICT (venue_type) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Amenity catalog (SSOT) + venue mapping
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS amenity_catalog (
  id UUID PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  label_ar TEXT NOT NULL,
  label_en TEXT NOT NULL,
  icon_key TEXT,
  applicable_venue_types TEXT[] NOT NULL DEFAULT ARRAY['*']::TEXT[],
  filterable BOOLEAN NOT NULL DEFAULT TRUE,
  display_only BOOLEAN NOT NULL DEFAULT FALSE,
  availability_mode TEXT NOT NULL DEFAULT 'static'
    CHECK (availability_mode IN ('static', 'needs_dates')),
  parent_code TEXT REFERENCES amenity_catalog (code),
  sort_order INT NOT NULL DEFAULT 100,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS venue_amenity_links (
  id UUID PRIMARY KEY,
  venue_id UUID NOT NULL REFERENCES venues (id) ON DELETE CASCADE,
  amenity_code TEXT NOT NULL REFERENCES amenity_catalog (code),
  inventory_type_id UUID REFERENCES inventory_types (id) ON DELETE CASCADE,
  scope TEXT NOT NULL DEFAULT 'venue' CHECK (scope IN ('venue', 'inventory')),
  value TEXT
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_venue_amenity_venue_scope
  ON venue_amenity_links (venue_id, amenity_code)
  WHERE inventory_type_id IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_venue_amenity_inventory_scope
  ON venue_amenity_links (venue_id, amenity_code, inventory_type_id)
  WHERE inventory_type_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_venue_amenity_links_code ON venue_amenity_links (amenity_code);
CREATE INDEX IF NOT EXISTS idx_venue_amenity_links_venue ON venue_amenity_links (venue_id);

-- ---------------------------------------------------------------------------
-- Enrich filter_definitions for schema-driven UI/engine
-- ---------------------------------------------------------------------------
ALTER TABLE filter_definitions
  ADD COLUMN IF NOT EXISTS section TEXT NOT NULL DEFAULT 'common',
  ADD COLUMN IF NOT EXISTS label_en TEXT,
  ADD COLUMN IF NOT EXISTS parent_key TEXT,
  ADD COLUMN IF NOT EXISTS source_field TEXT,
  ADD COLUMN IF NOT EXISTS availability_mode TEXT NOT NULL DEFAULT 'static'
    CHECK (availability_mode IN ('static', 'needs_dates', 'needs_location')),
  ADD COLUMN IF NOT EXISTS priority INT NOT NULL DEFAULT 100,
  ADD COLUMN IF NOT EXISTS sort_order INT NOT NULL DEFAULT 100,
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'inactive'));

CREATE INDEX IF NOT EXISTS idx_filter_definitions_type_status
  ON filter_definitions (venue_type, status, sort_order);

-- ---------------------------------------------------------------------------
-- Intent presets (map to real filter conditions — not fake attributes)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS intent_presets (
  id UUID PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  label_ar TEXT NOT NULL,
  label_en TEXT NOT NULL,
  applicable_venue_types TEXT[] NOT NULL DEFAULT ARRAY['*']::TEXT[],
  expands_to_jsonb JSONB NOT NULL DEFAULT '{}'::jsonb,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  sort_order INT NOT NULL DEFAULT 100,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Event / wedding time slots (double-booking protected)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS event_slot_templates (
  id UUID PRIMARY KEY,
  venue_id UUID NOT NULL REFERENCES venues (id) ON DELETE CASCADE,
  code TEXT NOT NULL,
  label_ar TEXT NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  capacity INT CHECK (capacity IS NULL OR capacity >= 1),
  base_price NUMERIC(12, 2),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  UNIQUE (venue_id, code),
  CHECK (end_time > start_time)
);

CREATE TABLE IF NOT EXISTS event_slot_inventory (
  id UUID PRIMARY KEY,
  venue_id UUID NOT NULL REFERENCES venues (id) ON DELETE CASCADE,
  slot_template_id UUID NOT NULL REFERENCES event_slot_templates (id) ON DELETE CASCADE,
  slot_date DATE NOT NULL,
  status TEXT NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'held', 'booked', 'blocked')),
  booking_id UUID REFERENCES bookings (id),
  hold_id UUID,
  UNIQUE (slot_template_id, slot_date)
);
CREATE INDEX IF NOT EXISTS idx_event_slot_inventory_venue_date
  ON event_slot_inventory (venue_id, slot_date, status);

-- ---------------------------------------------------------------------------
-- Seed amenity catalog
-- ---------------------------------------------------------------------------
INSERT INTO amenity_catalog (id, code, label_ar, label_en, icon_key, applicable_venue_types, filterable, sort_order)
VALUES
  (gen_random_uuid(), 'wifi', 'واي فاي', 'Wi-Fi', 'wifi', ARRAY['*'], TRUE, 10),
  (gen_random_uuid(), 'parking', 'مواقف', 'Parking', 'local_parking', ARRAY['*'], TRUE, 20),
  (gen_random_uuid(), 'pool', 'مسبح', 'Pool', 'pool', ARRAY['hotel','resort','chalet','rest_house','villa','hotel_apartment','serviced_apartment'], TRUE, 30),
  (gen_random_uuid(), 'private_pool', 'مسبح خاص', 'Private Pool', 'pool', ARRAY['chalet','villa','rest_house','resort'], TRUE, 31),
  (gen_random_uuid(), 'kids_pool', 'مسبح أطفال', 'Kids Pool', 'pool', ARRAY['chalet','rest_house','resort','hotel'], TRUE, 32),
  (gen_random_uuid(), 'indoor_pool', 'مسبح داخلي', 'Indoor Pool', 'pool', ARRAY['hotel','resort','chalet'], TRUE, 33),
  (gen_random_uuid(), 'outdoor_pool', 'مسبح خارجي', 'Outdoor Pool', 'pool', ARRAY['hotel','resort','chalet','villa','rest_house'], TRUE, 34),
  (gen_random_uuid(), 'breakfast', 'إفطار', 'Breakfast', 'free_breakfast', ARRAY['hotel','resort','hotel_apartment'], TRUE, 40),
  (gen_random_uuid(), 'restaurant', 'مطعم', 'Restaurant', 'restaurant', ARRAY['hotel','resort'], TRUE, 41),
  (gen_random_uuid(), 'room_service', 'خدمة غرف', 'Room Service', 'room_service', ARRAY['hotel','resort'], TRUE, 42),
  (gen_random_uuid(), 'gym', 'نادي رياضي', 'Gym', 'fitness_center', ARRAY['hotel','resort','serviced_apartment'], TRUE, 50),
  (gen_random_uuid(), 'spa', 'سبا', 'Spa', 'spa', ARRAY['hotel','resort'], TRUE, 51),
  (gen_random_uuid(), 'kitchen', 'مطبخ', 'Kitchen', 'kitchen', ARRAY['apartment','hotel_apartment','serviced_apartment','chalet','rest_house','villa'], TRUE, 60),
  (gen_random_uuid(), 'kitchenette', 'مطبخ صغير', 'Kitchenette', 'kitchen', ARRAY['hotel_apartment','serviced_apartment','apartment'], TRUE, 61),
  (gen_random_uuid(), 'washing_machine', 'غسالة', 'Washing Machine', 'local_laundry_service', ARRAY['apartment','hotel_apartment','serviced_apartment','villa'], TRUE, 62),
  (gen_random_uuid(), 'living_room', 'صالة', 'Living Room', 'weekend', ARRAY['apartment','hotel_apartment','serviced_apartment','chalet','villa','rest_house'], TRUE, 63),
  (gen_random_uuid(), 'balcony', 'شرفة', 'Balcony', 'balcony', ARRAY['apartment','hotel_apartment','serviced_apartment','villa'], TRUE, 64),
  (gen_random_uuid(), 'elevator', 'مصعد', 'Elevator', 'elevator', ARRAY['apartment','hotel_apartment','serviced_apartment','hotel'], TRUE, 65),
  (gen_random_uuid(), 'furnished', 'مفروش', 'Furnished', 'chair', ARRAY['apartment','serviced_apartment','hotel_apartment'], TRUE, 66),
  (gen_random_uuid(), 'private_entrance', 'مدخل خاص', 'Private Entrance', 'door_front', ARRAY['apartment','chalet','villa','rest_house','wedding_palace'], TRUE, 67),
  (gen_random_uuid(), 'majlis', 'مجلس', 'Majlis', 'weekend', ARRAY['chalet','rest_house','villa'], TRUE, 70),
  (gen_random_uuid(), 'bbq', 'شواء', 'Barbecue', 'outdoor_grill', ARRAY['chalet','rest_house','villa'], TRUE, 71),
  (gen_random_uuid(), 'outdoor_seating', 'جلسات خارجية', 'Outdoor Seating', 'deck', ARRAY['chalet','rest_house','villa','resort'], TRUE, 72),
  (gen_random_uuid(), 'garden', 'حديقة', 'Garden', 'yard', ARRAY['chalet','rest_house','villa','resort'], TRUE, 73),
  (gen_random_uuid(), 'playground', 'ملعب أطفال', 'Playground', 'child_care', ARRAY['chalet','rest_house','resort','hotel'], TRUE, 74),
  (gen_random_uuid(), 'football_field', 'ملعب كرة', 'Football Field', 'sports_soccer', ARRAY['rest_house'], TRUE, 75),
  (gen_random_uuid(), 'kids', 'مرافق أطفال', 'Kids Facilities', 'child_care', ARRAY['hotel','resort','chalet','rest_house','villa'], TRUE, 76),
  (gen_random_uuid(), 'family', 'عائلي', 'Family Friendly', 'family_restroom', ARRAY['*'], TRUE, 77),
  (gen_random_uuid(), 'honeymoon', 'عرسان', 'Honeymoon', 'favorite', ARRAY['hotel','resort','chalet','villa'], TRUE, 78),
  (gen_random_uuid(), 'privacy', 'خصوصية عالية', 'High Privacy', 'lock', ARRAY['chalet','villa','rest_house','resort'], TRUE, 79),
  (gen_random_uuid(), 'events', 'مناسبات', 'Events Allowed', 'celebration', ARRAY['chalet','rest_house','villa','wedding_palace','event_hall'], TRUE, 80),
  (gen_random_uuid(), 'men_section', 'قسم رجال', 'Men Section', 'man', ARRAY['rest_house','chalet','wedding_palace'], TRUE, 81),
  (gen_random_uuid(), 'women_section', 'قسم نساء', 'Women Section', 'woman', ARRAY['rest_house','chalet','wedding_palace'], TRUE, 82),
  (gen_random_uuid(), 'workspace', 'مساحة عمل', 'Workspace', 'desk', ARRAY['serviced_apartment','hotel','hotel_apartment'], TRUE, 83),
  (gen_random_uuid(), 'long_stay', 'إقامة طويلة', 'Long Stay', 'calendar_month', ARRAY['serviced_apartment','apartment','hotel_apartment'], TRUE, 84),
  (gen_random_uuid(), 'housekeeping', 'تنظيف', 'Housekeeping', 'cleaning_services', ARRAY['hotel_apartment','serviced_apartment','hotel'], TRUE, 85),
  (gen_random_uuid(), 'accessibility', 'إمكانية وصول', 'Accessibility', 'accessible', ARRAY['hotel','resort','event_hall','wedding_palace'], TRUE, 86),
  (gen_random_uuid(), 'business', 'أعمال', 'Business', 'business_center', ARRAY['hotel','serviced_apartment','event_hall'], TRUE, 87),
  (gen_random_uuid(), 'views', 'إطلالة', 'Views', 'visibility', ARRAY['hotel','resort','villa','chalet'], TRUE, 88),
  (gen_random_uuid(), 'private_terrace', 'تراس خاص', 'Private Terrace', 'deck', ARRAY['resort','villa'], TRUE, 89),
  (gen_random_uuid(), 'shuttle', 'نقل', 'Shuttle', 'airport_shuttle', ARRAY['resort','hotel'], TRUE, 90),
  (gen_random_uuid(), 'stage', 'منصة', 'Stage', 'theater_comedy', ARRAY['wedding_palace','event_hall'], TRUE, 100),
  (gen_random_uuid(), 'catering', 'ضيافة', 'Catering', 'restaurant', ARRAY['wedding_palace','event_hall'], TRUE, 101),
  (gen_random_uuid(), 'buffet', 'بوفيه', 'Buffet', 'restaurant', ARRAY['wedding_palace'], TRUE, 102),
  (gen_random_uuid(), 'sound_system', 'صوتيات', 'Sound System', 'speaker', ARRAY['wedding_palace','event_hall'], TRUE, 103),
  (gen_random_uuid(), 'lighting', 'إضاءة', 'Lighting', 'lightbulb', ARRAY['wedding_palace','event_hall'], TRUE, 104),
  (gen_random_uuid(), 'photography', 'تصوير', 'Photography', 'photo_camera', ARRAY['wedding_palace'], TRUE, 105),
  (gen_random_uuid(), 'bridal_room', 'غرفة عروس', 'Bridal Room', 'meeting_room', ARRAY['wedding_palace'], TRUE, 106),
  (gen_random_uuid(), 'projector', 'بروجكتر', 'Projector', 'videocam', ARRAY['event_hall'], TRUE, 107),
  (gen_random_uuid(), 'men_hall', 'قاعة رجال', 'Men Hall', 'meeting_room', ARRAY['wedding_palace'], TRUE, 108),
  (gen_random_uuid(), 'women_hall', 'قاعة نساء', 'Women Hall', 'meeting_room', ARRAY['wedding_palace'], TRUE, 109),
  (gen_random_uuid(), 'combined_hall', 'قاعة مشتركة', 'Combined Hall', 'meeting_room', ARRAY['wedding_palace','event_hall'], TRUE, 110)
ON CONFLICT (code) DO NOTHING;

UPDATE amenity_catalog SET parent_code = 'pool'
WHERE code IN ('private_pool', 'kids_pool', 'indoor_pool', 'outdoor_pool')
  AND parent_code IS NULL;

-- ---------------------------------------------------------------------------
-- Seed / refresh filter definitions (schema-driven SSOT)
-- ---------------------------------------------------------------------------
-- Clear prior seed rows (ids were random); rebuild with full metadata.
DELETE FROM filter_definitions;

INSERT INTO filter_definitions (
  id, key, venue_type, label_ar, label_en, value_type, operator, indexed,
  options_json, section, source_field, availability_mode, priority, sort_order, status, parent_key
) VALUES
  -- COMMON
  (gen_random_uuid(), 'city', NULL, 'المدينة', 'City', 'enum', 'eq', TRUE,
   '[{"id":"Riyadh","labelAr":"الرياض"},{"id":"Jeddah","labelAr":"جدة"},{"id":"Dammam","labelAr":"الدمام"}]'::jsonb,
   'location', 'venues.city', 'static', 10, 10, 'active', NULL),
  (gen_random_uuid(), 'district', NULL, 'الحي', 'District', 'enum', 'eq', TRUE,
   '[]'::jsonb, 'location', 'venues.district', 'static', 20, 20, 'active', NULL),
  (gen_random_uuid(), 'price', NULL, 'السعر', 'Price', 'range', 'between', TRUE,
   '{}'::jsonb, 'price', 'venue_media.starting_price_hint|quote', 'needs_dates', 30, 30, 'active', NULL),
  (gen_random_uuid(), 'guests', NULL, 'الضيوف', 'Guests', 'int', 'gte', TRUE,
   '{}'::jsonb, 'trip', 'inventory_types.max_occupancy|venues.capacity', 'static', 40, 40, 'active', NULL),
  (gen_random_uuid(), 'quantity', NULL, 'الوحدات', 'Units', 'int', 'gte', TRUE,
   '{}'::jsonb, 'trip', 'availability.quantity', 'needs_dates', 45, 45, 'active', NULL),
  (gen_random_uuid(), 'rating', NULL, 'التقييم', 'Rating', 'number', 'gte', TRUE,
   '[{"id":"3","labelAr":"3+"},{"id":"4","labelAr":"4+"},{"id":"4.5","labelAr":"4.5+"}]'::jsonb,
   'quality', 'venues.weighted_rating', 'static', 50, 50, 'active', NULL),
  (gen_random_uuid(), 'verified', NULL, 'موثق', 'Verified', 'bool', 'eq', TRUE,
   '{}'::jsonb, 'quality', 'venues.verified', 'static', 60, 60, 'active', NULL),
  (gen_random_uuid(), 'offers', NULL, 'عروض', 'Offers', 'bool', 'eq', TRUE,
   '{}'::jsonb, 'quality', 'venues.has_active_offer', 'static', 70, 70, 'active', NULL),
  (gen_random_uuid(), 'distance_km', NULL, 'المسافة', 'Distance', 'number', 'lte', TRUE,
   '{}'::jsonb, 'location', 'venues.lat/lng', 'needs_location', 80, 80, 'active', NULL),
  (gen_random_uuid(), 'cancellation', NULL, 'سياسة الإلغاء', 'Cancellation', 'enum', 'eq', FALSE,
   '[{"id":"flexible","labelAr":"مرنة"},{"id":"moderate","labelAr":"متوسطة"},{"id":"strict","labelAr":"صارمة"}]'::jsonb,
   'policy', 'venues.cancellation_policy_json', 'static', 90, 90, 'active', NULL),
  (gen_random_uuid(), 'amenity', NULL, 'المرافق', 'Amenities', 'amenity_set', 'contains_all', TRUE,
   '{}'::jsonb, 'amenities', 'venue_amenity_links', 'static', 100, 100, 'active', NULL),

  -- HOTEL
  (gen_random_uuid(), 'stars', 'hotel', 'نجوم', 'Stars', 'int', 'gte', TRUE,
   '[{"id":"3","labelAr":"3★"},{"id":"4","labelAr":"4★"},{"id":"5","labelAr":"5★"}]'::jsonb,
   'hotel_class', 'venues.stars', 'static', 10, 10, 'active', NULL),
  (gen_random_uuid(), 'room_type', 'hotel', 'نوع الغرفة', 'Room Type', 'enum', 'eq', FALSE,
   '[]'::jsonb, 'hotel_class', 'inventory_types.name', 'static', 20, 20, 'active', NULL),

  -- UNIT LAYOUT (apartments / chalets / villas)
  (gen_random_uuid(), 'bedrooms', 'hotel_apartment', 'غرف النوم', 'Bedrooms', 'int', 'gte', TRUE,
   '{}'::jsonb, 'unit_layout', 'venues.bedrooms', 'static', 10, 10, 'active', NULL),
  (gen_random_uuid(), 'bathrooms', 'hotel_apartment', 'الحمامات', 'Bathrooms', 'int', 'gte', TRUE,
   '{}'::jsonb, 'unit_layout', 'venues.bathrooms', 'static', 20, 20, 'active', NULL),
  (gen_random_uuid(), 'bedrooms', 'serviced_apartment', 'غرف النوم', 'Bedrooms', 'int', 'gte', TRUE,
   '{}'::jsonb, 'unit_layout', 'venues.bedrooms', 'static', 10, 10, 'active', NULL),
  (gen_random_uuid(), 'bathrooms', 'serviced_apartment', 'الحمامات', 'Bathrooms', 'int', 'gte', TRUE,
   '{}'::jsonb, 'unit_layout', 'venues.bathrooms', 'static', 20, 20, 'active', NULL),
  (gen_random_uuid(), 'bedrooms', 'apartment', 'غرف النوم', 'Bedrooms', 'int', 'gte', TRUE,
   '{}'::jsonb, 'unit_layout', 'venues.bedrooms', 'static', 10, 10, 'active', NULL),
  (gen_random_uuid(), 'bathrooms', 'apartment', 'الحمامات', 'Bathrooms', 'int', 'gte', TRUE,
   '{}'::jsonb, 'unit_layout', 'venues.bathrooms', 'static', 20, 20, 'active', NULL),
  (gen_random_uuid(), 'bedrooms', 'chalet', 'غرف النوم', 'Bedrooms', 'int', 'gte', TRUE,
   '{}'::jsonb, 'unit_layout', 'venues.bedrooms', 'static', 10, 10, 'active', NULL),
  (gen_random_uuid(), 'bedrooms', 'rest_house', 'غرف النوم', 'Bedrooms', 'int', 'gte', TRUE,
   '{}'::jsonb, 'unit_layout', 'venues.bedrooms', 'static', 10, 10, 'active', NULL),
  (gen_random_uuid(), 'capacity', 'rest_house', 'السعة', 'Capacity', 'int', 'gte', TRUE,
   '{}'::jsonb, 'unit_layout', 'venues.capacity', 'static', 5, 5, 'active', NULL),
  (gen_random_uuid(), 'bedrooms', 'resort', 'غرف النوم', 'Bedrooms', 'int', 'gte', TRUE,
   '{}'::jsonb, 'unit_layout', 'venues.bedrooms', 'static', 10, 10, 'active', NULL),
  (gen_random_uuid(), 'inventory_kind', 'resort', 'نوع الوحدة', 'Unit Kind', 'enum', 'eq', FALSE,
   '[{"id":"room","labelAr":"غرفة"},{"id":"suite","labelAr":"جناح"},{"id":"villa","labelAr":"فيلا"}]'::jsonb,
   'hotel_class', 'inventory_types.name', 'static', 15, 15, 'active', NULL),
  (gen_random_uuid(), 'bedrooms', 'villa', 'غرف النوم', 'Bedrooms', 'int', 'gte', TRUE,
   '{}'::jsonb, 'unit_layout', 'venues.bedrooms', 'static', 10, 10, 'active', NULL),
  (gen_random_uuid(), 'bathrooms', 'villa', 'الحمامات', 'Bathrooms', 'int', 'gte', TRUE,
   '{}'::jsonb, 'unit_layout', 'venues.bathrooms', 'static', 20, 20, 'active', NULL),
  (gen_random_uuid(), 'size_sqm', 'villa', 'المساحة', 'Size', 'range', 'between', FALSE,
   '{}'::jsonb, 'unit_layout', 'venues.size_sqm', 'static', 30, 30, 'active', NULL),

  -- WEDDING / EVENT
  (gen_random_uuid(), 'capacity', 'wedding_palace', 'السعة', 'Capacity', 'int', 'gte', TRUE,
   '{}'::jsonb, 'event', 'venues.capacity', 'static', 10, 10, 'active', NULL),
  (gen_random_uuid(), 'slot', 'wedding_palace', 'الفترة', 'Time Slot', 'enum', 'eq', TRUE,
   '[{"id":"morning","labelAr":"صباحي"},{"id":"evening","labelAr":"مسائي"}]'::jsonb,
   'event', 'event_slot_templates.code', 'needs_dates', 20, 20, 'active', NULL),
  (gen_random_uuid(), 'capacity', 'event_hall', 'السعة', 'Capacity', 'int', 'gte', TRUE,
   '{}'::jsonb, 'event', 'venues.capacity', 'static', 10, 10, 'active', NULL),
  (gen_random_uuid(), 'hall_type', 'event_hall', 'نوع القاعة', 'Hall Type', 'enum', 'eq', FALSE,
   '[{"id":"conference","labelAr":"مؤتمرات"},{"id":"banquet","labelAr":"حفلات"},{"id":"theatre","labelAr":"مسرح"},{"id":"meeting","labelAr":"اجتماعات"}]'::jsonb,
   'event', 'venues.attributes_jsonb.hall_type', 'static', 15, 15, 'active', NULL),
  (gen_random_uuid(), 'slot', 'event_hall', 'الفترة', 'Time Slot', 'enum', 'eq', TRUE,
   '[{"id":"morning","labelAr":"صباحي"},{"id":"evening","labelAr":"مسائي"}]'::jsonb,
   'event', 'event_slot_templates.code', 'needs_dates', 20, 20, 'active', NULL);

-- Intent presets (expand only to real engine fields)
INSERT INTO intent_presets (id, code, label_ar, label_en, applicable_venue_types, expands_to_jsonb, sort_order)
VALUES
  (gen_random_uuid(), 'family', 'عائلي', 'Family',
   ARRAY['*'], '{"amenities":["family"],"guestsMin":4}'::jsonb, 10),
  (gen_random_uuid(), 'honeymoon', 'عرسان', 'Honeymoon',
   ARRAY['hotel','resort','chalet','villa'], '{"amenities":["honeymoon","privacy"],"guestsMin":2,"guestsMax":2}'::jsonb, 20),
  (gen_random_uuid(), 'romantic', 'رومانسي', 'Romantic',
   ARRAY['hotel','resort','chalet','villa'], '{"amenities":["privacy"]}'::jsonb, 25),
  (gen_random_uuid(), 'weekend', 'عطلة نهاية الأسبوع', 'Weekend',
   ARRAY['*'], '{"intentHint":"weekend_dates"}'::jsonb, 30),
  (gen_random_uuid(), 'luxury', 'فاخر', 'Luxury',
   ARRAY['hotel','resort','villa'], '{"starsMin":4,"pricePercentile":"p75"}'::jsonb, 40),
  (gen_random_uuid(), 'budget', 'اقتصادي', 'Budget',
   ARRAY['*'], '{"pricePercentile":"p25"}'::jsonb, 50),
  (gen_random_uuid(), 'high_privacy', 'خصوصية عالية', 'High Privacy',
   ARRAY['chalet','villa','rest_house','resort'], '{"amenities":["privacy"]}'::jsonb, 60),
  (gen_random_uuid(), 'kids', 'أطفال', 'Kids',
   ARRAY['hotel','resort','chalet','rest_house','villa'], '{"amenities":["kids"]}'::jsonb, 70),
  (gen_random_uuid(), 'large_group', 'مجموعة كبيرة', 'Large Group',
   ARRAY['*'], '{"guestsMin":8}'::jsonb, 80),
  (gen_random_uuid(), 'business', 'عمل', 'Business',
   ARRAY['hotel','serviced_apartment','event_hall'], '{"amenities":["business","workspace"]}'::jsonb, 90),
  (gen_random_uuid(), 'long_stay', 'إقامة طويلة', 'Long Stay',
   ARRAY['serviced_apartment','apartment','hotel_apartment'], '{"amenities":["long_stay"],"nightsMin":7}'::jsonb, 100),
  (gen_random_uuid(), 'events', 'مناسبات', 'Events',
   ARRAY['chalet','rest_house','villa','wedding_palace','event_hall'], '{"amenities":["events"]}'::jsonb, 110)
ON CONFLICT (code) DO NOTHING;

-- Backfill amenity links from legacy free-text venue_amenities where codes match catalog
INSERT INTO venue_amenity_links (id, venue_id, amenity_code, scope, value)
SELECT gen_random_uuid(), va.venue_id, va.key, 'venue', va.value
FROM venue_amenities va
JOIN amenity_catalog ac ON ac.code = va.key
ON CONFLICT DO NOTHING;
