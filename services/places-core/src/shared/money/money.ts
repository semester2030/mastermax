import { Decimal } from './decimal';

export function money(value: string | number): Decimal {
  return new Decimal(value);
}

/** Commission = gross × bps / 10000 with half-up rounding to 2dp. */
export function commissionOf(gross: Decimal, bps: number): Decimal {
  return gross.ofBps(bps);
}

export function providerNetOf(gross: Decimal, commission: Decimal): Decimal {
  return gross.sub(commission);
}

/**
 * Refund share of a booked amount: floor((refundAmount / gross) * target + ½).
 * All via integer cents — never IEEE float.
 */
export function proportionalShare(refundAmount: Decimal, gross: Decimal, target: Decimal): Decimal {
  return target.allocateProportion(refundAmount, gross);
}
