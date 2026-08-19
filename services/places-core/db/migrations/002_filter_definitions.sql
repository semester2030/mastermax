INSERT INTO filter_definitions (id, key, venue_type, label_ar, value_type, operator, indexed, options_json)
VALUES
  (gen_random_uuid(), 'city', NULL, 'المدينة', 'enum', 'eq', TRUE, '[]'::jsonb),
  (gen_random_uuid(), 'price', NULL, 'السعر', 'range', 'between', TRUE, '{}'::jsonb),
  (gen_random_uuid(), 'guests', NULL, 'الضيوف', 'int', 'gte', TRUE, '{}'::jsonb),
  (gen_random_uuid(), 'stars', 'hotel', 'نجوم', 'int', 'eq', TRUE, '{}'::jsonb);
