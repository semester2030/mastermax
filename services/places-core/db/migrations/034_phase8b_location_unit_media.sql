-- Phase 8B: structured location catalog + venue address + per-scope video quota.
-- Does not DROP/TRUNCATE. Does not edit 001–033.

CREATE TABLE IF NOT EXISTS places_cities (
  id UUID PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  name_ar TEXT NOT NULL,
  name_en TEXT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive'))
);

CREATE TABLE IF NOT EXISTS places_districts (
  id UUID PRIMARY KEY,
  city_id UUID NOT NULL REFERENCES places_cities (id),
  code TEXT NOT NULL,
  name_ar TEXT NOT NULL,
  name_en TEXT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  UNIQUE (city_id, code)
);
CREATE INDEX IF NOT EXISTS idx_places_districts_city ON places_districts (city_id, sort_order);

ALTER TABLE venues
  ADD COLUMN IF NOT EXISTS city_id UUID REFERENCES places_cities (id),
  ADD COLUMN IF NOT EXISTS district_id UUID REFERENCES places_districts (id),
  ADD COLUMN IF NOT EXISTS street TEXT,
  ADD COLUMN IF NOT EXISTS building_no TEXT,
  ADD COLUMN IF NOT EXISTS landmark TEXT,
  ADD COLUMN IF NOT EXISTS access_notes TEXT,
  ADD COLUMN IF NOT EXISTS maps_url TEXT,
  ADD COLUMN IF NOT EXISTS location_source TEXT
    CHECK (location_source IS NULL OR location_source IN ('manual', 'geolocation', 'search', 'pin'));

CREATE INDEX IF NOT EXISTS idx_venues_city_id ON venues (city_id);
CREATE INDEX IF NOT EXISTS idx_venues_district_id ON venues (district_id);

INSERT INTO places_cities (id, code, name_ar, name_en, sort_order) VALUES
  ('01400000-0000-7000-8000-000000000001', 'riyadh', 'الرياض', 'Riyadh', 10),
  ('01400000-0000-7000-8000-000000000002', 'jeddah', 'جدة', 'Jeddah', 20),
  ('01400000-0000-7000-8000-000000000003', 'dammam', 'الدمام', 'Dammam', 30),
  ('01400000-0000-7000-8000-000000000004', 'khobar', 'الخبر', 'Khobar', 40),
  ('01400000-0000-7000-8000-000000000005', 'makkah', 'مكة المكرمة', 'Makkah', 50),
  ('01400000-0000-7000-8000-000000000006', 'madinah', 'المدينة المنورة', 'Madinah', 60),
  ('01400000-0000-7000-8000-000000000007', 'abha', 'أبها', 'Abha', 70),
  ('01400000-0000-7000-8000-000000000008', 'taif', 'الطائف', 'Taif', 80)
ON CONFLICT (id) DO NOTHING;

INSERT INTO places_districts (id, city_id, code, name_ar, name_en, sort_order) VALUES
  ('01400001-0000-7000-8000-000000000001', '01400000-0000-7000-8000-000000000001', 'olaya', 'العليا', 'Olaya', 10),
  ('01400001-0000-7000-8000-000000000002', '01400000-0000-7000-8000-000000000001', 'malaz', 'الملز', 'Malaz', 20),
  ('01400001-0000-7000-8000-000000000003', '01400000-0000-7000-8000-000000000001', 'nakheel', 'النخيل', 'Al Nakheel', 30),
  ('01400001-0000-7000-8000-000000000004', '01400000-0000-7000-8000-000000000001', 'yasmin', 'الياسمين', 'Al Yasmin', 40),
  ('01400001-0000-7000-8000-000000000005', '01400000-0000-7000-8000-000000000001', 'narjis', 'النرجس', 'Al Narjis', 50),
  ('01400001-0000-7000-8000-000000000006', '01400000-0000-7000-8000-000000000001', 'hittin', 'حطين', 'Hittin', 60),
  ('01400001-0000-7000-8000-000000000007', '01400000-0000-7000-8000-000000000001', 'sahafa', 'الصحافة', 'Al Sahafa', 70),
  ('01400001-0000-7000-8000-000000000008', '01400000-0000-7000-8000-000000000001', 'rawdah', 'الروضة', 'Al Rawdah', 80),
  ('01400001-0000-7000-8000-000000000009', '01400000-0000-7000-8000-000000000002', 'shati', 'الشاطئ', 'Ash Shati', 10),
  ('01400001-0000-7000-8000-00000000000a', '01400000-0000-7000-8000-000000000002', 'hamra', 'الحمراء', 'Al Hamra', 20),
  ('01400001-0000-7000-8000-00000000000b', '01400000-0000-7000-8000-000000000002', 'rawdah_j', 'الروضة', 'Al Rawdah', 30),
  ('01400001-0000-7000-8000-00000000000c', '01400000-0000-7000-8000-000000000002', 'zahra', 'الزهراء', 'Az Zahra', 40),
  ('01400001-0000-7000-8000-00000000000d', '01400000-0000-7000-8000-000000000003', 'faisaliyah', 'الفيصلية', 'Al Faisaliyah', 10),
  ('01400001-0000-7000-8000-00000000000e', '01400000-0000-7000-8000-000000000003', 'shati_d', 'الشاطئ', 'Ash Shati', 20),
  ('01400001-0000-7000-8000-00000000000f', '01400000-0000-7000-8000-000000000004', 'ulaya_k', 'العليا', 'Olaya', 10),
  ('01400001-0000-7000-8000-000000000010', '01400000-0000-7000-8000-000000000004', 'thuqbah', 'الثقبة', 'Ath Thuqbah', 20),
  ('01400001-0000-7000-8000-000000000011', '01400000-0000-7000-8000-000000000005', 'aziziyah', 'العزيزية', 'Al Aziziyah', 10),
  ('01400001-0000-7000-8000-000000000012', '01400000-0000-7000-8000-000000000005', 'shisha', 'الششة', 'Ash Shisha', 20),
  ('01400001-0000-7000-8000-000000000013', '01400000-0000-7000-8000-000000000006', 'quba', 'قباء', 'Quba', 10),
  ('01400001-0000-7000-8000-000000000014', '01400000-0000-7000-8000-000000000006', 'awali', 'العوالي', 'Al Awali', 20),
  ('01400001-0000-7000-8000-000000000015', '01400000-0000-7000-8000-000000000007', 'wadi', 'الوادي', 'Al Wadi', 10),
  ('01400001-0000-7000-8000-000000000016', '01400000-0000-7000-8000-000000000007', 'manhal', 'المنهل', 'Al Manhal', 20),
  ('01400001-0000-7000-8000-000000000017', '01400000-0000-7000-8000-000000000008', 'shifa', 'الشفا', 'Ash Shifa', 10),
  ('01400001-0000-7000-8000-000000000018', '01400000-0000-7000-8000-000000000008', 'hudaydah', 'الهدا', 'Al Hada', 20)
ON CONFLICT (id) DO NOTHING;

-- Backfill known city text onto catalog ids (no data wipe).
UPDATE venues v
SET city_id = c.id
FROM places_cities c
WHERE v.city_id IS NULL
  AND v.city IS NOT NULL
  AND (v.city = c.name_ar OR v.city = c.name_en OR v.city ILIKE c.code);

-- Per-scope video quota (venue-level OR inventory_type). Keep venue-level
-- places_video_quota_used() counting only inventory_type_id IS NULL.
CREATE OR REPLACE FUNCTION places_video_quota_used(p_venue_id UUID)
RETURNS INT
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  media_cnt INT;
  sess_cnt INT;
BEGIN
  SELECT COUNT(*)::int INTO media_cnt
  FROM venue_media
  WHERE venue_id = p_venue_id
    AND inventory_type_id IS NULL
    AND kind = 'video'
    AND deleted_at IS NULL
    AND moderation_status IN ('pending', 'approved');
  SELECT COUNT(*)::int INTO sess_cnt
  FROM media_upload_sessions
  WHERE venue_id = p_venue_id
    AND inventory_type_id IS NULL
    AND kind = 'video'
    AND status = 'pending'
    AND expires_at >= now();
  RETURN COALESCE(media_cnt, 0) + COALESCE(sess_cnt, 0);
END;
$$;

CREATE OR REPLACE FUNCTION places_video_quota_used_scope(p_venue_id UUID, p_inventory_type_id UUID)
RETURNS INT
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  media_cnt INT;
  sess_cnt INT;
BEGIN
  SELECT COUNT(*)::int INTO media_cnt
  FROM venue_media
  WHERE venue_id = p_venue_id
    AND kind = 'video'
    AND deleted_at IS NULL
    AND moderation_status IN ('pending', 'approved')
    AND inventory_type_id IS NOT DISTINCT FROM p_inventory_type_id;
  SELECT COUNT(*)::int INTO sess_cnt
  FROM media_upload_sessions
  WHERE venue_id = p_venue_id
    AND kind = 'video'
    AND status = 'pending'
    AND expires_at >= now()
    AND inventory_type_id IS NOT DISTINCT FROM p_inventory_type_id;
  RETURN COALESCE(media_cnt, 0) + COALESCE(sess_cnt, 0);
END;
$$;

CREATE OR REPLACE FUNCTION places_enforce_venue_video_cap()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  cnt INT;
BEGIN
  IF NEW.kind <> 'video' THEN
    RETURN NEW;
  END IF;
  IF NEW.deleted_at IS NOT NULL THEN
    RETURN NEW;
  END IF;
  IF NEW.moderation_status NOT IN ('pending', 'approved') THEN
    RETURN NEW;
  END IF;
  SELECT COUNT(*)::int INTO cnt
  FROM venue_media
  WHERE venue_id = NEW.venue_id
    AND kind = 'video'
    AND deleted_at IS NULL
    AND moderation_status IN ('pending', 'approved')
    AND inventory_type_id IS NOT DISTINCT FROM NEW.inventory_type_id
    AND id IS DISTINCT FROM NEW.id;
  IF cnt >= 3 THEN
    RAISE EXCEPTION 'VENUE_VIDEO_CAP: max 3 pending+approved videos per scope'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;
