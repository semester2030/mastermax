import { Injectable } from "@nestjs/common";
import { AppError } from "../../../shared/errors/app-error";
import { ErrorCodes } from "../../../shared/errors/error-codes";
import { PgService } from "../../../shared/database/pg.service";
import { AuditService } from "../../audit/application/audit.service";
import { newId } from "../../../shared/ids/ids";

export type ModerationDecision = "approved" | "rejected";

/**
 * Single shared media moderation path (Phase 5 / F-V2-011 / F-V3-004).
 * Admin + Internal Operator controllers stay thin and call this service only.
 * CF deletes go through media_cf_delete_outbox (Phase 6) — never inline.
 */
@Injectable()
export class MediaModerationService {
  constructor(
    private readonly pg: PgService,
    private readonly audit: AuditService,
  ) {}

  async listPending(limit = 50): Promise<
    Array<{
      id: string;
      venueId: string;
      providerId: string;
      kind: string;
      moderationStatus: string;
      url: string | null;
      coverUrl: string | null;
      streamUid: string | null;
      cloudflareImageId: string | null;
      casVersion: number;
      isCover: boolean;
      createdAt: string;
    }>
  > {
    const lim = Math.min(Math.max(limit, 1), 100);
    const r = await this.pg.query<{
      id: string;
      venue_id: string;
      provider_id: string;
      kind: string;
      moderation_status: string;
      url: string | null;
      cover_url: string | null;
      stream_uid: string | null;
      cloudflare_image_id: string | null;
      cas_version: number;
      is_cover: boolean;
      created_at: Date;
    }>(
      `SELECT id, venue_id, provider_id, kind, moderation_status, url, cover_url,
              stream_uid, cloudflare_image_id, cas_version, is_cover, created_at
       FROM venue_media
       WHERE moderation_status = 'pending' AND deleted_at IS NULL
       ORDER BY created_at ASC
       LIMIT $1`,
      [lim],
    );
    return r.rows.map((row) => ({
      id: row.id,
      venueId: row.venue_id,
      providerId: row.provider_id,
      kind: row.kind,
      moderationStatus: row.moderation_status,
      url: row.url,
      coverUrl: row.cover_url,
      streamUid: row.stream_uid,
      cloudflareImageId: row.cloudflare_image_id,
      casVersion: row.cas_version,
      isCover: row.is_cover,
      createdAt: row.created_at.toISOString(),
    }));
  }

  async moderate(input: {
    mediaId: string;
    decision: ModerationDecision;
    expectedCasVersion: number;
    actorUid: string;
    actorRole: "placesAdmin" | "placesInternalOperator";
    correlationId: string;
    reason?: string;
    rejectionReason?: string;
  }): Promise<{
    ok: true;
    moderationStatus: ModerationDecision;
    casVersion: number;
  }> {
    if (input.decision !== "approved" && input.decision !== "rejected") {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        "decision must be approved|rejected",
      );
    }
    const before = await this.pg.query<{
      id: string;
      venue_id: string;
      provider_id: string;
      inventory_type_id: string | null;
      moderation_status: string;
      cloudflare_image_id: string | null;
      stream_uid: string | null;
      is_cover: boolean;
      kind: string;
      deleted_at: Date | null;
      cas_version: number;
    }>(
      `SELECT id, venue_id, provider_id, inventory_type_id, moderation_status,
              cloudflare_image_id, stream_uid, is_cover, kind, deleted_at, cas_version
       FROM venue_media WHERE id = $1`,
      [input.mediaId],
    );
    if (!before.rowCount || before.rows[0].deleted_at) {
      throw new AppError(ErrorCodes.NOT_FOUND, "Media not found");
    }
    const row = before.rows[0];
    await this.pg.tx(async (c) => {
      await c.query(`SELECT places_lock_media_write_scope($1::uuid, $2::uuid)`, [
        row.venue_id,
        row.inventory_type_id,
      ]);
      if (
        input.decision === "approved" &&
        row.is_cover &&
        row.kind === "image"
      ) {
        const existingApprovedCover = row.inventory_type_id
          ? await c.query(
              `SELECT 1 FROM venue_media
               WHERE inventory_type_id = $1 AND kind = 'image'
                 AND moderation_status = 'approved' AND is_cover = TRUE
                 AND deleted_at IS NULL AND id <> $2
               LIMIT 1`,
              [row.inventory_type_id, input.mediaId],
            )
          : await c.query(
              `SELECT 1 FROM venue_media
               WHERE venue_id = $1 AND inventory_type_id IS NULL AND kind = 'image'
                 AND moderation_status = 'approved' AND is_cover = TRUE
                 AND deleted_at IS NULL AND id <> $2
               LIMIT 1`,
              [row.venue_id, input.mediaId],
            );
        if (existingApprovedCover.rowCount) {
          await c.query(`UPDATE venue_media SET is_cover = FALSE WHERE id = $1`, [
            input.mediaId,
          ]);
        }
      }
      if (
        input.decision === "rejected" &&
        row.kind === "image" &&
        row.inventory_type_id == null &&
        row.moderation_status === "approved"
      ) {
        const venue = await c.query<{ status: string }>(
          `SELECT status FROM venues WHERE id = $1 FOR NO KEY UPDATE`,
          [row.venue_id],
        );
        if (venue.rows[0]?.status === "published") {
          const other = await c.query(
            `SELECT 1 FROM venue_media
             WHERE venue_id = $1 AND inventory_type_id IS NULL AND kind = 'image'
               AND moderation_status = 'approved' AND deleted_at IS NULL AND id <> $2
             LIMIT 1`,
            [row.venue_id, input.mediaId],
          );
          if (!other.rowCount) {
            throw new AppError(
              ErrorCodes.VALIDATION_ERROR,
              "Cannot reject last approved venue image while venue is published",
            );
          }
        }
      }
      if (input.decision === "approved" && row.kind === "video") {
        await c.query(
          `SELECT places_expire_stale_video_upload_sessions($1::uuid)`,
          [row.venue_id],
        );
        const used = await c.query<{ c: string }>(
          `SELECT places_video_quota_used($1::uuid)::text AS c`,
          [row.venue_id],
        );
        const alreadyLive =
          row.moderation_status === "pending" ||
          row.moderation_status === "approved";
        const occupied = Number(used.rows[0].c) + (alreadyLive ? 0 : 1);
        if (occupied > 3) {
          throw new AppError(
            ErrorCodes.VALIDATION_ERROR,
            "Video quota full (max 3 pending+approved)",
          );
        }
      }
      const cas = await c.query(
        `UPDATE venue_media SET
           moderation_status = $2,
           rejection_reason = CASE WHEN $2 = 'rejected' THEN $4 ELSE NULL END,
           cas_version = cas_version + 1,
           updated_at = now()
         WHERE id = $1 AND cas_version = $3 AND deleted_at IS NULL`,
        [
          input.mediaId,
          input.decision,
          input.expectedCasVersion,
          input.rejectionReason ?? input.reason ?? null,
        ],
      );
      if (cas.rowCount !== 1) {
        throw new AppError(
          ErrorCodes.DUPLICATE_REQUEST,
          "Media CAS conflict — reload and retry",
        );
      }
      // Phase 6: never inline CF delete — enqueue durable outbox (retry/alert).
      if (
        input.decision === "rejected" &&
        (row.cloudflare_image_id || row.stream_uid)
      ) {
        await c.query(
          `INSERT INTO media_cf_delete_outbox
             (id, kind, cloudflare_image_id, stream_uid, venue_media_id, status, next_attempt_at)
           VALUES ($1,$2,$3,$4,$5,'pending',now())`,
          [
            newId(),
            row.kind === "video" ? "video" : "image",
            row.cloudflare_image_id,
            row.stream_uid,
            input.mediaId,
          ],
        );
      }
      await this.audit.write(
        {
          actorUid: input.actorUid,
          actorRole: input.actorRole,
          entityType: "media",
          entityId: input.mediaId,
          before: before.rows[0],
          after: {
            moderationStatus: input.decision,
            reason: input.reason,
          },
          reason: input.reason,
          correlationId: input.correlationId,
        },
        c,
      );
    });
    return {
      ok: true,
      moderationStatus: input.decision,
      casVersion: input.expectedCasVersion + 1,
    };
  }
}
