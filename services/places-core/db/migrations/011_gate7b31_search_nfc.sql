-- Gate 7B.3.1 — Align places_normalize_search with TypeScript NFC normalize.
-- Non-destructive to venue rows; rebuilds generated search_document only.

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
              normalize(coalesce(t, ''), NFC),
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

-- Generated columns pin the prior function body; rebuild to pick up NFC.
ALTER TABLE venues DROP COLUMN IF EXISTS search_document;

ALTER TABLE venues
  ADD COLUMN search_document text
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

COMMENT ON FUNCTION places_normalize_search(text) IS
  'Gate 7B.3.1: NFC + AR/EN normalize matching TypeScript normalizeSearchText.';
COMMENT ON COLUMN venues.search_document IS
  'Gate 7B.3.1: venue-local NFC-normalized search text; capability labels query-time only.';
