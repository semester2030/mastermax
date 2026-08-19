import { Pool } from 'pg';
import { newId } from '../../src/shared/ids/ids';
import {
  applyMigrationsThrough,
  applyRemainingMigrations,
} from '../helpers/migrate-partial';
import { resetDb, testEnv } from '../helpers/test-app';
import { dropPublicSchemaForCi } from '../helpers/db-safety';
import { seedProvider, seedVenue } from '../helpers/seed';

describe('Gate 7A.2 — 007 to 008 upgrade and amenity conversion FC71–FC89', () => {
  let pool: Pool;
  let linkedVenueId: string;
  let legacyVenueId: string;
  const migration = '008_gate7a2_final_contract_closure.sql';

  beforeAll(async () => {
    testEnv();
    pool = new Pool({ connectionString: process.env.DATABASE_URL });
    await dropPublicSchemaForCi(pool);
    await applyMigrationsThrough(pool, '007_gate7a1_contract_closure.sql');

    const providerId = await seedProvider(pool, `migration-${newId()}`, 'Migration fixtures');
    const linked = await seedVenue(pool, providerId, {
      name: 'Existing amenity links',
      venueType: 'hotel',
      types: [{ name: 'standard', qty: 1, nights: { '2034-01-01': '100' } }],
    });
    const legacy = await seedVenue(pool, providerId, {
      name: 'Legacy amenities',
      venueType: 'hotel',
      types: [{ name: 'standard', qty: 1, nights: { '2034-01-01': '100' } }],
    });
    linkedVenueId = linked.venueId;
    legacyVenueId = legacy.venueId;

    const existingValues: Array<[string, string | null]> = [
      ['wifi', 'true'],
      ['parking', 'YES'],
      ['pool', ' available '],
      ['breakfast', '1'],
      ['restaurant', 'false'],
      ['room_service', 'NO'],
      ['gym', ' not_available '],
      ['spa', '0'],
      ['kitchen', null],
      ['kitchenette', '   '],
      ['washing_machine', 'sometimes'],
    ];
    for (const [code, value] of existingValues) {
      await pool.query(
        `INSERT INTO venue_amenity_links
           (id, venue_id, amenity_code, scope, value, state)
         VALUES ($1,$2,$3,'venue',$4,'AVAILABLE')`,
        [newId(), linkedVenueId, code, value],
      );
    }

    const legacyValues: Array<[string, string | null]> = [
      ['balcony', 'true'],
      ['elevator', 'false'],
      ['furnished', null],
      ['private_entrance', 'unrecognized'],
    ];
    for (const [code, value] of legacyValues) {
      await pool.query(
        'INSERT INTO venue_amenities (id, venue_id, key, value) VALUES ($1,$2,$3,$4)',
        [newId(), legacyVenueId, code, value],
      );
    }

    await pool.query(
      `INSERT INTO filter_definitions
         (id, key, venue_type, label_ar, label_en, value_type, operator, indexed,
          options_json, section, status)
       VALUES ($1,'custom_gate7a2_admin','hotel','مخصص','Custom','bool','eq',false,
               '{}'::jsonb,'admin','inactive')`,
      [newId()],
    );
    await applyRemainingMigrations(pool);
  }, 120_000);

  afterAll(async () => {
    await pool.end();
  });

  async function state(venueId: string, code: string): Promise<string> {
    const result = await pool.query(
      'SELECT state FROM venue_amenity_links WHERE venue_id=$1 AND amenity_code=$2',
      [venueId, code],
    );
    expect(result.rowCount).toBe(1);
    return result.rows[0].state;
  }

  it('FC71 records the forward migration after a partial 007 install', async () => {
    const applied = await pool.query('SELECT id FROM schema_migrations WHERE id=$1', [migration]);
    // FC71: the upgrade path applies and records 008.
    expect(applied.rows).toEqual([{ id: migration }]);
  });

  it('FC72 preserves the tri-state schema contract', async () => {
    const column = await pool.query(
      `SELECT is_nullable, column_default
       FROM information_schema.columns
       WHERE table_schema='public' AND table_name='venue_amenity_links' AND column_name='state'`,
    );
    // FC72: state remains a non-null SSOT column after upgrade.
    expect(column.rows[0].is_nullable).toBe('NO');
    expect(column.rows[0].column_default).toContain('UNKNOWN');
  });

  it('FC73–FC75 maps every true-like existing value to AVAILABLE', async () => {
    // FC73: true/yes are recognized case-insensitively.
    expect([await state(linkedVenueId, 'wifi'), await state(linkedVenueId, 'parking')]).toEqual([
      'AVAILABLE',
      'AVAILABLE',
    ]);
    // FC74: surrounding whitespace on "available" is ignored.
    expect(await state(linkedVenueId, 'pool')).toBe('AVAILABLE');
    // FC75: numeric true-like value 1 is AVAILABLE.
    expect(await state(linkedVenueId, 'breakfast')).toBe('AVAILABLE');
  });

  it('FC76–FC78 maps every false-like existing value to NOT_AVAILABLE', async () => {
    // FC76: false/no are recognized case-insensitively.
    expect([
      await state(linkedVenueId, 'restaurant'),
      await state(linkedVenueId, 'room_service'),
    ]).toEqual(['NOT_AVAILABLE', 'NOT_AVAILABLE']);
    // FC77: surrounding whitespace on "not_available" is ignored.
    expect(await state(linkedVenueId, 'gym')).toBe('NOT_AVAILABLE');
    // FC78: numeric false-like value 0 is NOT_AVAILABLE.
    expect(await state(linkedVenueId, 'spa')).toBe('NOT_AVAILABLE');
  });

  it('FC79–FC81 maps null, blank, and unrecognized existing values to UNKNOWN', async () => {
    // FC79: NULL is never promoted to AVAILABLE.
    expect(await state(linkedVenueId, 'kitchen')).toBe('UNKNOWN');
    // FC80: blank/whitespace-only values are UNKNOWN.
    expect(await state(linkedVenueId, 'kitchenette')).toBe('UNKNOWN');
    // FC81: unrecognized text fails closed to UNKNOWN.
    expect(await state(linkedVenueId, 'washing_machine')).toBe('UNKNOWN');
  });

  it('FC82 applies the same conversion table to legacy backfill', async () => {
    const rows = await pool.query(
      `SELECT amenity_code, state FROM venue_amenity_links
       WHERE venue_id=$1 ORDER BY amenity_code`,
      [legacyVenueId],
    );
    // FC82: legacy and existing-link conversion cannot diverge.
    expect(rows.rows).toEqual([
      { amenity_code: 'balcony', state: 'AVAILABLE' },
      { amenity_code: 'elevator', state: 'NOT_AVAILABLE' },
      { amenity_code: 'furnished', state: 'UNKNOWN' },
      { amenity_code: 'private_entrance', state: 'UNKNOWN' },
    ]);
  });

  it('FC83 rejects states outside the tri-state vocabulary', async () => {
    await expect(
      pool.query(
        `UPDATE venue_amenity_links SET state='MAYBE'
         WHERE venue_id=$1 AND amenity_code='wifi'`,
        [linkedVenueId],
      ),
    ).rejects.toThrow();
    // FC83: a rejected write leaves the canonical state unchanged.
    expect(await state(linkedVenueId, 'wifi')).toBe('AVAILABLE');
  });

  it('FC84 keeps the AVAILABLE-only filter index', async () => {
    const index = await pool.query(
      `SELECT indexdef FROM pg_indexes
       WHERE schemaname='public' AND indexname='idx_venue_amenity_links_available'`,
    );
    // FC84: filter acceleration is explicitly limited to AVAILABLE rows.
    expect(index.rows[0].indexdef).toContain("WHERE (state = 'AVAILABLE'::text)");
  });

  it('FC85 keeps room_type inactive', async () => {
    const rows = await pool.query("SELECT DISTINCT status FROM filter_definitions WHERE key='room_type'");
    // FC85: migration closure cannot reactivate an unhandled filter.
    expect(rows.rows.every((row: { status: string }) => row.status === 'inactive')).toBe(true);
  });

  it('FC86 adds deterministic filter-definition creation timestamps', async () => {
    const column = await pool.query(
      `SELECT is_nullable, column_default FROM information_schema.columns
       WHERE table_name='filter_definitions' AND column_name='created_at'`,
    );
    // FC86: duplicate reconciliation has a non-null deterministic timestamp input.
    expect(column.rows[0].is_nullable).toBe('NO');
    expect(column.rows[0].column_default).toContain('now()');
  });

  it('FC87 enforces one filter definition per business key', async () => {
    const existing = await pool.query(
      `SELECT * FROM filter_definitions WHERE key='custom_gate7a2_admin' AND venue_type='hotel'`,
    );
    expect(existing.rowCount).toBe(1);
    await expect(
      pool.query(
        `INSERT INTO filter_definitions
           (id, key, venue_type, label_ar, label_en, value_type, operator, indexed,
            options_json, section, status)
         VALUES ($1,'custom_gate7a2_admin','hotel','آخر','Other','bool','eq',false,
                 '{}'::jsonb,'admin','inactive')`,
        [newId()],
      ),
    ).rejects.toThrow();
    // FC87: the unique business-key survivor remains singular.
    expect(
      (
        await pool.query(
          `SELECT id FROM filter_definitions
           WHERE key='custom_gate7a2_admin' AND venue_type='hotel'`,
        )
      ).rowCount,
    ).toBe(1);
  });

  it('FC88 preserves custom inactive admin definitions', async () => {
    const custom = await pool.query(
      `SELECT status, section FROM filter_definitions
       WHERE key='custom_gate7a2_admin' AND venue_type='hotel'`,
    );
    // FC88: closure migration does not delete unrelated custom definitions.
    expect(custom.rows).toEqual([{ status: 'inactive', section: 'admin' }]);
  });

  it('FC89 applyRemainingMigrations is idempotent after 008', async () => {
    const reapplied = await applyRemainingMigrations(pool);
    // FC89: schema_migrations prevents a second execution.
    expect(reapplied).toEqual([]);
  });
});

describe('Gate 7A.2 — clean 001 to 009 install FC90', () => {
  let pool: Pool;

  beforeAll(async () => {
    testEnv();
    await resetDb();
    pool = new Pool({ connectionString: process.env.DATABASE_URL });
  }, 120_000);

  afterAll(async () => {
    await pool.end();
  });

  it('FC90 installs the complete migration chain on a clean database', async () => {
    const migrations = await pool.query('SELECT id FROM schema_migrations ORDER BY id');
    expect(migrations.rows.map((row: { id: string }) => row.id)).toEqual([
      '001_init.sql',
      '002_filter_definitions.sql',
      '003_gate3a_hardening.sql',
      '004_gate3b_settlement_outbox.sql',
      '005_gate3c_financial_integrity.sql',
      '006_gate7a_filter_engine.sql',
      '007_gate7a1_contract_closure.sql',
      '008_gate7a2_final_contract_closure.sql',
      '009_gate7a3_final_closure.sql',
      '010_gate7b_search.sql',
      '011_gate7b31_search_nfc.sql',
      '012_gate7b35_slot_venue_integrity.sql',
      '013_gate7b5_perf_indexes.sql',
      '014_gate7b51_perf_playable_rating.sql',
      '015_gate7b511_media_denorm_reparent.sql',
      '016_gate7b512_denorm_reconcile.sql',
      '017_gate7b513_concurrent_media_denorm.sql',
      '018_pre_provider_media_gallery_locks.sql',
      '019_places_cloudflare_media.sql',
      '020_pre_device_rev2_locks_media_idempotency.sql',
      '021_pre_provider_corrective_closure.sql',
      '022_pre_provider_rev4_corrective.sql',
      '023_pay_at_venue_event_slot_gate9a.sql',
      '024_rc4_event_slot_kill_switch_payment_combo.sql',
      '025_rc5_half_null_payment_remediation.sql',
      '026_wave1_rc2_palace_hall_content_only.sql',
      '027_phase3_inventory_truth.sql',
    ]);
  });
});
