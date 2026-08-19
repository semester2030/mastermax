import { brand } from "@/lib/design/tokens";
import { LoginForm } from "@/components/login-form";

export default function LoginPage() {
  const appName =
    process.env.NEXT_PUBLIC_APP_NAME?.trim() ||
    `${brand.displayNameAr} — مقدم الخدمة`;

  return (
    <div className="flex min-h-screen items-center justify-center px-4 py-10">
      <div className="w-full max-w-md space-y-6 rounded-[var(--radius-xl)] border border-[var(--color-border)] bg-white/80 p-6 shadow-[0_20px_50px_rgba(63,0,113,0.08)] sm:p-8">
        <div className="space-y-2 text-center">
          <p className="text-xs font-semibold tracking-[0.16em] text-[var(--color-text-secondary)]">
            WAVE1
          </p>
          <h1 className="font-display text-2xl font-bold text-[var(--color-text-primary)]">
            {appName}
          </h1>
          <p className="text-sm text-[var(--color-on-surface-muted)]">
            دخول المشغّل الداخلي عبر رقم الجوال ورمز التحقق لمرة واحدة.
          </p>
        </div>
        <LoginForm />
      </div>
    </div>
  );
}
