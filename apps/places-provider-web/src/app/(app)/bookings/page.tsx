import Link from "next/link";
import { EmptyState } from "@/components/ui/empty-state";
import {
  asArray,
  CoreApiError,
  listBookings,
  requireProviderId,
} from "@/lib/core/client";
import type { BookingRow } from "@/lib/core/types";
import { bookingCodeOf } from "@/lib/core/types";

export default async function BookingsPage() {
  const providerId = await requireProviderId();
  let bookings: BookingRow[] = [];
  let error: string | null = null;
  try {
    bookings = asArray(await listBookings(providerId)) as BookingRow[];
  } catch (e) {
    error =
      e instanceof CoreApiError ? e.message : "تعذّر جلب الحجوزات";
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold">الحجوزات</h1>
        <p className="mt-1 text-sm text-[var(--color-on-surface-muted)]">
          GET /v1/provider/bookings
        </p>
      </div>

      {error ? (
        <p className="text-sm text-[var(--color-error)]">{error}</p>
      ) : null}

      {!error && bookings.length === 0 ? (
        <EmptyState
          title="لا توجد حجوزات"
          description="ستظهر الحجوزات هنا عند تأكيدها من تطبيق المستهلك."
        />
      ) : (
        <ul className="divide-y divide-[var(--color-border)] rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-white/80">
          {bookings.map((b) => (
            <li key={b.id}>
              <Link
                href={`/bookings/${b.id}`}
                className="flex flex-col gap-1 px-4 py-3 hover:bg-[var(--color-primary-light)]/50 sm:flex-row sm:items-center sm:justify-between"
              >
                <div>
                  <p className="font-semibold" dir="ltr">
                    {bookingCodeOf(b)}
                  </p>
                  <p className="text-xs text-[var(--color-on-surface-muted)]">
                    {b.status ?? "—"} · {b.check_in ?? b.checkIn ?? "—"} →{" "}
                    {b.check_out ?? b.checkOut ?? "—"}
                  </p>
                </div>
                <span className="text-sm font-medium" dir="ltr">
                  {b.gross_total ?? b.grossTotal ?? "—"}
                </span>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
