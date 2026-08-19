import Link from "next/link";
import { CancelBookingForm } from "@/components/cancel-booking-form";
import {
  asArray,
  CoreApiError,
  getBooking,
  listBookings,
  requireProviderId,
} from "@/lib/core/client";
import type { BookingRow } from "@/lib/core/types";
import { bookingCodeOf } from "@/lib/core/types";

export default async function BookingDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  const providerId = await requireProviderId();
  let booking: BookingRow | null = null;
  let error: string | null = null;

  try {
    booking = (await getBooking(id, providerId)) as BookingRow;
  } catch {
    try {
      const list = asArray(await listBookings(providerId)) as BookingRow[];
      booking = list.find((b) => b.id === id) ?? null;
      if (!booking) {
        error = "الحجز غير موجود";
      }
    } catch (e) {
      error =
        e instanceof CoreApiError ? e.message : "تعذّر جلب تفاصيل الحجز";
    }
  }

  return (
    <div className="space-y-6">
      <div>
        <Link
          href="/bookings"
          className="text-sm text-[var(--color-text-secondary)] hover:text-[var(--color-primary)]"
        >
          ← الحجوزات
        </Link>
        <h1 className="mt-2 text-2xl font-bold" dir="ltr">
          {booking ? bookingCodeOf(booking) : "تفاصيل الحجز"}
        </h1>
      </div>

      {error ? (
        <p className="text-sm text-[var(--color-error)]">{error}</p>
      ) : booking ? (
        <>
          <dl className="grid gap-3 rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-white/80 p-4 text-sm sm:grid-cols-2">
            <div>
              <dt className="text-[var(--color-on-surface-muted)]">الحالة</dt>
              <dd className="font-semibold">{booking.status ?? "—"}</dd>
            </div>
            <div>
              <dt className="text-[var(--color-on-surface-muted)]">المبلغ</dt>
              <dd className="font-semibold" dir="ltr">
                {booking.gross_total ?? booking.grossTotal ?? "—"}
              </dd>
            </div>
            <div>
              <dt className="text-[var(--color-on-surface-muted)]">الوصول</dt>
              <dd dir="ltr">{booking.check_in ?? booking.checkIn ?? "—"}</dd>
            </div>
            <div>
              <dt className="text-[var(--color-on-surface-muted)]">المغادرة</dt>
              <dd dir="ltr">{booking.check_out ?? booking.checkOut ?? "—"}</dd>
            </div>
            <div className="sm:col-span-2">
              <dt className="text-[var(--color-on-surface-muted)]">المعرّف</dt>
              <dd dir="ltr" className="text-xs">
                {booking.id}
              </dd>
            </div>
          </dl>
          <div>
            <h2 className="mb-3 text-lg font-bold">إلغاء الحجز</h2>
            <CancelBookingForm bookingId={id} />
          </div>
        </>
      ) : null}
    </div>
  );
}
