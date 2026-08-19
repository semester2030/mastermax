/**
 * Gate 7B.5 — deterministic 50k+ venue seed generator (no dump files).
 * Targets PERF DB only. Bulk SQL / generate_series.
 */
import { createHash } from 'crypto';
import { execSync } from 'child_process';
import { promises as fs } from 'fs';
import path from 'path';
import { Pool } from 'pg';
import {
  DATASET_SEED,
  DATASET_VERSION,
  PERF_DB_NAME,
  assertSafePerfDbName,
  dbNameFromUrl,
  recreatePerfDatabase,
  resolvePerfDatabaseUrl,
} from './perf-db-safety';

const VENUE_COUNT = 52_000;
const CITIES = [
  'Riyadh',
  'Jeddah',
  'Dammam',
  'Khobar',
  'Mecca',
  'Medina',
  'Abha',
  'Tabuk',
  'Taif',
  'Hail',
  'Najran',
  'Jazan',
];
const TYPES = [
  'hotel',
  'hotel_apartment',
  'serviced_apartment',
  'apartment',
  'chalet',
  'rest_house',
  'resort',
  'villa',
  'wedding_palace',
  'event_hall',
];
const DISCOVERY_TYPES = TYPES.slice(0, 8);

async function migrate(perfUrl: string): Promise<void> {
  execSync('npx ts-node src/shared/database/migrate.ts', {
    cwd: path.resolve(__dirname, '../..'),
    env: { ...process.env, DATABASE_URL: perfUrl, NODE_ENV: 'development' },
    stdio: 'inherit',
  });
}

async function seed(pool: Pool): Promise<Record<string, unknown>> {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS perf_dataset_meta (
      id TEXT PRIMARY KEY,
      dataset_version TEXT NOT NULL,
      dataset_seed INT NOT NULL,
      venue_count INT NOT NULL,
      content_hash TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      notes JSONB NOT NULL DEFAULT '{}'::jsonb
    )
  `);

  const existing = await pool.query(
    `SELECT * FROM perf_dataset_meta WHERE id = 'current'`,
  );
  if (existing.rowCount) {
    const row = existing.rows[0];
    if (
      row.dataset_version === DATASET_VERSION &&
      Number(row.dataset_seed) === DATASET_SEED &&
      Number(row.venue_count) >= 50_000
    ) {
      return { reused: true, meta: row };
    }
  }

  // Fresh seed path assumes empty or will truncate discovery tables carefully on PERF only.
  await pool.query('TRUNCATE providers CASCADE');

  // One provider
  await pool.query(
    `INSERT INTO providers (
       id, legal_name, display_name, type, status, firebase_owner_uid
     ) VALUES (
       '00000000-0000-4000-8000-000000000001',
       'Perf Provider', 'Perf Provider', 'company', 'active', 'perf-owner'
     )`,
  );

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(
      `CREATE TEMP TABLE _perf_cities ON COMMIT DROP AS
       SELECT * FROM unnest($1::text[]) WITH ORDINALITY AS t(city, ord)`,
      [CITIES],
    );
    await client.query(
      `CREATE TEMP TABLE _perf_types ON COMMIT DROP AS
       SELECT * FROM unnest($1::text[]) WITH ORDINALITY AS t(venue_type, ord)`,
      [TYPES],
    );

    // Venues via generate_series
    await client.query(
      `
    INSERT INTO venues (
      id, provider_id, name, venue_type, booking_mode, status,
      lat, lng, city, district, timezone,
      verified, stars, bedrooms, bathrooms, beds, capacity, size_sqm,
      rating_average, reviews_count, rating_sum, weighted_rating,
      has_active_offer, filter_data_completeness, attributes_jsonb,
      filter_values_jsonb, created_at, updated_at
    )
    SELECT
      (
        substr(md5('venue-' || g::text), 1, 8) || '-' ||
        substr(md5('venue-' || g::text), 9, 4) || '-4' ||
        substr(md5('venue-' || g::text), 14, 3) || '-8' ||
        substr(md5('venue-' || g::text), 17, 3) || '-' ||
        substr(md5('venue-' || g::text), 21, 12)
      )::uuid,
      '00000000-0000-4000-8000-000000000001'::uuid,
      CASE WHEN g % 7 = 0 THEN 'فندق Perf ' || g
           WHEN g % 7 = 1 THEN 'Chalet Perf ' || g
           WHEN g % 7 = 2 THEN 'Apartment Near Me ' || g
           WHEN g % 7 = 3 THEN 'Luxury Villa ' || g
           WHEN g % 7 = 4 THEN 'منتجع الساحل ' || g
           WHEN g % 7 = 5 THEN 'Rest House Family ' || g
           ELSE 'Hotel Apartment ' || g END,
      CASE
        WHEN g % 25 = 0 THEN (SELECT venue_type FROM _perf_types WHERE ord = 9 + (g % 2))
        ELSE (SELECT venue_type FROM _perf_types WHERE ord = ((g - 1) % 8) + 1)
      END,
      CASE WHEN g % 25 = 0 THEN 'daily' ELSE 'nightly' END,
      CASE
        WHEN g % 55 = 0 THEN 'draft'
        WHEN g % 65 = 0 THEN 'suspended'
        ELSE 'published'
      END,
      CASE
        WHEN g % 41 = 0 THEN NULL
        WHEN g % 50 < 30 THEN 24.70 + ((g % 200) * 0.0008)
        WHEN g % 50 < 40 THEN 18.20 + ((g % 80) * 0.05)
        WHEN g % 50 < 45 THEN 24.0 + ((g % 30) * 0.01)
        ELSE 21.4 + ((g % 40) * 0.02)
      END,
      CASE
        WHEN g % 41 = 0 THEN NULL
        WHEN g % 50 < 30 THEN 46.67 + ((g % 200) * 0.0008)
        WHEN g % 50 < 40 THEN 42.50 + ((g % 80) * 0.08)
        WHEN g % 50 < 45 THEN LEAST(179.9, 179.2 + ((g % 15) * 0.04))
        WHEN g % 50 < 48 THEN GREATEST(-179.9, -179.2 - ((g % 15) * 0.04))
        ELSE 39.8 + ((g % 40) * 0.03)
      END,
      (SELECT city FROM _perf_cities WHERE ord = ((g - 1) % 12) + 1),
      'District-' || lpad((((g - 1) % 100) + 1)::text, 3, '0'),
      'Asia/Riyadh',
      (g % 3 = 0),
      CASE WHEN g % 5 = 0 THEN NULL ELSE (g % 5) + 1 END,
      1 + (g % 5),
      1 + (g % 4),
      1 + (g % 6),
      2 + (g % 12),
      40 + (g % 200),
      LEAST(5.0, round(((g % 50) / 10.0)::numeric, 2)),
      (g % 400),
      ((g % 50) * (g % 400))::numeric,
      LEAST(5.0, round((((g % 50) / 10.0) * (0.85 + (g % 20) / 100.0))::numeric, 2)),
      (g % 11 = 0),
      CASE WHEN g % 9 = 0 THEN 55.0 ELSE 100.0 END,
      jsonb_build_object('seed', g, 'bucket', g % 10),
      jsonb_build_object('city', (SELECT city FROM _perf_cities WHERE ord = ((g - 1) % 12) + 1)),
      timestamptz '2024-01-01 00:00:00+03' + ((g % 50000) * interval '3 minutes'),
      now()
    FROM generate_series(1, $1) AS g
    `,
      [VENUE_COUNT],
    );
    await client.query('COMMIT');
  } catch (e) {
    await client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }

  // Inventory + rates for discoverable published venues (sample ~all published discovery)
  await pool.query(`
    INSERT INTO inventory_types (
      id, venue_id, name, inventory_model, base_occupancy, max_occupancy,
      extra_guest_amount, quantity_total, status
    )
    SELECT
      (
        substr(md5('inv-' || v.id::text), 1, 8) || '-' ||
        substr(md5('inv-' || v.id::text), 9, 4) || '-4' ||
        substr(md5('inv-' || v.id::text), 14, 3) || '-8' ||
        substr(md5('inv-' || v.id::text), 17, 3) || '-' ||
        substr(md5('inv-' || v.id::text), 21, 12)
      )::uuid,
      v.id,
      'Standard',
      'pooled',
      2,
      2 + (abs(hashtext(v.id::text)) % 6),
      50,
      1 + (abs(hashtext(v.id::text)) % 5),
      'active'
    FROM venues v
    WHERE v.status = 'published'
      AND v.venue_type = ANY($1::text[])
  `, [DISCOVERY_TYPES]);

  await pool.query(`
    INSERT INTO rate_plans (id, inventory_type_id, name, currency, is_default, status)
    SELECT
      (
        substr(md5('rp-' || it.id::text), 1, 8) || '-' ||
        substr(md5('rp-' || it.id::text), 9, 4) || '-4' ||
        substr(md5('rp-' || it.id::text), 14, 3) || '-8' ||
        substr(md5('rp-' || it.id::text), 17, 3) || '-' ||
        substr(md5('rp-' || it.id::text), 21, 12)
      )::uuid,
      it.id, 'Default', 'SAR', TRUE, 'active'
    FROM inventory_types it
  `);

  await pool.query(`
    INSERT INTO rate_rules (id, rate_plan_id, kind, amount, priority)
    SELECT
      (
        substr(md5('rr-' || rp.id::text), 1, 8) || '-' ||
        substr(md5('rr-' || rp.id::text), 9, 4) || '-4' ||
        substr(md5('rr-' || rp.id::text), 14, 3) || '-8' ||
        substr(md5('rr-' || rp.id::text), 17, 3) || '-' ||
        substr(md5('rr-' || rp.id::text), 21, 12)
      )::uuid,
      rp.id,
      'base',
      (80 + (abs(hashtext(rp.id::text)) % 920))::numeric,
      0
    FROM rate_plans rp
  `);

  // Capacity window for Same-Type dated filters (7 nights; ~40% of inventory types)
  await pool.query(`SET synchronous_commit = off`);
  await pool.query(`
    INSERT INTO inventory_daily_capacity (
      id, inventory_type_id, date, capacity, held, booked, blocked
    )
    SELECT
      gen_random_uuid(),
      it.id,
      d::date,
      it.quantity_total,
      0,
      CASE WHEN abs(hashtext(it.id::text || d::text)) % 17 = 0 THEN it.quantity_total ELSE 0 END,
      0
    FROM inventory_types it
    CROSS JOIN generate_series(DATE '2026-09-01', DATE '2026-09-07', '1 day') AS d
    WHERE abs(hashtext(it.id::text)) % 5 < 2
  `);
  await pool.query(`SET synchronous_commit = on`);
  await pool.query(`CHECKPOINT`);

  // Media: mix approved video/image, pending, rejected, none
  await pool.query(`
    INSERT INTO venue_media (
      id, venue_id, provider_id, kind, stream_uid, url, cover_url,
      moderation_status, sort_order, category, starting_price_hint
    )
    SELECT
      gen_random_uuid(),
      v.id,
      v.provider_id,
      CASE WHEN abs(hashtext(v.id::text)) % 3 = 0 THEN 'image' ELSE 'video' END,
      CASE
        WHEN abs(hashtext(v.id::text)) % 11 = 0 THEN NULL
        WHEN abs(hashtext(v.id::text)) % 3 <> 0 THEN 'stream-' || substr(v.id::text, 1, 8)
        ELSE NULL
      END,
      CASE
        WHEN abs(hashtext(v.id::text)) % 13 = 0 THEN 'http://insecure.example/v.mp4'
        WHEN abs(hashtext(v.id::text)) % 3 = 0 THEN 'https://cdn.example/img/' || substr(v.id::text, 1, 8) || '.jpg'
        ELSE 'https://cdn.example/vid/' || substr(v.id::text, 1, 8) || '.mp4'
      END,
      'https://cdn.example/cover/' || substr(v.id::text, 1, 8) || '.jpg',
      CASE
        WHEN abs(hashtext(v.id::text)) % 19 = 0 THEN 'pending'
        WHEN abs(hashtext(v.id::text)) % 29 = 0 THEN 'rejected'
        ELSE 'approved'
      END,
      0,
      'primary',
      (100 + (abs(hashtext(v.id::text)) % 800))::numeric
    FROM venues v
    WHERE abs(hashtext(v.id::text)) % 7 <> 0  -- ~14% no media
  `);

  // Amenities (~half of published discovery venues)
  await pool.query(`
    INSERT INTO venue_amenity_links (id, venue_id, amenity_code, scope, state)
    SELECT gen_random_uuid(), v.id, a.code, 'venue', 'AVAILABLE'
    FROM venues v
    JOIN LATERAL (
      SELECT code FROM amenity_catalog
      WHERE filterable = TRUE
      ORDER BY code
      OFFSET (abs(hashtext(v.id::text)) % 5)
      LIMIT 3
    ) a ON TRUE
    WHERE v.status = 'published'
      AND v.venue_type = ANY($1::text[])
      AND abs(hashtext(v.id::text)) % 2 = 0
    ON CONFLICT DO NOTHING
  `, [DISCOVERY_TYPES]);

  await pool.query('ANALYZE');

  const counts = await pool.query(`
    SELECT
      (SELECT COUNT(*)::int FROM venues) AS venues,
      (SELECT COUNT(*)::int FROM venues v
         JOIN venue_type_capabilities c ON c.venue_type = v.venue_type
        WHERE v.status = 'published' AND c.enabled_for_discovery) AS discoverable,
      (SELECT COUNT(DISTINCT city)::int FROM venues) AS cities,
      (SELECT COUNT(DISTINCT district)::int FROM venues) AS districts,
      (SELECT COUNT(*)::int FROM inventory_types) AS inventory_types,
      (SELECT COUNT(*)::int FROM inventory_daily_capacity) AS daily_capacity,
      (SELECT COUNT(*)::int FROM venue_media) AS media,
      (SELECT COUNT(*)::int FROM venue_media
        WHERE kind='video' AND moderation_status='approved'
          AND ((stream_uid IS NOT NULL AND btrim(stream_uid)<>'')
            OR (url IS NOT NULL AND url ~* '^https://'))) AS playable_videos,
      (SELECT COUNT(*)::int FROM venue_amenity_links) AS amenity_links,
      (SELECT COUNT(*)::int FROM rate_rules) AS rate_rules
  `);

  const c = counts.rows[0];
  const hash = createHash('sha256')
    .update(
      JSON.stringify({
        version: DATASET_VERSION,
        seed: DATASET_SEED,
        venues: c.venues,
        discoverable: c.discoverable,
      }),
    )
    .digest('hex');

  await pool.query(
    `INSERT INTO perf_dataset_meta (id, dataset_version, dataset_seed, venue_count, content_hash, notes)
     VALUES ('current', $1, $2, $3, $4, $5::jsonb)
     ON CONFLICT (id) DO UPDATE SET
       dataset_version = EXCLUDED.dataset_version,
       dataset_seed = EXCLUDED.dataset_seed,
       venue_count = EXCLUDED.venue_count,
       content_hash = EXCLUDED.content_hash,
       notes = EXCLUDED.notes,
       created_at = now()`,
    [
      DATASET_VERSION,
      DATASET_SEED,
      c.venues,
      hash,
      JSON.stringify(c),
    ],
  );

  if (Number(c.venues) < 50_000) {
    throw new Error(`seed failed: venues=${c.venues} < 50000`);
  }
  if (Number(c.discoverable) < 40_000) {
    throw new Error(`seed failed: discoverable=${c.discoverable} < 40000`);
  }
  if (Number(c.cities) < 10) {
    throw new Error(`seed failed: cities=${c.cities} < 10`);
  }
  if (Number(c.districts) < 100) {
    throw new Error(`seed failed: districts=${c.districts} < 100`);
  }

  return { reused: false, counts: c, content_hash: hash };
}

async function main(): Promise<void> {
  const force = process.argv.includes('--force');
  const { perfUrl, dbName } = await resolvePerfDatabaseUrl();
  assertSafePerfDbName(dbName);
  if (dbNameFromUrl(process.env.DATABASE_URL || '') === dbName && dbName === 'places_core_test') {
    throw new Error('REFUSED: would mutate test DB');
  }

  let url = perfUrl;
  if (force) {
    const adminBase = process.env.DATABASE_URL;
    if (!adminBase) throw new Error('DATABASE_URL required for --force recreate');
    // Use admin URL but connect to postgres db for DROP/CREATE
    const admin = new URL(adminBase);
    admin.pathname = '/postgres';
    url = await recreatePerfDatabase(admin.toString(), PERF_DB_NAME);
  }

  process.stdout.write(`PERF_DB=${dbName}\nURL_DB=${dbNameFromUrl(url)}\n`);
  await migrate(url);
  const pool = new Pool({ connectionString: url, max: 10 });
  try {
    const result = await seed(pool);
    const outDir = path.resolve(
      __dirname,
      '../../../../docs/places_core_gate7b51/raw',
    );
    await fs.mkdir(outDir, { recursive: true });
    const envInfo = await pool.query(`
      SELECT version() AS pg_version,
             current_setting('shared_buffers') AS shared_buffers,
             current_setting('work_mem') AS work_mem,
             current_setting('random_page_cost') AS random_page_cost,
             current_setting('effective_cache_size') AS effective_cache_size
    `);
    const payload = {
      dataset_version: DATASET_VERSION,
      dataset_seed: DATASET_SEED,
      dbName,
      result,
      env: envInfo.rows[0],
      pool: { max: 10 },
      ts: new Date().toISOString(),
    };
    await fs.writeFile(
      path.join(outDir, 'DATASET_SEED_RESULT.json'),
      JSON.stringify(payload, null, 2),
    );
    process.stdout.write(JSON.stringify(payload, null, 2) + '\n');
  } finally {
    await pool.end();
  }
}

main().catch((err) => {
  process.stderr.write(String(err?.stack || err) + '\n');
  process.exit(1);
});
