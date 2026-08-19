"use client";

import { useState, useTransition } from "react";
import {
  ArrowDown,
  ArrowUp,
  ImagePlus,
  Star,
  Trash2,
  Video,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { EmptyState } from "@/components/ui/empty-state";
import {
  deleteMediaAction,
  finishImageUploadAction,
  finishVideoUploadAction,
  reorderMediaAction,
  setCoverAction,
  startImageUploadAction,
  startVideoUploadAction,
} from "@/lib/core/actions";
import { describeCloudflareUploadFailure } from "@/lib/core/media-errors";
import { operatorErrorAr } from "@/lib/operator-errors";
import type { MediaRow } from "@/lib/core/types";
import { MEDIA_LIMITS, mediaCasOf, mediaModerationOf } from "@/lib/core/types";

function moderationLabel(status: string): string {
  switch (status) {
    case "pending":
      return "بانتظار المراجعة";
    case "approved":
      return "مقبول";
    case "rejected":
      return "مرفوض";
    default:
      return "غير معروف";
  }
}

function kindLabel(kind?: string): string {
  return kind === "video" ? "فيديو" : "صورة";
}

export function MediaManager({
  venueId,
  items,
  inventoryTypeId,
  heading,
}: {
  venueId: string;
  items: MediaRow[];
  inventoryTypeId?: string;
  heading?: string;
}) {
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();
  const [ordered, setOrdered] = useState(items);
  const liveVideos = ordered.filter((m) => {
    if (m.kind !== "video") return false;
    const st = mediaModerationOf(m);
    return st === "pending" || st === "approved";
  }).length;
  const videosAtCap = liveVideos >= MEDIA_LIMITS.maxVideosPerScope;
  const liveImages = ordered.filter((m) => {
    if ((m.kind ?? "image") !== "image") return false;
    const st = mediaModerationOf(m);
    return st === "pending" || st === "approved";
  });
  const imagesAtCap = liveImages.length >= MEDIA_LIMITS.maxImagesPerScope;
  const approvedImages = ordered.filter(
    (m) =>
      (m.kind ?? "image") === "image" && mediaModerationOf(m) === "approved",
  );

  function fail(message: string) {
    setSuccess(null);
    setError(operatorErrorAr(message));
  }

  async function uploadImage(file: File) {
    setError(null);
    setSuccess(null);
    const started = await startImageUploadAction(venueId, inventoryTypeId);
    if (!started.ok) {
      fail(started.error);
      return;
    }
    const { uploadURL, uploadSessionId } = started.session;
    const cfId = started.session.cloudflareImageId;
    let cloudflareImageId = cfId ?? "";
    const stubBound =
      typeof uploadURL === "string" &&
      (uploadURL.includes("/stub/") || cloudflareImageId.startsWith("stub-img-"));
    if (stubBound) {
      fail("تعذّر رفع الصورة لأن خدمة الرفع غير جاهزة. أعد المحاولة لاحقًا.");
      return;
    }
    const body = new FormData();
    body.append("file", file);
    const uploadRes = await fetch(uploadURL, { method: "POST", body });
    if (!uploadRes.ok) {
      const raw = await uploadRes.text().catch(() => "");
      fail(describeCloudflareUploadFailure("images", uploadRes.status, raw));
      return;
    }
    try {
      const json = (await uploadRes.json()) as {
        result?: { id?: string };
        id?: string;
      };
      cloudflareImageId = json.result?.id ?? json.id ?? cloudflareImageId;
    } catch {
      // session id remains authoritative
    }
    if (!cloudflareImageId) {
      fail("اكتمل الرفع دون تأكيد الصورة. أعد المحاولة.");
      return;
    }
    const done = await finishImageUploadAction(venueId, {
      uploadSessionId,
      cloudflareImageId,
      isCover: ordered.length === 0,
      inventoryTypeId,
    });
    if (!done.ok) fail(done.error);
    else window.location.reload();
  }

  async function uploadVideo(file: File) {
    setError(null);
    setSuccess(null);
    const started = await startVideoUploadAction(
      venueId,
      file.name,
      inventoryTypeId,
    );
    if (!started.ok) {
      fail(started.error);
      return;
    }
    const { uploadURL, uploadSessionId } = started.session;
    const stubBound =
      typeof uploadURL === "string" && uploadURL.includes("/stub/");
    if (stubBound) {
      fail("تعذّر رفع الفيديو لأن خدمة الرفع غير جاهزة. أعد المحاولة لاحقًا.");
      return;
    }
    const body = new FormData();
    body.append("file", file);
    const uploadRes = await fetch(uploadURL, { method: "POST", body });
    if (!uploadRes.ok) {
      const raw = await uploadRes.text().catch(() => "");
      fail(describeCloudflareUploadFailure("stream", uploadRes.status, raw));
      return;
    }

    const maxAttempts = 40;
    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
      const done = await finishVideoUploadAction(venueId, uploadSessionId);
      if (done.ok) {
        window.location.reload();
        return;
      }
      const msg = done.error ?? "";
      const waiting =
        /readyToStream|not ready|Stream not ready|لم يكتمل|معالجة/i.test(msg);
      if (!waiting || attempt === maxAttempts) {
        fail(
          waiting
            ? "ما زال الفيديو قيد المعالجة. انتظر قليلًا ثم أعد المحاولة."
            : msg || "فشل إكمال رفع الفيديو. أعد المحاولة.",
        );
        return;
      }
      setSuccess(`الفيديو قيد المعالجة… (${attempt} من ${maxAttempts})`);
      await new Promise((r) => setTimeout(r, 3000));
    }
  }

  return (
    <div className="space-y-6">
      {heading ? <h3 className="text-base font-semibold">{heading}</h3> : null}
      <div className="flex flex-wrap gap-3">
        <label className="inline-flex cursor-pointer">
          <input
            type="file"
            accept="image/*"
            className="sr-only"
            disabled={pending || imagesAtCap}
            onChange={(e) => {
              const file = e.target.files?.[0];
              if (file) startTransition(() => void uploadImage(file));
            }}
          />
          <span className="inline-flex h-11 items-center gap-2 rounded-[var(--radius-md)] bg-[var(--color-primary)] px-5 text-sm font-semibold text-white">
            <ImagePlus className="h-4 w-4" aria-hidden />
            {imagesAtCap ? "حد الصور مكتمل" : "رفع صورة"}
          </span>
        </label>
        <label className="inline-flex cursor-pointer">
          <input
            type="file"
            accept="video/*"
            className="sr-only"
            disabled={pending || videosAtCap}
            onChange={(e) => {
              const file = e.target.files?.[0];
              if (file) startTransition(() => void uploadVideo(file));
            }}
          />
          <span className="inline-flex h-11 items-center gap-2 rounded-[var(--radius-md)] border border-[var(--color-border-strong)] bg-white px-5 text-sm font-semibold">
            <Video className="h-4 w-4" aria-hidden />
            {videosAtCap ? "حد الفيديو مكتمل" : "رفع فيديو"}
          </span>
        </label>
        <Button
          type="button"
          variant="secondary"
          disabled={pending || approvedImages.length < 2}
          onClick={() => {
            startTransition(async () => {
              const approved = ordered.filter(
                (m) =>
                  (m.kind ?? "image") === "image" &&
                  mediaModerationOf(m) === "approved",
              );
              const ids = approved.map((m) => m.id);
              const cas = approved.map((m) => mediaCasOf(m));
              const res = await reorderMediaAction(
                venueId,
                ids,
                cas,
                inventoryTypeId,
              );
              if (!res.ok) fail(res.error);
              else setSuccess("تم حفظ ترتيب الصور");
            });
          }}
        >
          حفظ الترتيب
        </Button>
      </div>

      {pending ? (
        <p className="text-sm text-[var(--color-text-secondary)]" role="status">
          جارٍ تنفيذ العملية…
        </p>
      ) : null}
      {error ? (
        <p className="text-sm text-[var(--color-error)]" role="alert">
          {error}
        </p>
      ) : null}
      {success ? (
        <p className="text-sm text-[#22C063]" role="status">
          {success}
        </p>
      ) : null}

      {ordered.length === 0 ? (
        <EmptyState
          title="لا توجد صور أو فيديو بعد"
          description={
            inventoryTypeId
              ? "ارفع فيديو وصورة معتمدين لهذه الوحدة قبل النشر."
              : "ارفع فيديو رئيسيًا وصورة غلاف معتمدة على مستوى المكان."
          }
        />
      ) : (
        <ul className="grid gap-3 sm:grid-cols-2">
          {ordered.map((item, index) => {
            const status = mediaModerationOf(item);
            const isCover = item.isCover ?? item.is_cover ?? item.cover;
            const isVideo = item.kind === "video";
            const isApprovedImage =
              !isVideo && status === "approved";
            const approvedIndex = approvedImages.findIndex((m) => m.id === item.id);
            return (
              <li
                key={item.id}
                className="overflow-hidden rounded-[var(--radius-md)] border border-[var(--color-border)] bg-white/80"
              >
                <div className="relative aspect-[16/10] bg-[var(--color-primary-light)]">
                  {item.url && !isVideo ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img
                      src={item.url}
                      alt={isCover ? "صورة الغلاف" : `صورة ${index + 1}`}
                      className="h-full w-full object-cover"
                    />
                  ) : (
                    <div className="grid h-full place-items-center text-sm text-[var(--color-text-secondary)]">
                      {isVideo ? "فيديو" : "لا توجد معاينة"}
                    </div>
                  )}
                  {isCover ? (
                    <span className="absolute start-2 top-2 rounded-full bg-[#22C063] px-2 py-0.5 text-xs font-bold text-white">
                      الغلاف
                    </span>
                  ) : null}
                </div>
                <div className="space-y-3 p-3">
                  <p className="text-sm font-medium">
                    {kindLabel(item.kind)} · {moderationLabel(status)}
                  </p>
                  <div className="flex flex-wrap gap-2">
                    <Button
                      type="button"
                      size="sm"
                      variant="ghost"
                      disabled={!isApprovedImage || approvedIndex <= 0}
                      onClick={() => {
                        const next = [...ordered];
                        const prevApproved = approvedImages[approvedIndex - 1];
                        const a = next.findIndex((m) => m.id === item.id);
                        const b = next.findIndex((m) => m.id === prevApproved?.id);
                        if (a < 0 || b < 0) return;
                        const tmp = next[b]!;
                        next[b] = next[a]!;
                        next[a] = tmp;
                        setOrdered(next);
                      }}
                    >
                      <ArrowUp className="h-4 w-4" aria-hidden />
                      أعلى
                    </Button>
                    <Button
                      type="button"
                      size="sm"
                      variant="ghost"
                      disabled={
                        !isApprovedImage ||
                        approvedIndex < 0 ||
                        approvedIndex >= approvedImages.length - 1
                      }
                      onClick={() => {
                        const next = [...ordered];
                        const nxt = approvedImages[approvedIndex + 1];
                        const a = next.findIndex((m) => m.id === item.id);
                        const b = next.findIndex((m) => m.id === nxt?.id);
                        if (a < 0 || b < 0) return;
                        const tmp = next[b]!;
                        next[b] = next[a]!;
                        next[a] = tmp;
                        setOrdered(next);
                      }}
                    >
                      <ArrowDown className="h-4 w-4" aria-hidden />
                      أسفل
                    </Button>
                    {!isVideo ? (
                      <Button
                        type="button"
                        size="sm"
                        variant="secondary"
                        disabled={pending || !!isCover || !isApprovedImage}
                        onClick={() => {
                          startTransition(async () => {
                            const res = await setCoverAction(
                              venueId,
                              item.id,
                              mediaCasOf(item),
                            );
                            if (!res.ok) fail(res.error);
                            else window.location.reload();
                          });
                        }}
                      >
                        <Star className="h-4 w-4" aria-hidden />
                        تعيين غلاف
                      </Button>
                    ) : null}
                    <Button
                      type="button"
                      size="sm"
                      variant="danger"
                      disabled={pending}
                      onClick={() => {
                        startTransition(async () => {
                          const res = await deleteMediaAction(
                            venueId,
                            item.id,
                            mediaCasOf(item),
                          );
                          if (!res.ok) fail(res.error);
                          else window.location.reload();
                        });
                      }}
                    >
                      <Trash2 className="h-4 w-4" aria-hidden />
                      حذف
                    </Button>
                  </div>
                </div>
              </li>
            );
          })}
        </ul>
      )}
    </div>
  );
}
