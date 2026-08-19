import Link from "next/link";

const tabs = [
  { suffix: "", label: "التفاصيل" },
  { suffix: "/units", label: "الوحدات" },
  { suffix: "/pricing", label: "التسعير" },
  { suffix: "/availability", label: "التوفر" },
  { suffix: "/media", label: "الوسائط" },
] as const;

export function VenueNav({ venueId }: { venueId: string }) {
  return (
    <nav
      className="flex flex-wrap gap-2 border-b border-[var(--color-border)] pb-3"
      aria-label="أقسام المكان"
    >
      {tabs.map((tab) => (
        <Link
          key={tab.suffix}
          href={`/venues/${venueId}${tab.suffix}`}
          className="rounded-[var(--radius-sm)] px-3 py-1.5 text-sm font-medium text-[var(--color-text-secondary)] hover:bg-[var(--color-primary-light)] hover:text-[var(--color-text-primary)]"
        >
          {tab.label}
        </Link>
      ))}
    </nav>
  );
}
