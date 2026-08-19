/**
 * Gate 7B.5.1.1 — media denorm trigger (015): INSERT/DELETE/moderation/url/streamUid/price/re-parent.
 * Stored has_playable_video / indicative_starting_price must match EXISTS / MIN always.
 */
import { Pool } from 'pg';
import { withIsolatedDatabase } from '../helpers/isolated-database';
import { applyMigrationsThrough } from '../helpers/migrate-partial';
import { newId } from '../../src/shared/ids/ids';

const PLAYABLE_EXISTS = `
  EXISTS (
    SELECT 1 FROM venue_media m
    WHERE m.venue_id = v.id
      AND m.kind = 'video'
      AND m.moderation_status = 'approved'
      AND (
        (m.stream_uid IS NOT NULL AND btrim(m.stream_uid) <> '')
        OR (m.url IS NOT NULL AND btrim(m.url) <> '' AND m.url ~* '^https://')
      )
  )`;

const PRICE_MIN = `
  (SELECT MIN(m.starting_price_hint) FROM venue_media m
   WHERE m.venue_id = v.id
     AND m.moderation_status = 'approved'
     AND m.starting_price_hint IS NOT NULL)`;

async function assertDenorm(pool: Pool, venueId: string): Promise<void> {
  const r = await pool.query(
    `SELECT v.has_playable_video AS stored_playable,
            v.indicative_starting_price::text AS stored_price,
            (${PLAYABLE_EXISTS}) AS expect_playable,
            (${PRICE_MIN})::text AS expect_price,
            v.best_score_static IS NOT NULL AS has_static
     FROM venues v WHERE v.id = $1`,
    [venueId],
  );
  expect(r.rowCount).toBe(1);
  const row = r.rows[0];
  expect(row.stored_playable).toBe(row.expect_playable);
  expect(row.stored_price).toBe(row.expect_price);
  expect(row.has_static).toBe(true);
}

describe('Gate 7B.5.1.1 — media denorm trigger re-parent (G7B511-TRG)', () => {
  it('G7B511-TRG-01 INSERT/DELETE/moderation/url/streamUid/price/re-parent keep denorm = EXISTS/MIN', async () => {
    await withIsolatedDatabase(async (pool) => {
      await applyMigrationsThrough(pool, '015_gate7b511_media_denorm_reparent.sql');

      const providerId = newId();
      await pool.query(
        `INSERT INTO providers (id, legal_name, display_name, type, status, firebase_owner_uid)
         VALUES ($1,'T','T','company','active',$2)`,
        [providerId, `o-${providerId}`],
      );
      const type = (
        await pool.query<{ venue_type: string }>(
          `SELECT venue_type FROM venue_type_capabilities WHERE enabled_for_discovery ORDER BY 1 LIMIT 1`,
        )
      ).rows[0].venue_type;

      const a = newId();
      const b = newId();
      for (const id of [a, b]) {
        await pool.query(
          `INSERT INTO venues (
             id, provider_id, name, venue_type, booking_mode, status, city, lat, lng,
             weighted_rating, reviews_count, rating_average
           ) VALUES ($1,$2,$3,$4,'nightly','published','Riyadh',24.7,46.7,4.2,10,4.2)`,
          [id, providerId, `V-${id.slice(0, 8)}`, type],
        );
      }

      const mediaId = newId();
      // INSERT playable https video + price
      await pool.query(
        `INSERT INTO venue_media (
           id, venue_id, provider_id, kind, url, stream_uid, moderation_status, sort_order, starting_price_hint
         ) VALUES ($1,$2,$3,'video','https://cdn.example/a.mp4',NULL,'approved',0,150)`,
        [mediaId, a, providerId],
      );
      await assertDenorm(pool, a);
      expect(
        (await pool.query(`SELECT has_playable_video FROM venues WHERE id=$1`, [a])).rows[0]
          .has_playable_video,
      ).toBe(true);

      // moderation → rejected clears playable + price
      await pool.query(
        `UPDATE venue_media SET moderation_status='rejected' WHERE id=$1`,
        [mediaId],
      );
      await assertDenorm(pool, a);
      expect(
        (await pool.query(`SELECT has_playable_video, indicative_starting_price FROM venues WHERE id=$1`, [a]))
          .rows[0].has_playable_video,
      ).toBe(false);

      // restore approved + non-https url without stream_uid → not playable
      await pool.query(
        `UPDATE venue_media SET moderation_status='approved', url='http://cdn.example/a.mp4', stream_uid=NULL WHERE id=$1`,
        [mediaId],
      );
      await assertDenorm(pool, a);
      expect(
        (await pool.query(`SELECT has_playable_video FROM venues WHERE id=$1`, [a])).rows[0]
          .has_playable_video,
      ).toBe(false);

      // stream_uid makes playable even with http url
      await pool.query(
        `UPDATE venue_media SET stream_uid='cf-uid-1', starting_price_hint=220 WHERE id=$1`,
        [mediaId],
      );
      await assertDenorm(pool, a);
      expect(
        (await pool.query(`SELECT has_playable_video, indicative_starting_price::float FROM venues WHERE id=$1`, [a]))
          .rows[0],
      ).toMatchObject({ has_playable_video: true, indicative_starting_price: 220 });

      // price change
      await pool.query(`UPDATE venue_media SET starting_price_hint=99 WHERE id=$1`, [mediaId]);
      await assertDenorm(pool, a);

      // RE-PARENT A → B: both must refresh
      await pool.query(`UPDATE venue_media SET venue_id=$1 WHERE id=$2`, [b, mediaId]);
      await assertDenorm(pool, a);
      await assertDenorm(pool, b);
      const afterMove = await pool.query(
        `SELECT id, has_playable_video, indicative_starting_price::float AS price
         FROM venues WHERE id = ANY($1::uuid[]) ORDER BY id`,
        [[a, b]],
      );
      const byId = Object.fromEntries(afterMove.rows.map((r) => [r.id, r]));
      expect(byId[a].has_playable_video).toBe(false);
      expect(byId[a].price).toBeNull();
      expect(byId[b].has_playable_video).toBe(true);
      expect(byId[b].price).toBe(99);

      // DELETE from B
      await pool.query(`DELETE FROM venue_media WHERE id=$1`, [mediaId]);
      await assertDenorm(pool, a);
      await assertDenorm(pool, b);
      expect(
        (await pool.query(`SELECT has_playable_video FROM venues WHERE id=$1`, [b])).rows[0]
          .has_playable_video,
      ).toBe(false);
    });
  }, 180_000);
});
