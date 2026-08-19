"use client";

/**
 * Minimal global error boundary so Next production build can prerender
 * `/_global-error` without a broken React dispatcher (useContext null).
 */
export default function GlobalError({
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <html lang="ar" dir="rtl">
      <body style={{ fontFamily: "system-ui", padding: 24 }}>
        <h1>حدث خطأ</h1>
        <button type="button" onClick={() => reset()}>
          إعادة المحاولة
        </button>
      </body>
    </html>
  );
}
