"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Input, Label } from "@/components/ui/field";

export function LoginForm() {
  const router = useRouter();
  const [phoneE164, setPhoneE164] = useState("");
  const [challengeId, setChallengeId] = useState<string | null>(null);
  const [code, setCode] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [pending, setPending] = useState(false);

  async function sendOtp(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setPending(true);
    try {
      const res = await fetch("/api/auth/otp/send", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ phoneE164: phoneE164.trim() }),
      });
      const data = (await res.json()) as {
        ok?: boolean;
        challengeId?: string;
        error?: string;
      };
      if (!res.ok || !data.challengeId) {
        setError(data.error ?? "تعذّر إرسال رمز التحقق");
        return;
      }
      setChallengeId(data.challengeId);
    } catch {
      setError("تعذّر الاتصال بالخادم");
    } finally {
      setPending(false);
    }
  }

  async function verifyOtp(e: React.FormEvent) {
    e.preventDefault();
    if (!challengeId) return;
    setError(null);
    setPending(true);
    try {
      const res = await fetch("/api/auth/session", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ challengeId, code: code.trim() }),
      });
      const data = (await res.json()) as {
        ok?: boolean;
        error?: string;
      };
      if (!res.ok) {
        setError(data.error ?? "رمز التحقق غير صحيح");
        return;
      }
      router.replace("/");
      router.refresh();
    } catch {
      setError("تعذّر التحقق من الرمز");
    } finally {
      setPending(false);
    }
  }

  return (
    <div className="space-y-6">
      {!challengeId ? (
        <form onSubmit={sendOtp} className="space-y-4">
          <div>
            <Label htmlFor="phone">رقم الجوال</Label>
            <Input
              id="phone"
              name="phone"
              dir="ltr"
              inputMode="tel"
              autoComplete="tel"
              placeholder="05XXXXXXXX أو +9665XXXXXXXX"
              value={phoneE164}
              onChange={(e) => setPhoneE164(e.target.value)}
              required
            />
            <p className="mt-1.5 text-xs text-[var(--color-on-surface-muted)]">
              يمكن إدخال الرقم بصيغة 05… أو +9665…، ويتحقق Places Core منه مقابل
              قائمة السماح في بيئة الخادم فقط.
            </p>
          </div>
          {error ? (
            <p className="text-sm text-[var(--color-error)]" role="alert">
              {error}
            </p>
          ) : null}
          <Button type="submit" className="w-full" disabled={pending}>
            {pending ? "جارٍ الإرسال…" : "إرسال رمز التحقق"}
          </Button>
        </form>
      ) : (
        <form onSubmit={verifyOtp} className="space-y-4">
          <div>
            <Label htmlFor="otp">رمز التحقق</Label>
            <Input
              id="otp"
              name="otp"
              dir="ltr"
              inputMode="numeric"
              autoComplete="one-time-code"
              value={code}
              onChange={(e) => setCode(e.target.value)}
              required
            />
          </div>
          {error ? (
            <p className="text-sm text-[var(--color-error)]" role="alert">
              {error}
            </p>
          ) : null}
          <Button type="submit" className="w-full" disabled={pending}>
            {pending ? "جارٍ التحقق…" : "تسجيل الدخول"}
          </Button>
          <Button
            type="button"
            variant="ghost"
            className="w-full"
            disabled={pending}
            onClick={() => {
              setChallengeId(null);
              setCode("");
              setError(null);
            }}
          >
            تغيير الرقم
          </Button>
        </form>
      )}
    </div>
  );
}
