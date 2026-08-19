import { INestApplication } from '@nestjs/common';
import { Pool } from 'pg';
import request from 'supertest';
import { newId } from '../../src/shared/ids/ids';
import { auth, createTestApp, resetDb, testEnv } from '../helpers/test-app';
import { seedProvider, seedVenue } from '../helpers/seed';

describe('Gate 7A.2 — Feed surface FC46–FC53', () => {
  let app: INestApplication;
  let pool: Pool;
  const consumer = 'consumer-fc7a2-feed';

  beforeAll(async () => {
    testEnv();
    await resetDb();
    app = await createTestApp();
    pool = new Pool({ connectionString: process.env.DATABASE_URL });
  }, 120_000);

  beforeEach(async () => {
    await pool.query('TRUNCATE providers CASCADE');
  });

  afterAll(async () => {
    await app.close();
    await pool.end();
  });

  async function seedCandidate(
    name: string,
    media?: { kind: 'video' | 'image'; moderation: 'approved' | 'pending' | 'rejected' },
  ): Promise<string> {
    const providerId = await seedProvider(pool, `feed-${name}-${newId()}`, name);
    const venue = await seedVenue(pool, providerId, {
      name,
      venueType: 'hotel',
      types: [{ name: 'standard', qty: 3, nights: { '2032-01-01': '200' } }],
    });
    if (media) {
      const url =
        media.kind === 'video'
          ? `https://customer-abc.cloudflarestream.com/${encodeURIComponent(name)}/manifest/video.m3u8`
          : `https://imagedelivery.net/stub/${encodeURIComponent(name)}/public`;
      await pool.query(
        `INSERT INTO venue_media
           (id, venue_id, provider_id, kind, url, cover_url, moderation_status, sort_order, category, starting_price_hint)
         VALUES ($1,$2,$3,$4,$5,'https://imagedelivery.net/stub/cover/public',$6,0,'hotel',200)`,
        [newId(), venue.venueId, providerId, media.kind, url, media.moderation],
      );
    }
    return venue.venueId;
  }

  function search(body: Record<string, unknown>) {
    return request(app.getHttpServer())
      .post('/v1/discovery/search')
      .set('Authorization', auth(consumer))
      .send(body);
  }

  it('FC46 accepts every declared discovery surface', async () => {
    for (const surface of ['feed', 'map', 'circle', 'search']) {
      const res = await search({ surface, limit: 1 });
      // FC46: each declared surface is accepted by the POST contract.
      expect(res.status).toBe(201);
      expect(res.body.applied.surface).toBe(surface);
    }
  });

  it('FC47 rejects an undeclared surface', async () => {
    const res = await search({ surface: 'carousel' });
    // FC47: validation must fail rather than silently normalizing an unknown surface.
    expect(res.status).toBeGreaterThanOrEqual(400);
  });

  it('FC48 applies approved-video eligibility before feed COUNT', async () => {
    const approved = await seedCandidate('FC48-approved', {
      kind: 'video',
      moderation: 'approved',
    });
    await seedCandidate('FC48-no-media');
    await seedCandidate('FC48-pending', { kind: 'video', moderation: 'pending' });
    await seedCandidate('FC48-image', { kind: 'image', moderation: 'approved' });

    const res = await search({ surface: 'feed', category: 'hotel', limit: 50 });
    expect(res.status).toBe(201);
    // FC48: total counts only candidates satisfying APPROVED_VIDEO_EXISTS.
    expect(res.body.total).toBe(1);
    expect(res.body.items.map((item: { venueId: string }) => item.venueId)).toEqual([approved]);
  });

  it('FC49 leaves non-feed surfaces free to return candidates without video', async () => {
    const noMedia = await seedCandidate('FC49-no-media');
    const res = await search({ surface: 'map', category: 'hotel', limit: 50 });
    expect(res.status).toBe(201);
    // FC49: approved video is a feed-only candidate predicate.
    expect(res.body.items.some((item: { venueId: string }) => item.venueId === noMedia)).toBe(true);
  });

  it('FC50 feed LIMIT is applied after approved-video eligibility', async () => {
    for (let index = 0; index < 3; index++) {
      await seedCandidate(`FC50-ineligible-${index}`);
      await seedCandidate(`FC50-eligible-${index}`, {
        kind: 'video',
        moderation: 'approved',
      });
    }
    const res = await search({ surface: 'feed', category: 'hotel', sort: 'newest', limit: 2 });
    expect(res.status).toBe(201);
    // FC50: ineligible rows cannot consume page slots.
    expect(res.body.items).toHaveLength(2);
    expect(res.body.total).toBe(3);
  });

  it('FC51 feed cursor pages contain no holes or duplicates', async () => {
    const ids: string[] = [];
    for (let index = 0; index < 3; index++) {
      ids.push(
        await seedCandidate(`FC51-${index}`, {
          kind: 'video',
          moderation: 'approved',
        }),
      );
    }
    const first = await search({ surface: 'feed', category: 'hotel', sort: 'newest', limit: 2 });
    expect(first.status).toBe(201);
    expect(first.body.nextCursor).toBeTruthy();
    const second = await search({
      surface: 'feed',
      category: 'hotel',
      sort: 'newest',
      limit: 2,
      cursor: first.body.nextCursor,
    });
    expect(second.status).toBe(201);
    const paged = [...first.body.items, ...second.body.items].map(
      (item: { venueId: string }) => item.venueId,
    );
    // FC51: candidate-level filtering preserves complete keyset traversal.
    expect(new Set(paged)).toEqual(new Set(ids));
  });

  it('FC52 GET feed delegates to surface=feed discovery semantics', async () => {
    const eligible = await seedCandidate('FC52-eligible', {
      kind: 'video',
      moderation: 'approved',
    });
    await seedCandidate('FC52-ineligible');
    const feed = await request(app.getHttpServer())
      .get('/v1/feed')
      .query({ category: 'hotel' })
      .set('Authorization', auth(consumer));
    expect(feed.status).toBe(200);
    // FC52: legacy GET feed exposes only the shared query's feed-eligible candidates.
    expect(feed.body.items.map((item: { venueId: string }) => item.venueId)).toEqual([eligible]);
    expect(feed.body.total).toBe(1);
  });

  it('FC53 GET feed never post-filters returned page items', async () => {
    for (let index = 0; index < 21; index++) {
      await seedCandidate(`FC53-eligible-${index}`, {
        kind: 'video',
        moderation: 'approved',
      });
      await seedCandidate(`FC53-ineligible-${index}`);
    }
    const feed = await request(app.getHttpServer())
      .get('/v1/feed')
      .query({ category: 'hotel' })
      .set('Authorization', auth(consumer));
    expect(feed.status).toBe(200);
    // FC53: adapter maps a full 20-row page; no item-level .filter() shrinks it.
    expect(feed.body.items).toHaveLength(20);
    expect(feed.body.total).toBe(21);
    expect(feed.body.nextCursor).toBeTruthy();
    expect(
      feed.body.items.every(
        (item: { videoId: string; coverUrl: string; streamUrl: string }) =>
          typeof item.videoId === 'string' &&
          typeof item.coverUrl === 'string' &&
          typeof item.streamUrl === 'string',
      ),
    ).toBe(true);
  });
});
