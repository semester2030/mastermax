import { Pool } from 'pg';
import { newId } from '../../src/shared/ids/ids';

export interface SeededVenue {
  providerId: string;
  venueId: string;
  types: Record<string, string>;
  plans: Record<string, string>;
}

export async function seedProvider(pool: Pool, ownerUid: string, name = 'Prov'): Promise<string> {
  const id = newId();
  await pool.query(
    `INSERT INTO providers (id, legal_name, display_name, type, status, firebase_owner_uid)
     VALUES ($1,$2,$2,'company','active',$3)`,
    [id, name, ownerUid],
  );
  await pool.query(
    `INSERT INTO provider_users (id, provider_id, firebase_uid, role, status)
     VALUES ($1,$2,$3,'owner','active')`,
    [newId(), id, ownerUid],
  );
  return id;
}

export async function seedVenue(
  pool: Pool,
  providerId: string,
  opts: {
    name: string;
    venueType: string;
    mode?: 'nightly' | 'daily' | 'event_slot';
    types: { name: string; qty: number; nights: Record<string, string> }[];
  },
): Promise<SeededVenue> {
  const venueId = newId();
  await pool.query(
    `INSERT INTO venues (
       id, provider_id, name, venue_type, booking_mode, status, city, min_stay,
       city_id, district_id, street, location_source, lat, lng
     )
     VALUES (
       $1,$2,$3,$4,$5,'published','الرياض',1,
       '01400000-0000-7000-8000-000000000001',
       '01400001-0000-7000-8000-000000000001',
       'طريق الملك فهد',
       'manual',
       24.7136,
       46.6753
     )`,
    [venueId, providerId, opts.name, opts.venueType, opts.mode ?? 'nightly'],
  );
  const types: Record<string, string> = {};
  const plans: Record<string, string> = {};
  for (const t of opts.types) {
    const typeId = newId();
    types[t.name] = typeId;
    await pool.query(
      `INSERT INTO inventory_types (id, venue_id, name, inventory_model, quantity_total, base_occupancy, max_occupancy)
       VALUES ($1,$2,$3,'pooled',$4,2,4)`,
      [typeId, venueId, t.name, t.qty],
    );
    const planId = newId();
    plans[t.name] = planId;
    await pool.query(
      `INSERT INTO rate_plans (id, inventory_type_id, name, is_default, status)
       VALUES ($1,$2,'default',true,'active')`,
      [planId, typeId],
    );
    await pool.query(
      `INSERT INTO rate_rules (id, rate_plan_id, kind, amount, priority) VALUES ($1,$2,'base',$3,0)`,
      [newId(), planId, Object.values(t.nights)[0] ?? '100'],
    );
    for (const [date, amount] of Object.entries(t.nights)) {
      await pool.query(
        `INSERT INTO rate_rules (id, rate_plan_id, kind, amount, date_from, date_to, priority)
         VALUES ($1,$2,'date_range',$3,$4::date,$4::date,10)`,
        [newId(), planId, amount, date],
      );
    }
    await pool.query(
      `INSERT INTO availability_rules (id, inventory_type_id, dow_mask, is_open)
       VALUES ($1,$2,127,TRUE)`,
      [newId(), typeId],
    );
    await pool.query(
      `INSERT INTO venue_media
         (id, venue_id, inventory_type_id, provider_id, kind, url, moderation_status, sort_order)
       VALUES ($1,$2,$3,$4,'image',$5,'approved',0),
              ($6,$2,$3,$4,'video',$7,'approved',0)`,
      [
        newId(),
        venueId,
        typeId,
        providerId,
        `https://imagedelivery.net/stub/${typeId}/public`,
        newId(),
        `https://videodelivery.net/stub/${typeId}/manifest/video.m3u8`,
      ],
    );
  }
  await pool.query(
    `INSERT INTO venue_media
       (id, venue_id, provider_id, kind, url, moderation_status, sort_order, is_cover)
     VALUES ($1,$2,$3,'image',$4,'approved',0,TRUE),
            ($5,$2,$3,'video',$6,'approved',0,FALSE)`,
    [
      newId(),
      venueId,
      providerId,
      `https://imagedelivery.net/stub/${venueId}/public`,
      newId(),
      `https://videodelivery.net/stub/${venueId}/manifest/video.m3u8`,
    ],
  );
  return { providerId, venueId, types, plans };
}

export function pool(): Pool {
  return new Pool({ connectionString: process.env.DATABASE_URL });
}
