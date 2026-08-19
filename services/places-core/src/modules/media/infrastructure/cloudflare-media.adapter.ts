import { Inject, Injectable } from '@nestjs/common';
import { APP_CONFIG } from '../../../shared/config/app-config';
import { AppEnv } from '../../../shared/config/env';
import { AppError } from '../../../shared/errors/app-error';
import { ErrorCodes } from '../../../shared/errors/error-codes';
import {
  CloudflareImageStatus,
  CloudflareMediaPort,
  CloudflareStreamStatus,
  ImagesDirectUploadResult,
  StreamDirectUploadResult,
} from '../domain/cloudflare-media.port';

/**
 * Real Cloudflare adapter — same HTTP endpoints as DAR CAR `functions/index.js`.
 * Secrets: CF_ACCOUNT_ID, CF_IMAGES_TOKEN, CF_IMAGES_HASH, CF_STREAM_TOKEN, CF_STREAM_SUBDOMAIN.
 */
@Injectable()
export class CloudflareMediaAdapter implements CloudflareMediaPort {
  readonly providerName = 'cloudflare' as const;

  constructor(@Inject(APP_CONFIG) private readonly env: AppEnv) {}

  imageDeliveryUrl(imagesHash: string, cloudflareImageId: string, variant = 'public'): string {
    return `https://imagedelivery.net/${imagesHash}/${cloudflareImageId}/${variant}`;
  }

  streamPlaybackUrl(streamUid: string): string {
    const subdomain = this.env.cfStreamSubdomain?.trim() || 'customer';
    return `https://${subdomain}.cloudflarestream.com/${streamUid}/manifest/video.m3u8`;
  }

  async createImagesDirectUpload(): Promise<ImagesDirectUploadResult> {
    const { accountId, token, imagesHash } = this.requireImages();
    // CF Images direct_upload requires multipart/form-data (JSON → 415/5415).
    const prefix = (process.env.CF_ASSET_PREFIX ?? 'places-wave1-').trim();
    const form = new FormData();
    form.append('requireSignedURLs', 'false');
    form.append(
      'metadata',
      JSON.stringify({ places_wave: 'rc2', prefix, isolation: 'places-core' }),
    );
    let json: { result?: { uploadURL?: string; id?: string } };
    try {
      json = await this.cfForm(
        `https://api.cloudflare.com/client/v4/accounts/${accountId}/images/v2/direct_upload`,
        token,
        'images',
        form,
      );
    } catch (err) {
      // Only retry the older route for API-shape failures; auth/entitlement
      // rejections must surface as-is instead of being masked by a second 403.
      if (!isApiShapeFailure(err)) throw err;
      const formV1 = new FormData();
      formV1.append('requireSignedURLs', 'false');
      formV1.append(
        'metadata',
        JSON.stringify({ places_wave: 'rc2', prefix, isolation: 'places-core' }),
      );
      json = await this.cfForm(
        `https://api.cloudflare.com/client/v4/accounts/${accountId}/images/v1/direct_upload`,
        token,
        'images',
        formV1,
      );
    }
    const uploadURL = json.result?.uploadURL;
    if (!uploadURL) {
      throw new AppError(ErrorCodes.INTERNAL, 'Cloudflare Images did not return uploadURL', undefined, true);
    }
    return {
      uploadURL,
      imagesHash,
      cloudflareImageId: json.result?.id ?? null,
    };
  }

  async getImageStatus(cloudflareImageId: string): Promise<CloudflareImageStatus> {
    const { accountId, token } = this.requireImages();
    const url = `https://api.cloudflare.com/client/v4/accounts/${accountId}/images/v1/${cloudflareImageId}`;
    const res = await this.fetchWithTimeout(url, {
      method: 'GET',
      headers: { Authorization: `Bearer ${token}` },
    });
    if (res.status === 404) {
      return { exists: false, ready: false, draft: true };
    }
    if (!res.ok) {
      throw await this.cfResponseFailure('images', 'GET', url, res);
    }
    const json = (await res.json().catch(() => ({}))) as {
      result?: { draft?: boolean; id?: string };
    };
    const draft = json.result?.draft === true;
    return { exists: true, draft, ready: !draft };
  }

  async deleteImage(cloudflareImageId: string): Promise<void> {
    const { accountId, token } = this.requireImages();
    const url = `https://api.cloudflare.com/client/v4/accounts/${accountId}/images/v1/${cloudflareImageId}`;
    const res = await this.fetchWithTimeout(url, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${token}` },
    });
    if (res.status !== 200 && res.status !== 404) {
      throw await this.cfResponseFailure('images', 'DELETE', url, res);
    }
  }

  async createStreamDirectUpload(title?: string): Promise<StreamDirectUploadResult> {
    const { accountId, token, subdomain } = this.requireStream();
    const prefix = (process.env.CF_ASSET_PREFIX ?? 'places-wave1-').trim();
    const name = `${prefix}${title?.trim() || 'upload'}`.slice(0, 500);
    const body: Record<string, unknown> = {
      maxDurationSeconds: 240,
      meta: { name, places_wave: 'rc2', isolation: 'places-core' },
    };
    const json = await this.cfJson<{ result?: { uploadURL?: string; uid?: string } }>(
      'POST',
      `https://api.cloudflare.com/client/v4/accounts/${accountId}/stream/direct_upload`,
      token,
      'stream',
      body,
    );
    const uploadURL = json.result?.uploadURL;
    const uid = json.result?.uid;
    if (!uploadURL || !uid) {
      throw new AppError(ErrorCodes.INTERNAL, 'Cloudflare Stream direct_upload unexpected', undefined, true);
    }
    return { uploadURL, uid, customerSubdomain: subdomain };
  }

  async getStreamStatus(streamUid: string): Promise<CloudflareStreamStatus> {
    const { accountId, token } = this.requireStream();
    const url = `https://api.cloudflare.com/client/v4/accounts/${accountId}/stream/${streamUid}`;
    const res = await this.fetchWithTimeout(url, {
      method: 'GET',
      headers: { Authorization: `Bearer ${token}` },
    });
    if (res.status === 404) {
      return { exists: false, readyToStream: false };
    }
    if (!res.ok) {
      throw await this.cfResponseFailure('stream', 'GET', url, res);
    }
    const json = (await res.json().catch(() => ({}))) as {
      result?: { readyToStream?: boolean };
    };
    const readyToStream = json.result?.readyToStream === true;
    return { exists: true, readyToStream };
  }

  async deleteStream(streamUid: string): Promise<void> {
    const { accountId, token } = this.requireStream();
    const url = `https://api.cloudflare.com/client/v4/accounts/${accountId}/stream/${streamUid}`;
    const res = await this.fetchWithTimeout(url, {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${token}` },
    });
    if (res.status !== 200 && res.status !== 404) {
      throw await this.cfResponseFailure('stream', 'DELETE', url, res);
    }
  }

  private requireImages(): { accountId: string; token: string; imagesHash: string } {
    const accountId = this.env.cfAccountId?.trim() ?? '';
    const token = this.env.cfImagesToken?.trim() ?? '';
    const imagesHash = this.env.cfImagesHash?.trim() ?? '';
    if (!accountId || !token || !imagesHash) {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        'Cloudflare Images not configured (CF_ACCOUNT_ID / CF_IMAGES_TOKEN / CF_IMAGES_HASH)',
      );
    }
    return { accountId, token, imagesHash };
  }

  private requireStream(): { accountId: string; token: string; subdomain: string } {
    const accountId = this.env.cfAccountId?.trim() ?? '';
    const token = this.env.cfStreamToken?.trim() ?? '';
    const subdomain = this.env.cfStreamSubdomain?.trim() ?? '';
    if (!accountId || !token || !subdomain) {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        'Cloudflare Stream not configured (CF_ACCOUNT_ID / CF_STREAM_TOKEN / CF_STREAM_SUBDOMAIN)',
      );
    }
    return { accountId, token, subdomain };
  }

  private cfTimeoutMs(): number {
    const n = Number(process.env.PLACES_CF_FETCH_TIMEOUT_MS ?? 12_000);
    return Number.isFinite(n) && n >= 1000 ? n : 12_000;
  }

  private async fetchWithTimeout(
    url: string,
    init: RequestInit,
  ): Promise<Response> {
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), this.cfTimeoutMs());
    try {
      return await fetch(url, { ...init, signal: ctrl.signal });
    } catch (err) {
      if ((err as { name?: string })?.name === 'AbortError') {
        throw new AppError(
          ErrorCodes.INTERNAL,
          `Cloudflare fetch timeout after ${this.cfTimeoutMs()}ms`,
          { url: url.split('?')[0] },
          true,
        );
      }
      throw err;
    } finally {
      clearTimeout(timer);
    }
  }

  private async cfJson<T = { result?: unknown }>(
    method: string,
    url: string,
    token: string,
    service: CfService,
    body?: unknown,
  ): Promise<T> {
    const res = await this.fetchWithTimeout(url, {
      method,
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    const json = (await res.json().catch(() => ({}))) as T & CfEnvelope;
    if (!res.ok || json.success === false) {
      throw this.cfFailure(service, method, url, res.status, json);
    }
    return json;
  }

  private async cfForm<T = { result?: { uploadURL?: string; id?: string } }>(
    url: string,
    token: string,
    service: CfService,
    form: FormData,
  ): Promise<T> {
    const res = await this.fetchWithTimeout(url, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
      body: form,
    });
    const json = (await res.json().catch(() => ({}))) as T & CfEnvelope;
    if (!res.ok || json.success === false) {
      throw this.cfFailure(service, 'POST', url, res.status, json);
    }
    return json;
  }

  /** Reads the error body once so failures keep Cloudflare's own code/message. */
  private async cfResponseFailure(
    service: CfService,
    method: string,
    url: string,
    res: Response,
  ): Promise<AppError> {
    const raw = await res.text().catch(() => '');
    let envelope: CfEnvelope = {};
    try {
      envelope = raw ? (JSON.parse(raw) as CfEnvelope) : {};
    } catch {
      envelope = { errors: raw ? [{ message: raw.slice(0, 200) }] : [] };
    }
    return this.cfFailure(service, method, url, res.status, envelope);
  }

  /**
   * Cloudflare returns 403 both when a token lacks scope and when the account
   * has no Images/Stream entitlement. `reason` keeps those apart so callers can
   * explain the failure instead of surfacing a bare 500.
   */
  private cfFailure(
    service: CfService,
    method: string,
    url: string,
    httpStatus: number,
    envelope: CfEnvelope,
  ): AppError {
    const first = envelope.errors?.find((e) => e?.code != null || e?.message != null);
    const cfCode = typeof first?.code === 'number' ? first.code : null;
    const cfMessage = first?.message?.trim() ?? null;
    const path = url.replace('https://api.cloudflare.com/client/v4', '');
    const parts = [`Cloudflare ${service} rejected ${method} ${path} → HTTP ${httpStatus}`];
    if (cfCode !== null) parts.push(`cf_code=${cfCode}`);
    if (cfMessage) parts.push(cfMessage);
    return new AppError(
      ErrorCodes.MEDIA_PROVIDER_UNAVAILABLE,
      parts.join(' · '),
      {
        provider: 'cloudflare',
        service,
        httpStatus,
        cfCode,
        cfMessage,
        reason: cfReason(httpStatus, cfCode),
      },
      httpStatus >= 500 || httpStatus === 429,
    );
  }
}

type CfService = 'images' | 'stream';

interface CfEnvelope {
  success?: boolean;
  errors?: Array<{ code?: number; message?: string } | null>;
}

/**
 * Stable machine reason for a Cloudflare rejection. Codes are Cloudflare's own:
 * 5403 = account not entitled to Images, 10002 = Stream request not authorized,
 * 10000 = token invalid for the resource, 9109 = token missing account scope.
 */
function cfReason(httpStatus: number, cfCode: number | null): string {
  switch (cfCode) {
    case 5403:
      return 'images_service_not_enabled';
    case 10002:
      return 'stream_not_authorized';
    case 10000:
      return 'token_invalid';
    case 9109:
      return 'token_scope_missing';
    case 5415:
      return 'unsupported_content_type';
    default:
      break;
  }
  if (httpStatus === 401) return 'token_invalid';
  if (httpStatus === 403) return 'not_authorized';
  if (httpStatus === 404) return 'resource_not_found';
  if (httpStatus === 415) return 'unsupported_content_type';
  if (httpStatus === 429) return 'rate_limited';
  if (httpStatus >= 500) return 'provider_error';
  return 'unknown';
}

/** True only when the route/payload shape looks wrong, so an older API version is worth trying. */
function isApiShapeFailure(err: unknown): boolean {
  if (!(err instanceof AppError)) return true;
  const reason = err.details?.reason;
  return reason === 'resource_not_found' || reason === 'unsupported_content_type';
}
