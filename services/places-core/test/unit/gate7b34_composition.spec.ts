/**
 * Gate 7B.3.4 — guests + quantity + capacityMin composition + date/slot guards (unit).
 */
import {
  applyDiscoveryDefaults,
  assertDiscoveryLimits,
  buildDiscoveryQuery,
} from '../../src/modules/filters/application/discovery-query';
import { DiscoverySearchDto } from '../../src/shared/api/dto/discovery-search.dto';

const AS_OF = new Date().toISOString().replace(/\.\d{3}Z$/, '.000Z');

function sqlFor(dto: DiscoverySearchDto) {
  const resolved = applyDiscoveryDefaults(dto);
  return buildDiscoveryQuery(resolved, { rankingAsOf: AS_OF });
}

describe('Gate 7B.3.4 — G7B34 filter composition unit', () => {
  it('G7B34-UNDATED-01 no qty: need = max(guests, capacityMin) on venue OR inventory', () => {
    const q = sqlFor({ guests: 4, capacityMin: 10 } as DiscoverySearchDto);
    expect(q.whereSql).toMatch(/v\.capacity/);
    expect(q.whereSql).toMatch(/max_occupancy/);
    expect(q.whereSql).not.toMatch(/quantity_total/);
    expect(q.whereParams).toContain(10);
    expect(q.whereParams).not.toContain(4);
  });

  it('G7B34-UNDATED-02 guests alone uses guests as need; no quantity_total', () => {
    const q = sqlFor({ guests: 8 } as DiscoverySearchDto);
    expect(q.whereParams).toContain(8);
    expect(q.whereSql).toMatch(/v\.capacity/);
    expect(q.whereSql).not.toMatch(/quantity_total/);
  });

  it('G7B34-UNDATED-03 explicit qty: same inventory type; no v.capacity bypass', () => {
    const q = sqlFor({ guests: 8, quantity: 2 } as DiscoverySearchDto);
    expect(q.whereSql).toMatch(/quantity_total/);
    expect(q.whereSql).toMatch(/max_occupancy \* \$/);
    expect(q.whereSql).not.toMatch(/v\.capacity/);
    expect(q.whereParams).toEqual(expect.arrayContaining([2, 8]));
  });

  it('G7B34-UNDATED-04 qty + capacityMin composed on same type', () => {
    const q = sqlFor({ capacityMin: 6, quantity: 3 } as DiscoverySearchDto);
    expect(q.whereSql).toMatch(/quantity_total/);
    expect(q.whereSql).not.toMatch(/v\.capacity/);
    expect(q.whereParams).toEqual(expect.arrayContaining([3, 6]));
  });

  it('G7B34-UNDATED-05 qty alone: quantity_total only', () => {
    const q = sqlFor({ quantity: 2 } as DiscoverySearchDto);
    expect(q.whereSql).toMatch(/quantity_total/);
    expect(q.whereSql).not.toMatch(/max_occupancy \*/);
  });

  it('G7B34-NIGHTLY-01 same type qty + capacity + all nights', () => {
    const q = sqlFor({
      checkIn: '2030-07-01',
      checkOut: '2030-07-03',
      quantity: 2,
      guests: 8,
      capacityMin: 6,
    } as DiscoverySearchDto);
    expect(q.whereSql).toMatch(/generate_series/);
    expect(q.whereSql).toMatch(/quantity_total/);
    expect(q.whereSql).toMatch(/max_occupancy \*/);
    expect(q.whereParams).toEqual(expect.arrayContaining([2, 8]));
    expect(q.availabilityMode).toBe('AVAILABLE');
  });

  it('G7B34-NIGHTLY-02 omitted qty defaults to 1 for dated availability only', () => {
    const q = sqlFor({
      checkIn: '2030-07-01',
      checkOut: '2030-07-02',
      guests: 4,
    } as DiscoverySearchDto);
    expect(q.whereParams).toContain(1);
    expect(q.whereParams).toContain(4);
  });

  it('G7B34-SLOT-01 capacityNeed on slot; no quantity_total', () => {
    const q = sqlFor({
      checkIn: '2030-09-01',
      slotCode: 'evening',
      guests: 100,
      capacityMin: 200,
    } as DiscoverySearchDto);
    expect(q.whereSql).toMatch(/event_slot_inventory/);
    expect(q.whereSql).toMatch(/est\.capacity/);
    expect(q.whereParams).toContain(200);
    expect(q.whereSql).not.toMatch(/quantity_total/);
  });

  it('G7B34-LIMITS-01 slot without checkIn → 400', () => {
    expect(() =>
      assertDiscoveryLimits({ slotCode: 'evening' } as DiscoverySearchDto),
    ).toThrow(/slotCode requires checkIn/);
  });

  it('G7B34-LIMITS-02 slot + checkOut → 400', () => {
    expect(() =>
      assertDiscoveryLimits({
        checkIn: '2030-09-01',
        checkOut: '2030-09-02',
        slotCode: 'evening',
      } as DiscoverySearchDto),
    ).toThrow(/slotCode forbids checkOut/);
  });

  it('G7B34-LIMITS-03 checkIn without checkOut/slot → 400', () => {
    expect(() =>
      assertDiscoveryLimits({ checkIn: '2030-09-01' } as DiscoverySearchDto),
    ).toThrow(/checkIn requires checkOut or slotCode/);
  });

  it('G7B34-LIMITS-04 checkOut without checkIn → 400', () => {
    expect(() =>
      assertDiscoveryLimits({ checkOut: '2030-09-02' } as DiscoverySearchDto),
    ).toThrow(/checkOut requires checkIn/);
  });

  it('G7B34-LIMITS-05 explicit quantity + slot → 400', () => {
    expect(() =>
      assertDiscoveryLimits({
        checkIn: '2030-09-01',
        slotCode: 'evening',
        quantity: 1,
      } as DiscoverySearchDto),
    ).toThrow(/explicit quantity forbidden with event slot/);
  });
});
