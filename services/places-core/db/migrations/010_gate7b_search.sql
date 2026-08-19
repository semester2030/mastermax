-- Gate 7B.2 — Search document + trigram (non-destructive)
-- Forward-only; safe after 001–009.

CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Immutable NFC-ish normalize for generated column (mirrors app normalizeSearchText subset).
CREATE OR REPLACE FUNCTION places_normalize_search(t text)
RETURNS text
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
AS $$
  SELECT lower(
    btrim(
      regexp_replace(
        translate(
          regexp_replace(
            regexp_replace(
              coalesce(t, ''),
              E'[\u064B-\u065F\u0670\u06D6-\u06ED]',
              '',
              'g'
            ),
            E'\u0640',
            '',
            'g'
          ),
          E'\u0622\u0623\u0625\u0671\u0649\u06CC\u0629',
          E'\u0627\u0627\u0627\u0627\u064A\u064A\u0647'
        ),
        E'\\s+',
        ' ',
        'g'
      )
    )
  );
$$;

ALTER TABLE venues
  ADD COLUMN IF NOT EXISTS search_document text
  GENERATED ALWAYS AS (
    places_normalize_search(
      coalesce(name, '') || ' ' ||
      coalesce(city, '') || ' ' ||
      coalesce(district, '') || ' ' ||
      coalesce(venue_type, '')
    )
  ) STORED;

CREATE INDEX IF NOT EXISTS idx_venues_search_document_trgm
  ON venues USING gin (search_document gin_trgm_ops);

COMMENT ON COLUMN venues.search_document IS
  'Gate 7B.2: venue-local normalized search text; capability labels resolved query-time only.';
COMMENT ON FUNCTION places_normalize_search(text) IS
  'Gate 7B.2: immutable normalize for search_document generated column.';
