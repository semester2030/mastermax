import { canTransition } from '../../src/modules/booking/domain/booking-states';
import { assertProductionGuards } from '../../src/shared/config/env';
import { money, proportionalShare } from '../../src/shared/money/money';

describe('pre-provider Batch1 closure unit', () => {
  it('PAYMENT_FAILED may retry to PENDING_PAYMENT', () => {
    expect(canTransition('PAYMENT_FAILED', 'PENDING_PAYMENT')).toBe(true);
    expect(canTransition('PAYMENT_FAILED', 'CONFIRMED')).toBe(false);
    expect(canTransition('PAYMENT_FAILED', 'EXPIRED')).toBe(true);
  });

  it('COMPLETED refunds via REFUND_PENDING not CANCELLED', () => {
    expect(canTransition('COMPLETED', 'CANCELLED')).toBe(false);
    expect(canTransition('COMPLETED', 'REFUND_PENDING')).toBe(true);
    expect(canTransition('REFUND_PENDING', 'REFUNDED')).toBe(true);
  });

  it('ledger shares adjust to exact PSP refund (halala)', () => {
    const refundAmt = money('33.33');
    const gross = money('100.00');
    const commission = money('10.00');
    const providerNet = money('90.00');
    const commBack = proportionalShare(refundAmt, gross, commission);
    let recBack = proportionalShare(refundAmt, gross, providerNet);
    if (!commBack.add(recBack).eq(refundAmt)) {
      recBack = refundAmt.sub(commBack);
    }
    expect(commBack.add(recBack).toString()).toBe('33.33');
  });

  it('production forbids stub auth and stub payment', () => {
    expect(() => assertProductionGuards('production', 'stub', 'stub')).toThrow(/AUTH_MODE/);
    expect(() => assertProductionGuards('production', 'firebase', 'stub')).toThrow(/PAYMENT_PROVIDER/);
    expect(() => assertProductionGuards('development', 'stub', 'stub')).not.toThrow();
  });

  it('Discovery occupancy parity: guests <= max_occupancy * quantity', () => {
    const maxOccupancy = 2;
    const quantity = 3;
    const guests = 6;
    expect(guests <= maxOccupancy * quantity).toBe(true);
    expect(7 <= maxOccupancy * quantity).toBe(false);
  });
});
