"use client";

import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";

export function SignOutButton({
  variant = "outline",
  label = "خروج",
}: {
  variant?: "outline" | "ghost";
  label?: string;
}) {
  const router = useRouter();

  async function signOut() {
    await fetch("/api/auth/session", { method: "DELETE" });
    router.replace("/login");
    router.refresh();
  }

  return (
    <Button type="button" variant={variant} size="sm" onClick={signOut}>
      {label}
    </Button>
  );
}
