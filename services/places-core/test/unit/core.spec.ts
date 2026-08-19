import { stayDates, isWeekend } from '../../src/shared/time/stay-dates';
import { Decimal } from '../../src/shared/money/decimal';
import { commissionOf, money, proportionalShare } from '../../src/shared/money/money';
import { canTransition } from '../../src/modules/booking/domain/booking-states';
import { availableOf, assertBucketsFit } from '../../src/modules/inventory/domain/capacity-invariant';
import { can } from '../../src/shared/rbac/permissions';
import { assertProductionGuards } from '../../src/shared/config/env';

describe('unit core', () => {
  it('nightly intersection dates exclusive checkout', () => {
    expect(stayDates('nightly', '2026-08-15', '2026-08-18')).toEqual([
      '2026-08-15',
      '2026-08-16',
      '2026-08-17',
    ]);
  });

  it('daily inclusive', () => {
    expect(stayDates('daily', '2026-08-15', '2026-08-15')).toEqual(['2026-08-15']);
  });

  it('saudi weekend fri/sat', () => {
    expect(isWeekend('2026-08-14')).toBe(true);
    expect(isWeekend('2026-08-15')).toBe(true);
    expect(isWeekend('2026-08-16')).toBe(false);
  });

  it('commission 10% of 1000', () => {
    expect(commissionOf(money('1000'), 1000).toString()).toBe('100.00');
  });

  it('Q money rounding 100.01 @ 10% half-up', () => {
    expect(commissionOf(money('100.01'), 1000).toString()).toBe('10.00');
    expect(commissionOf(money('100.05'), 1000).toString()).toBe('10.01');
    expect(proportionalShare(money('50.00'), money('100.00'), money('10.00')).toString()).toBe('5.00');
  });

  it('R commission snapshot uses stored bps not live default', () => {
    const snap = commissionOf(money('200.00'), 1000);
    const later = commissionOf(money('200.00'), 1200);
    expect(snap.toString()).toBe('20.00');
    expect(later.toString()).toBe('24.00');
    expect(snap.eq(later)).toBe(false);
  });

  it('decimal add/sub no float', () => {
    expect(new Decimal('0.10').add(new Decimal('0.20')).toString()).toBe('0.30');
    expect(new Decimal('1000').sub(new Decimal('100')).toString()).toBe('900.00');
  });

  it('state machine forbids random jumps', () => {
    // HOLDING→CONFIRMED allowed in graph; plain transition() still rejects (Pay-at-Venue path only).
    expect(canTransition('HOLDING', 'CONFIRMED')).toBe(true);
    expect(canTransition('PENDING_PAYMENT', 'CONFIRMED')).toBe(true);
    expect(canTransition('COMPLETED', 'PENDING_PAYMENT')).toBe(false);
    expect(canTransition('COMPLETED', 'CANCELLED')).toBe(false);
    expect(canTransition('COMPLETED', 'REFUND_PENDING')).toBe(true);
    expect(canTransition('PAYMENT_FAILED', 'PENDING_PAYMENT')).toBe(true);
    expect(canTransition('REFUNDED', 'CONFIRMED')).toBe(false);
  });

  it('capacity invariant', () => {
    expect(availableOf(30, 1, 0, 0)).toBe(29);
    expect(() => assertBucketsFit(1, 1, 1, 0)).toThrow();
  });

  it('rbac matrix', () => {
    expect(can('front_desk', 'finance.view')).toBe(false);
    expect(can('owner', 'team.manage')).toBe(true);
    expect(can('pricing', 'pricing.edit')).toBe(true);
  });

  it('production guards', () => {
    expect(() => assertProductionGuards('production', 'stub', 'x')).toThrow();
    expect(() => assertProductionGuards('test', 'stub', 'stub')).not.toThrow();
  });
});
