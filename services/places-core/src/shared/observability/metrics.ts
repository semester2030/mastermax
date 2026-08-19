export class Metrics {
  private readonly counters = new Map<string, number>();

  inc(name: string, by = 1): void {
    this.counters.set(name, (this.counters.get(name) ?? 0) + by);
  }

  observe(_name: string, _ms: number): void {
    this.inc(`${_name}_count`);
  }

  snapshot(): Record<string, number> {
    return Object.fromEntries(this.counters);
  }
}

export const metrics = new Metrics();
