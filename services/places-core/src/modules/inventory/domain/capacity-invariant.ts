export function assertBucketsFit(
  capacity: number,
  held: number,
  booked: number,
  blocked: number,
): void {
  if (capacity < 0 || held < 0 || booked < 0 || blocked < 0) {
    throw new Error("capacity buckets must be >= 0");
  }
  if (held + booked + blocked > capacity) {
    throw new Error("blocked + held + booked exceeds capacity");
  }
}

export function availableOf(
  capacity: number,
  held: number,
  booked: number,
  blocked: number,
): number {
  assertBucketsFit(capacity, held, booked, blocked);
  return capacity - held - booked - blocked;
}
