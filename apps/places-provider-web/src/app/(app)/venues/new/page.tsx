import Link from "next/link";
import { VenueCreateForm } from "@/components/venue-create-form";

export default function NewVenuePage() {
  return (
    <div className="space-y-6">
      <div>
        <Link
          href="/venues"
          className="text-sm text-[var(--color-text-secondary)] hover:text-[var(--color-primary)]"
        >
          ← العودة للأماكن
        </Link>
        <h1 className="mt-2 text-2xl font-bold">مكان جديد</h1>
      </div>
      <VenueCreateForm />
    </div>
  );
}
