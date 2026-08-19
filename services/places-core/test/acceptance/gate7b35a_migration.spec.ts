/**
 * Gate 7B.3.5A — migration 011→012 on isolated DATABASE_URL database.
 * Never drops public on the primary test database.
 */
import { newId } from '../../src/shared/ids/ids';
import { withIsolatedDatabase } from '../helpers/isolated-database';
import {
  applyMigrationsThrough,
  applyRemainingMigrations,
} from '../helpers/migrate-partial';
import { testEnv } from '../helpers/test-app';

describe('Gate 7B.3.5A — isolated migration 012 integrity', () => {
  beforeAll(() => {
    testEnv();
  });

  it('G7B35A-MIG-OK 011→012 preserves matching template/inventory rows', async () => {
    await withIsolatedDatabase(async (pool) => {
      const through011 = await applyMigrationsThrough(pool, '011_gate7b31_search_nfc.sql');
      expect(through011).toEqual(
        expect.arrayContaining(['011_gate7b31_search_nfc.sql']),
      );
      expect(through011.some((f) => f.startsWith('012_'))).toBe(false);

      const providerId = newId();
      const venueId = newId();
      const tplId = newId();
      const invId = newId();
      await pool.query(
        `INSERT INTO providers (id, legal_name, display_name, type, status, firebase_owner_uid)
         VALUES ($1,'ok','ok','company','active',$2)`,
        [providerId, `mig-ok-${newId().slice(0, 8)}`],
      );
      await pool.query(
        `INSERT INTO venues (id, provider_id, name, venue_type, booking_mode, status, city, min_stay)
         VALUES ($1,$2,'OK Venue','wedding_palace','nightly','published','Riyadh',1)`,
        [venueId, providerId],
      );
      await pool.query(
        `INSERT INTO event_slot_templates (id, venue_id, code, label_ar, start_time, end_time, capacity)
         VALUES ($1,$2,'evening','مسائي','18:00','23:00',100)`,
        [tplId, venueId],
      );
      await pool.query(
        `INSERT INTO event_slot_inventory (id, venue_id, slot_template_id, slot_date, status)
         VALUES ($1,$2,$3,'2030-11-01','open')`,
        [invId, venueId, tplId],
      );

      const rem = await applyRemainingMigrations(pool);
      expect(rem).toEqual(expect.arrayContaining(['012_gate7b35_slot_venue_integrity.sql']));

      const mig = await pool.query(
        `SELECT 1 FROM schema_migrations WHERE id='012_gate7b35_slot_venue_integrity.sql'`,
      );
      expect(mig.rowCount).toBe(1);

      const row = await pool.query<{ venue_id: string; slot_template_id: string }>(
        `SELECT venue_id::text, slot_template_id::text FROM event_slot_inventory WHERE id=$1`,
        [invId],
      );
      expect(row.rows).toHaveLength(1);
      expect(row.rows[0].venue_id).toBe(venueId);
      expect(row.rows[0].slot_template_id).toBe(tplId);

      const fk = await pool.query(
        `SELECT 1 FROM pg_constraint WHERE conname='event_slot_inventory_template_same_venue'`,
      );
      expect(fk.rowCount).toBe(1);
    });
  }, 180_000);

  it('G7B35A-MIG-FAIL cross-venue blocks 012 without delete or rewrite', async () => {
    await withIsolatedDatabase(async (pool) => {
      await applyMigrationsThrough(pool, '011_gate7b31_search_nfc.sql');

      const providerId = newId();
      const v1 = newId();
      const v2 = newId();
      const tpl = newId();
      const inv = newId();
      await pool.query(
        `INSERT INTO providers (id, legal_name, display_name, type, status, firebase_owner_uid)
         VALUES ($1,'bad','bad','company','active',$2)`,
        [providerId, `mig-bad-${newId().slice(0, 8)}`],
      );
      await pool.query(
        `INSERT INTO venues (id, provider_id, name, venue_type, booking_mode, status, city, min_stay)
         VALUES ($1,$3,'V1','wedding_palace','nightly','published','Riyadh',1),
                ($2,$3,'V2','wedding_palace','nightly','published','Riyadh',1)`,
        [v1, v2, providerId],
      );
      await pool.query(
        `INSERT INTO event_slot_templates (id, venue_id, code, label_ar, start_time, end_time, capacity)
         VALUES ($1,$2,'evening','مسائي','18:00','23:00',100)`,
        [tpl, v1],
      );
      // Pre-012: mismatched venue_id allowed
      await pool.query(
        `INSERT INTO event_slot_inventory (id, venue_id, slot_template_id, slot_date, status)
         VALUES ($1,$2,$3,'2030-12-01','open')`,
        [inv, v2, tpl],
      );

      const before = await pool.query<{ venue_id: string; cnt: string }>(
        `SELECT venue_id::text, COUNT(*)::text AS cnt
         FROM event_slot_inventory WHERE id=$1 GROUP BY venue_id`,
        [inv],
      );
      expect(before.rows[0].venue_id).toBe(v2);

      let failed = false;
      let errText = '';
      try {
        await applyRemainingMigrations(pool);
      } catch (e) {
        failed = true;
        errText = String(e);
      }
      expect(failed).toBe(true);
      expect(errText).toMatch(/012|cross-venue|must equal/i);

      const after = await pool.query<{ venue_id: string; slot_template_id: string }>(
        `SELECT venue_id::text, slot_template_id::text FROM event_slot_inventory WHERE id=$1`,
        [inv],
      );
      expect(after.rows).toHaveLength(1);
      expect(after.rows[0].venue_id).toBe(v2);
      expect(after.rows[0].slot_template_id).toBe(tpl);

      const mig = await pool.query(
        `SELECT 1 FROM schema_migrations WHERE id='012_gate7b35_slot_venue_integrity.sql'`,
      );
      expect(mig.rowCount).toBe(0);

      const tplStill = await pool.query(`SELECT venue_id::text FROM event_slot_templates WHERE id=$1`, [
        tpl,
      ]);
      expect(tplStill.rows[0].venue_id).toBe(v1);
    });
  }, 180_000);
});
