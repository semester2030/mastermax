import { Button } from "@/components/ui/button";
import { moderateMediaAction } from "@/lib/core/actions";
import {
  asArray,
  CoreApiError,
  listPendingModeration,
  requireProviderId,
} from "@/lib/core/client";
import { mediaCasOf } from "@/lib/core/types";

export const dynamic = "force-dynamic";

type PendingRow = {
  id: string;
  venueId?: string;
  venueName?: string;
  kind?: string;
  url?: string;
  moderationStatus?: string;
  casVersion?: number;
  cas_version?: number;
  isCover?: boolean;
};

export default async function ModerationPage() {
  const providerId = await requireProviderId();
  let items: PendingRow[] = [];
  let error: string | null = null;
  try {
    items = asArray(await listPendingModeration(providerId)) as PendingRow[];
  } catch (e) {
    error =
      e instanceof CoreApiError
        ? e.message
        : "تعذّر جلب الوسائط بانتظار الاعتماد";
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold">المراجعة</h1>
        <p className="mt-1 text-sm text-[var(--color-on-surface-muted)]">
          اعتماد الصور والفيديو قبل النشر. متاح لحساب المطوّر الداخلي فقط.
        </p>
      </div>

      {error ? (
        <p className="text-sm text-[var(--color-error)]" role="alert">
          {error}
        </p>
      ) : null}

      {items.length === 0 && !error ? (
        <p className="text-sm text-[var(--color-on-surface-muted)]">
          لا توجد وسائط بانتظار الاعتماد.
        </p>
      ) : (
        <ul className="space-y-3">
          {items.map((item) => {
            const cas = mediaCasOf(item);
            return (
              <li
                key={item.id}
                className="flex flex-wrap items-center justify-between gap-3 rounded-[var(--radius-md)] border border-[var(--color-border)] bg-white/80 p-4"
              >
                <div className="min-w-0 space-y-1">
                  <p className="text-sm font-semibold">
                    {item.venueName ?? "مكان"} ·{" "}
                    {item.kind === "video" ? "فيديو" : "صورة"}
                  </p>
                </div>
                <div className="flex gap-2">
                  <form
                    action={async () => {
                      "use server";
                      await moderateMediaAction(item.id, "approved", cas);
                    }}
                  >
                    <Button type="submit" size="sm">
                      قبول
                    </Button>
                  </form>
                  <form
                    action={async () => {
                      "use server";
                      await moderateMediaAction(
                        item.id,
                        "rejected",
                        cas,
                        "رفض من المشغّل الداخلي",
                      );
                    }}
                  >
                    <Button type="submit" size="sm" variant="secondary">
                      رفض
                    </Button>
                  </form>
                </div>
              </li>
            );
          })}
        </ul>
      )}
    </div>
  );
}
