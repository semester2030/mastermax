import Image from "next/image";
import Link from "next/link";
import { brand } from "@/lib/design/tokens";
import { SignOutButton } from "@/components/sign-out-button";

const links = [
  { href: "/", label: "لوحة التحكم" },
  { href: "/venues", label: "الأماكن" },
  { href: "/moderation", label: "المراجعة" },
  { href: "/bookings", label: "الحجوزات" },
] as const;

export function ProviderShell({
  children,
}: {
  children: React.ReactNode;
  providerId?: string | null;
}) {
  const appName =
    process.env.NEXT_PUBLIC_APP_NAME?.trim() ||
    `${brand.displayNameAr} — مقدم الخدمة`;

  return (
    <div className="min-h-screen bg-[var(--color-background)]">
      <header className="border-b border-[var(--color-border)] bg-white/85 backdrop-blur-xl">
        <div className="mx-auto flex h-14 w-full max-w-6xl items-center justify-between gap-4 px-4 sm:px-6">
          <div className="flex items-center gap-3">
            <span className="relative grid h-8 w-8 place-items-center overflow-hidden rounded-[var(--radius-sm)] border border-[var(--color-border)] bg-white">
              <Image
                src="/brand/dar_car_logo.png"
                alt={brand.displayNameAr}
                width={28}
                height={32}
                className="h-6 w-auto object-contain"
              />
            </span>
            <div className="leading-tight">
              <p className="text-sm font-bold text-[var(--color-text-primary)]">
                {appName}
              </p>
              <p className="text-[11px] text-[var(--color-on-surface-muted)]">
                حساب المطوّر الداخلي
              </p>
            </div>
          </div>
          <SignOutButton />
        </div>
      </header>

      <div className="mx-auto grid w-full max-w-6xl gap-6 px-4 py-6 sm:px-6 lg:grid-cols-[220px_1fr]">
        <aside className="h-fit rounded-[var(--radius-lg)] border border-[var(--color-border)] bg-white/70 p-3">
          <nav className="flex flex-col gap-1" aria-label="قائمة مقدم الخدمة">
            {links.map((link) => (
              <Link
                key={link.href}
                href={link.href}
                className="rounded-[var(--radius-sm)] px-3 py-2 text-sm font-medium text-[var(--color-text-secondary)] transition-colors hover:bg-[var(--color-primary-light)] hover:text-[var(--color-text-primary)]"
              >
                {link.label}
              </Link>
            ))}
            <div className="mt-2 border-t border-[var(--color-border)] pt-2">
              <SignOutButton variant="ghost" label="تسجيل الخروج" />
            </div>
          </nav>
        </aside>
        <main className="min-w-0 animate-fade-up">{children}</main>
      </div>
    </div>
  );
}
