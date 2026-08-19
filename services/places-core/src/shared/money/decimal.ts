/** Fixed-scale (2dp) money via integer cents. No IEEE float arithmetic. */
export class Decimal {
  private readonly cents: bigint;

  constructor(value: string | number | Decimal) {
    if (value instanceof Decimal) {
      this.cents = value.cents;
      return;
    }
    const s = typeof value === 'number' ? value.toFixed(2) : value;
    const neg = s.startsWith('-');
    const raw = neg ? s.slice(1) : s;
    const [w, f = ''] = raw.split('.');
    const frac = (f + '00').slice(0, 2);
    const n = BigInt(w || '0') * 100n + BigInt(frac);
    this.cents = neg ? -n : n;
  }

  add(o: Decimal): Decimal {
    return Decimal.fromCents(this.cents + o.cents);
  }
  sub(o: Decimal): Decimal {
    return Decimal.fromCents(this.cents - o.cents);
  }
  /** Multiply by a small integer (e.g. quantity, bps before div). */
  mul(n: number): Decimal {
    return Decimal.fromCents(this.cents * BigInt(n));
  }
  /** Truncating integer division by a small integer. Prefer allocateProportion / bps for money. */
  div(n: number): Decimal {
    return Decimal.fromCents(this.cents / BigInt(n));
  }
  /**
   * Half-up proportion: floor((this * numerator) / denominator + 1/2).
   * Used for refunds: refund/gross * commission.
   */
  allocateProportion(numerator: Decimal, denominator: Decimal): Decimal {
    if (denominator.cents === 0n) {
      return Decimal.zero();
    }
    const product = this.cents * numerator.cents;
    const den = denominator.cents;
    const half = den >= 0n ? den / 2n : -den / 2n;
    const q = product >= 0n ? (product + half) / den : (product - half) / den;
    return Decimal.fromCents(q);
  }
  /** Half-up basis points: amount * bps / 10000. */
  ofBps(bps: number): Decimal {
    const product = this.cents * BigInt(bps);
    const q = product >= 0n ? (product + 5000n) / 10000n : (product - 5000n) / 10000n;
    return Decimal.fromCents(q);
  }
  round(_scale: number): Decimal {
    return this;
  }
  toString(): string {
    const neg = this.cents < 0n;
    const abs = neg ? -this.cents : this.cents;
    const w = abs / 100n;
    const f = (abs % 100n).toString().padStart(2, '0');
    return `${neg ? '-' : ''}${w.toString()}.${f}`;
  }
  toNumber(): number {
    return Number(this.toString());
  }
  eq(o: Decimal): boolean {
    return this.cents === o.cents;
  }
  gt(o: Decimal): boolean {
    return this.cents > o.cents;
  }
  isPositive(): boolean {
    return this.cents > 0n;
  }
  private static fromCents(cents: bigint): Decimal {
    const neg = cents < 0n;
    const abs = neg ? -cents : cents;
    const w = abs / 100n;
    const f = (abs % 100n).toString().padStart(2, '0');
    return new Decimal(`${neg ? '-' : ''}${w.toString()}.${f}`);
  }
  static zero(): Decimal {
    return new Decimal('0');
  }
}
