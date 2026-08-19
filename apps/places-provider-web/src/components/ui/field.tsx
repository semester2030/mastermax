import { cn } from "@/lib/utils";

export function Input({
  className,
  ...props
}: React.ComponentProps<"input">) {
  return (
    <input
      className={cn(
        "h-11 w-full rounded-[var(--radius-md)] border border-[var(--color-border-strong)] bg-white px-3 text-sm text-[var(--color-text-primary)] outline-none transition-shadow focus:ring-2 focus:ring-[var(--color-primary)]/30",
        className,
      )}
      {...props}
    />
  );
}

export function Textarea({
  className,
  ...props
}: React.ComponentProps<"textarea">) {
  return (
    <textarea
      className={cn(
        "min-h-28 w-full rounded-[var(--radius-md)] border border-[var(--color-border-strong)] bg-white px-3 py-2.5 text-sm text-[var(--color-text-primary)] outline-none transition-shadow focus:ring-2 focus:ring-[var(--color-primary)]/30",
        className,
      )}
      {...props}
    />
  );
}

export function Label({
  className,
  ...props
}: React.ComponentProps<"label">) {
  return (
    <label
      className={cn(
        "mb-1.5 block text-xs font-semibold text-[var(--color-text-secondary)]",
        className,
      )}
      {...props}
    />
  );
}

export function Select({
  className,
  children,
  ...props
}: React.ComponentProps<"select">) {
  return (
    <select
      className={cn(
        "h-11 w-full rounded-[var(--radius-md)] border border-[var(--color-border-strong)] bg-white px-3 text-sm text-[var(--color-text-primary)] outline-none transition-shadow focus:ring-2 focus:ring-[var(--color-primary)]/30",
        className,
      )}
      {...props}
    >
      {children}
    </select>
  );
}
