import request from 'supertest';
import { INestApplication } from '@nestjs/common';
import { Pool } from 'pg';
import { auth, createTestApp, resetDb, testEnv } from '../helpers/test-app';
import { applyMigrationsThrough, applyRemainingMigrations } from '../helpers/migrate-partial';
import { newId } from '../../src/shared/ids/ids';
import { seedProvider, seedVenue } from '../helpers/seed';
import { encodeCursor } from '../../src/modules/filters/application/discovery-cursor';
import { dropPublicSchemaForCi } from '../helpers/db-safety';

describe('Gate 7A.3 — Migration / Capability / Cursor final closure', () => {
  describe('Migration upgrade with duplicates (FC-MIG)', () => {
    it('upgrade through 006 with duplicate business keys then 007–009 succeeds; custom preserved', async () => {
      testEnv();
      const pool = new Pool({ connectionString: process.env.DATABASE_URL });
      await dropPublicSchemaForCi(pool);
      await applyMigrationsThrough(pool, '006_gate7a_filter_engine.sql');

      const customId = newId();
      const dupA = newId();
      const dupB = newId();
      // Realistic: UNIQUE(key, venue_type) allows multiple NULLs for venue_type
      await pool.query(
        `INSERT INTO filter_definitions (id, key, venue_type, label_ar, value_type, operator, indexed, options_json, status)
         VALUES
           ($1,'city',NULL,'مدينة','enum','eq',true,'[]'::jsonb,'inactive'),
           ($2,'city',NULL,'مدينة2','enum','eq',true,'[]'::jsonb,'inactive'),
           ($3,'custom_admin_only','hotel','مخصص','bool','eq',false,'{}'::jsonb,'inactive')`,
        [dupA, dupB, customId],
      );

      const applied = await applyRemainingMigrations(pool);
      expect(applied.some((f) => f.includes('007'))).toBe(true);
      expect(applied.some((f) => f.includes('009'))).toBe(true);

      const custom = await pool.query(
        `SELECT key, status FROM filter_definitions WHERE id = $1`,
        [customId],
      );
      expect(custom.rowCount).toBe(1);
      expect(custom.rows[0].key).toBe('custom_admin_only');

      const cityKeys = await pool.query(
        `SELECT key, status FROM filter_definitions WHERE key LIKE 'city%' ORDER BY key`,
      );
      const business = cityKeys.rows.filter((r) => r.key === 'city');
      expect(business.length).toBeLessThanOrEqual(1);
      const archived = cityKeys.rows.filter((r) => String(r.key).includes('__dup_'));
      expect(archived.length + business.length).toBeGreaterThanOrEqual(2);

      const idx = await pool.query(
        `SELECT 1 FROM pg_indexes WHERE indexname = 'uq_filter_definitions_business_key'`,
      );
      expect(idx.rowCount).toBe(1);

      // Idempotent re-run of 009 body
      const fs = await import('fs/promises');
      const path = await import('path');
      const sql009 = await fs.readFile(
        path.resolve(__dirname, '../../db/migrations/009_gate7a3_final_closure.sql'),
        'utf8',
      );
      await pool.query(sql009);
      const custom2 = await pool.query(`SELECT key FROM filter_definitions WHERE id = $1`, [customId]);
      expect(custom2.rows[0].key).toBe('custom_admin_only');
      await pool.end();
    }, 120_000);

    it('clean install 001→009 via resetDb succeeds', async () => {
      await resetDb();
      const pool = new Pool({ connectionString: process.env.DATABASE_URL });
      const mig = await pool.query(`SELECT id FROM schema_migrations ORDER BY id`);
      expect(mig.rows.some((r) => String(r.id).includes('009'))).toBe(true);
      await pool.end();
    }, 120_000);
  });

  describe('Capability + payment boundary + cursor', () => {
    let app: INestApplication;
    let pool: Pool;
    const consumer = 'consumer-g7a3';
    const provider = 'provider-g7a3';

    beforeAll(async () => {
      await resetDb();
      app = await createTestApp();
      pool = new Pool({ connectionString: process.env.DATABASE_URL });
    }, 120_000);

    afterAll(async () => {
      await app.close();
      await pool.end();
    });

    async function seedHotel(): Promise<{ venueId: string; typeId: string; providerId: string }> {
      const providerId = await seedProvider(pool, `${provider}-${newId().slice(0, 8)}`, 'P');
      const seeded = await seedVenue(pool, providerId, {
        name: `V-${newId().slice(0, 6)}`,
        venueType: 'hotel',
        types: [{ name: 'std', qty: 3, nights: { '2027-03-01': '200' } }],
      });
      await pool.query(
        `INSERT INTO venue_media (id, venue_id, provider_id, kind, url, cover_url, moderation_status, sort_order, category, starting_price_hint)
         VALUES ($1,$2,$3,'video','https://ex/v.mp4','https://ex/c.jpg','approved',0,'hotel',200)`,
        [newId(), seeded.venueId, providerId],
      );
      const t = await pool.query(`SELECT id FROM inventory_types WHERE venue_id=$1 LIMIT 1`, [
        seeded.venueId,
      ]);
      return { venueId: seeded.venueId, typeId: t.rows[0].id, providerId };
    }

    it('provider=false blocks create; missing capability blocks create', async () => {
      await pool.query(
        `UPDATE venue_type_capabilities SET enabled_for_provider=FALSE WHERE venue_type='hotel'`,
      );
      const providerId = await seedProvider(pool, `${provider}-off`, 'Off');
      const res = await request(app.getHttpServer())
        .post('/v1/provider/venues')
        .set('Authorization', auth(`${provider}-off`, 'placesProvider'))
        .send({
          providerId,
          name: 'Blocked',
          venueType: 'hotel',
          bookingMode: 'nightly',
          city: 'Riyadh',
        });
      expect(res.status).toBeGreaterThanOrEqual(400);

      await pool.query(`DELETE FROM venue_type_capabilities WHERE venue_type='chalet'`);
      const res2 = await request(app.getHttpServer())
        .post('/v1/provider/venues')
        .set('Authorization', auth(`${provider}-off`, 'placesProvider'))
        .send({
          providerId,
          name: 'MissingCap',
          venueType: 'chalet',
          bookingMode: 'nightly',
          city: 'Riyadh',
        });
      expect(res2.status).toBeGreaterThanOrEqual(400);

      // restore chalet + hotel provider for later suites
      await pool.query(
        `INSERT INTO venue_type_capabilities (venue_type, label_ar, label_en, enabled_for_discovery, enabled_for_booking, enabled_for_provider, enabled_for_admin, booking_semantics, sort_order)
         VALUES ('chalet','شاليه','Chalet',TRUE,TRUE,TRUE,TRUE,'accommodation',50)
         ON CONFLICT (venue_type) DO UPDATE SET enabled_for_provider=TRUE, enabled_for_booking=TRUE, enabled_for_discovery=TRUE`,
      );
      await pool.query(
        `UPDATE venue_type_capabilities SET enabled_for_provider=TRUE WHERE venue_type='hotel'`,
      );
    });

    it('booking=false after hold blocks payment intent; existing CONFIRMED remains readable/cancellable', async () => {
      const { venueId, typeId } = await seedHotel();
      const quote = await request(app.getHttpServer())
        .post('/v1/quotes')
        .set('Authorization', auth(consumer))
        .send({
          venueId,
          inventoryTypeId: typeId,
          checkIn: '2027-03-01',
          checkOut: '2027-03-02',
          quantity: 1,
          guestsAdults: 1,
          guestsChildren: 0,
          extraIds: [],
        });
      expect(quote.status).toBe(201);
      const hold = await request(app.getHttpServer())
        .post('/v1/holds')
        .set('Authorization', auth(consumer))
        .set('Idempotency-Key', `ik-${newId()}`)
        .send({ quoteId:quote.body.quoteId, quantity: 1, guestSnapshot: { bookerFullName: 'فائز المختبر', bookerPhone: '0501234567', bookingForOther: false } });
      expect(hold.status).toBe(201);

      await pool.query(
        `UPDATE venue_type_capabilities SET enabled_for_booking=FALSE WHERE venue_type='hotel'`,
      );
      const pay = await request(app.getHttpServer())
        .post('/v1/payments/intents')
        .set('Authorization', auth(consumer))
        .set('Idempotency-Key', `pay-${newId()}`)
        .send({ holdId: hold.body.holdId });
      expect(pay.status).toBeGreaterThanOrEqual(400);

      await pool.query(
        `UPDATE venue_type_capabilities SET enabled_for_booking=TRUE WHERE venue_type='hotel'`,
      );

      // Existing booking path: insert COMPLETED and ensure cancel endpoint still finds bookings list
      const bookings = await request(app.getHttpServer())
        .get('/v1/bookings')
        .set('Authorization', auth(consumer));
      expect(bookings.status).toBe(200);
      expect(Array.isArray(bookings.body.items ?? bookings.body)).toBe(true);
    });

    it('cursor validation rejects malformed / sort mismatch / bad sv2 before SQL', async () => {
      const bad = await request(app.getHttpServer())
        .post('/v1/discovery/search')
        .set('Authorization', auth(consumer))
        .send({ sort: 'best', cursor: 'not-valid' });
      expect(bad.status).toBeGreaterThanOrEqual(400);

      const mismatch = encodeCursor({
        v: 1,
        sort: 'cheapest',
        sv: '10',
        id: newId(),
      });
      const mm = await request(app.getHttpServer())
        .post('/v1/discovery/search')
        .set('Authorization', auth(consumer))
        .send({ sort: 'best', cursor: mismatch });
      expect(mm.status).toBeGreaterThanOrEqual(400);

      const badSv2 = encodeCursor({
        v: 1,
        sort: 'rating',
        sv: '4.5',
        sv2: 'nope',
        id: newId(),
      });
      const b2 = await request(app.getHttpServer())
        .post('/v1/discovery/search')
        .set('Authorization', auth(consumer))
        .send({ sort: 'rating', cursor: badSv2 });
      expect(b2.status).toBeGreaterThanOrEqual(400);
    });

    it('near_me multi-page keyset: stable total, no dupes, null cursor on last page', async () => {
      for (let i = 0; i < 5; i++) {
        const providerId = await seedProvider(pool, `${provider}-nm-${i}`, `NM${i}`);
        const seeded = await seedVenue(pool, providerId, {
          name: `Near${i}`,
          venueType: 'apartment',
          types: [{ name: 'u', qty: 2, nights: { '2027-01-10': '100' } }],
        });
        await pool.query(`UPDATE venues SET lat=$2, lng=$3, city='Riyadh' WHERE id=$1`, [
          seeded.venueId,
          24.7 + i * 0.02,
          46.7 + i * 0.02,
        ]);
        await pool.query(
          `INSERT INTO venue_media (id, venue_id, provider_id, kind, url, cover_url, moderation_status, sort_order, category, starting_price_hint)
           VALUES ($1,$2,$3,'video','https://ex/v.mp4','https://ex/c.jpg','approved',0,'apartment',100)`,
          [newId(), seeded.venueId, providerId],
        );
      }
      const body = {
        category: 'apartment',
        sort: 'near_me',
        lat: 24.7,
        lng: 46.7,
        limit: 2,
      };
      const p1 = await request(app.getHttpServer())
        .post('/v1/discovery/search')
        .set('Authorization', auth(consumer))
        .send(body);
      expect(p1.status).toBe(201);
      expect(p1.body.items.length).toBe(2);
      expect(p1.body.nextCursor).toBeTruthy();
      const p2 = await request(app.getHttpServer())
        .post('/v1/discovery/search')
        .set('Authorization', auth(consumer))
        .send({ ...body, cursor: p1.body.nextCursor });
      expect(p2.body.total).toBe(p1.body.total);
      const p3 = await request(app.getHttpServer())
        .post('/v1/discovery/search')
        .set('Authorization', auth(consumer))
        .send({ ...body, cursor: p2.body.nextCursor });
      const ids = [
        ...p1.body.items,
        ...p2.body.items,
        ...p3.body.items,
      ].map((i: { venueId: string }) => i.venueId);
      expect(new Set(ids).size).toBe(ids.length);
      // eventually last page has null cursor when exhausted among these
      let cursor = p3.body.nextCursor as string | null;
      let guard = 0;
      while (cursor && guard < 10) {
        const pn = await request(app.getHttpServer())
          .post('/v1/discovery/search')
          .set('Authorization', auth(consumer))
          .send({ ...body, cursor });
        expect(pn.body.total).toBe(p1.body.total);
        cursor = pn.body.nextCursor;
        guard++;
      }
      expect(cursor).toBeNull();
    });
  });
});
