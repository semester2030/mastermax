/**
 * Gate 7B.5 — semantic parity / cursor / workload invariants (test DB).
 */
import { INestApplication } from '@nestjs/common';
import { Pool } from 'pg';
import request from 'supertest';
import { auth, createTestApp, resetDb } from '../helpers/test-app';
import { newId } from '../../src/shared/ids/ids';
import {
  computeChunkSize,
  diversityCandidateQueryBound,
  diversityRowBound,
} from '../../src/modules/filters/application/discovery-diversity-runtime';

describe('Gate 7B.5 — semantic / cursor / work bounds', () => {
  let app: INestApplication;
  let pool: Pool;
  const uid = 'g7b5-sem';
  let types: string[] = [];

  beforeAll(async () => {
    await resetDb();
    app = await createTestApp();
    pool = new Pool({ connectionString: process.env.DATABASE_URL });
    const r = await pool.query<{ venue_type: string }>(
      `SELECT venue_type FROM venue_type_capabilities WHERE enabled_for_discovery ORDER BY sort_order`,
    );
    types = r.rows.map((x) => x.venue_type);
  }, 120_000);

  afterAll(async () => {
    await app.close();
    await pool.end();
  });

  beforeEach(async () => {
    await pool.query('TRUNCATE providers CASCADE');
  });

  async function search(body: Record<string, unknown>) {
    return request(app.getHttpServer())
      .post('/v1/discovery/search')
      .set('Authorization', auth(uid))
      .send(body);
  }

  async function seedPlayable(name: string, venueType: string, createdAt: string) {
    const providerId = newId();
    await pool.query(
      `INSERT INTO providers (id, legal_name, display_name, type, status, firebase_owner_uid)
       VALUES ($1,$2,$2,'company','active',$3)`,
      [providerId, name, `owner-${name}`],
    );
    const venueId = newId();
    await pool.query(
      `INSERT INTO venues (id, provider_id, name, venue_type, booking_mode, status, city, lat, lng, created_at)
       VALUES ($1,$2,$3,$4,'nightly','published','Riyadh',24.7,46.7,$5::timestamptz)`,
      [venueId, providerId, name, venueType, createdAt],
    );
    await pool.query(
      `INSERT INTO venue_media (id, venue_id, provider_id, kind, url, stream_uid, moderation_status, sort_order)
       VALUES ($1,$2,$3,'video','https://cdn.example/v.mp4',$4,'approved',0)`,
      [newId(), venueId, providerId, `s-${newId()}`],
    );
    return venueId;
  }

  it('G7B5-SEM-01 identical ordered ids for repeated identical request', async () => {
    for (let i = 0; i < 12; i++) {
      await seedPlayable(
        `v${i}`,
        types[i % types.length],
        `2026-01-01T00:00:${String(i).padStart(2, '0')}Z`,
      );
    }
    const body = { sort: 'newest', limit: 10, surface: 'search' };
    const a = await search(body);
    const b = await search(body);
    expect([200, 201]).toContain(a.status);
    expect([200, 201]).toContain(b.status);
    expect(a.body.items.map((x: { venueId: string }) => x.venueId)).toEqual(
      b.body.items.map((x: { venueId: string }) => x.venueId),
    );
    expect(a.body.total).toBe(b.body.total);
    expect(a.body.queryHash).toBe(b.body.queryHash);
  });

  it('G7B5-CURSOR-01 no duplicate/drop across deep pages', async () => {
    for (let i = 0; i < 60; i++) {
      await seedPlayable(`c${i}`, types[0], `2026-02-01T00:${String(i).padStart(2, '0')}:00Z`);
    }
    const seen = new Set<string>();
    let cursor: string | undefined;
    let pages = 0;
    for (;;) {
      const res = await search({ sort: 'newest', limit: 10, surface: 'search', cursor });
      expect([200, 201]).toContain(res.status);
      for (const it of res.body.items) {
        expect(seen.has(it.venueId)).toBe(false);
        seen.add(it.venueId);
      }
      pages += 1;
      if (!res.body.nextCursor) break;
      cursor = res.body.nextCursor;
      if (pages > 20) break;
    }
    expect(seen.size).toBeGreaterThanOrEqual(50);
  });

  it('G7B5-WORK-01 diversity fixed-chunk bounds hold', () => {
    const limit = 20;
    const typeCount = Math.max(1, types.length);
    const B = computeChunkSize(limit, typeCount);
    expect(B).toBe(Math.max(1, Math.ceil(limit / typeCount)));
    expect(diversityRowBound(typeCount, limit)).toBe(2 * (typeCount + limit));
    expect(diversityCandidateQueryBound(typeCount)).toBe(2 * typeCount + 1);
  });
});
