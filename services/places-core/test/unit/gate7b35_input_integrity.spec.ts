/**
 * Gate 7B.3.5 — input integrity (IsInt / YYYY-MM-DD / slot) + composition regression (unit).
 */
import 'reflect-metadata';
import {
  applyDiscoveryDefaults,
  assertDiscoveryLimits,
  assertIsoCalendarDate,
  buildDiscoveryQuery,
} from '../../src/modules/filters/application/discovery-query';
import { DiscoverySearchDto } from '../../src/shared/api/dto/discovery-search.dto';
import { plainToInstance } from 'class-transformer';
import { validateSync } from 'class-validator';

const AS_OF = new Date().toISOString().replace(/\.\d{3}Z$/, '.000Z');

function dto(body: Record<string, unknown>): DiscoverySearchDto {
  return plainToInstance(DiscoverySearchDto, body);
}

describe('Gate 7B.3.5 — G7B35 input + slot integrity unit', () => {
  it('G7B35-INT rejects fractional int-contract fields before SQL', () => {
    for (const [field, value] of [
      ['quantity', 1.5],
      ['guests', 2.5],
      ['capacityMin', 10.1],
      ['starsMin', 3.5],
      ['bedroomsMin', 1.5],
      ['bathroomsMin', 0.5],
      ['limit', 10.5],
    ] as const) {
      const errs = validateSync(dto({ [field]: value }));
      expect(errs.length).toBeGreaterThan(0);
    }
    // Fractional price / rating / geo still allowed
    expect(validateSync(dto({ minPrice: 99.5, minRating: 4.5, lat: 24.7, lng: 46.7 })).length).toBe(
      0,
    );
    expect(validateSync(dto({ quantity: 2, guests: 4, limit: 20 })).length).toBe(0);
  });

  it('G7B35-DATE rejects timestamp / unreal / inverted; allows same-day daily', () => {
    expect(validateSync(dto({ checkIn: '2030-07-01T00:00:00.000Z' })).length).toBeGreaterThan(0);
    expect(validateSync(dto({ checkIn: '2030-07-01', checkOut: '2030-07-02' })).length).toBe(0);
    expect(() => assertIsoCalendarDate('2030-02-30', 'checkIn')).toThrow(/real calendar/);
    expect(() =>
      assertDiscoveryLimits({
        checkIn: '2030-07-01',
        checkOut: '2030-07-01',
      } as DiscoverySearchDto),
    ).not.toThrow();
    expect(() =>
      assertDiscoveryLimits({
        checkIn: '2030-07-02',
        checkOut: '2030-07-01',
      } as DiscoverySearchDto),
    ).toThrow(/inverted|on or before/);
    expect(() =>
      assertDiscoveryLimits({
        checkIn: '2030-07-01T12:00:00Z',
        checkOut: '2030-07-02',
      } as DiscoverySearchDto),
    ).toThrow(/YYYY-MM-DD/);
  });

  it('G7B35-SLOT SQL requires est.venue_id = esi.venue_id = v.id', () => {
    const q = buildDiscoveryQuery(
      applyDiscoveryDefaults({
        checkIn: '2030-09-01',
        slotCode: 'evening',
      } as DiscoverySearchDto),
      { rankingAsOf: AS_OF },
    );
    expect(q.whereSql).toMatch(/est\.venue_id = v\.id/);
    expect(q.whereSql).toMatch(/est\.venue_id = esi\.venue_id/);
    expect(q.whereSql).toMatch(/esi\.venue_id = v\.id/);
  });

  it('G7B35-COMP regression: explicit qty still forbids v.capacity bypass', () => {
    const q = buildDiscoveryQuery(
      applyDiscoveryDefaults({ guests: 8, quantity: 2 } as DiscoverySearchDto),
      { rankingAsOf: AS_OF },
    );
    expect(q.whereSql).toMatch(/quantity_total/);
    expect(q.whereSql).not.toMatch(/v\.capacity/);
  });
});
