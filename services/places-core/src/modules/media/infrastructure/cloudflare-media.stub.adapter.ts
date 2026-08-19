import { Injectable } from '@nestjs/common';
import {
  CloudflareImageStatus,
  CloudflareMediaPort,
  CloudflareStreamStatus,
  ImagesDirectUploadResult,
  StreamDirectUploadResult,
} from '../domain/cloudflare-media.port';

/**
 * Test/dev stub — never used when real CF env is configured in production media path.
 * Does not claim to be a real PSP or storage backend.
 *
 * Set STUB_CF_OMIT_IMAGE_ID=1 to mint sessions without an early CF id (null-id path).
 * Set STUB_CF_IMAGE_DRAFT=1 so getImageStatus returns draft/not-ready.
 * Set STUB_CF_STREAM_NOT_READY=1 so getStreamStatus.readyToStream=false.
 * deleteImage / deleteStream: set STUB_CF_DELETE_FAIL=1 to force retryable failures.
 */
@Injectable()
export class CloudflareMediaStubAdapter implements CloudflareMediaPort {
  readonly providerName = 'cloudflare' as const;
  private readonly knownImageIds = new Set<string>();
  private readonly draftImageIds = new Set<string>();
  private readonly deletedImageIds = new Set<string>();
  private readonly knownStreamUids = new Set<string>();
  private readonly notReadyStreamUids = new Set<string>();
  private readonly deletedStreamUids = new Set<string>();

  constructor() {
    if (process.env.NODE_ENV === 'production') {
      throw new Error(
        'FATAL: CloudflareMediaStubAdapter must not be constructed when NODE_ENV=production',
      );
    }
  }

  imageDeliveryUrl(imagesHash: string, cloudflareImageId: string, variant = 'public'): string {
    return `https://imagedelivery.net/${imagesHash}/${cloudflareImageId}/${variant}`;
  }

  streamPlaybackUrl(streamUid: string): string {
    return `https://customer-stub.cloudflarestream.com/${streamUid}/manifest/video.m3u8`;
  }

  async createImagesDirectUpload(): Promise<ImagesDirectUploadResult> {
    const id = `stub-img-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
    this.knownImageIds.add(id);
    const omit = process.env.STUB_CF_OMIT_IMAGE_ID === '1';
    return {
      uploadURL: `https://upload.imagedelivery.net/stub/${id}`,
      imagesHash: 'stub-hash',
      cloudflareImageId: omit ? null : id,
    };
  }

  async getImageStatus(cloudflareImageId: string): Promise<CloudflareImageStatus> {
    if (this.deletedImageIds.has(cloudflareImageId)) {
      return { exists: false, ready: false, draft: true };
    }
    const known =
      this.knownImageIds.has(cloudflareImageId) ||
      cloudflareImageId.startsWith('stub-img-') ||
      cloudflareImageId.startsWith('verified-');
    if (!known) {
      return { exists: false, ready: false, draft: true };
    }
    const forceDraft =
      process.env.STUB_CF_IMAGE_DRAFT === '1' || this.draftImageIds.has(cloudflareImageId);
    return { exists: true, draft: forceDraft, ready: !forceDraft };
  }

  /** Test helper: register a client-supplied id as provider-verified. */
  registerKnownImageId(cloudflareImageId: string): void {
    this.knownImageIds.add(cloudflareImageId);
  }

  /** Test helper: mark image as draft/not ready. */
  markImageDraft(cloudflareImageId: string): void {
    this.draftImageIds.add(cloudflareImageId);
    this.knownImageIds.add(cloudflareImageId);
  }

  /** Test helper: clear draft flag so image is ready. */
  clearImageDraft(cloudflareImageId: string): void {
    this.draftImageIds.delete(cloudflareImageId);
  }

  async deleteImage(cloudflareImageId: string): Promise<void> {
    if (process.env.STUB_CF_DELETE_FAIL === '1') {
      throw new Error('stub CF image delete forced failure');
    }
    this.deletedImageIds.add(cloudflareImageId);
  }

  async createStreamDirectUpload(_title?: string): Promise<StreamDirectUploadResult> {
    const uid = `stub-stream-${Date.now()}`;
    this.knownStreamUids.add(uid);
    if (process.env.STUB_CF_STREAM_NOT_READY === '1') {
      this.notReadyStreamUids.add(uid);
    }
    return {
      uploadURL: `https://upload.cloudflarestream.com/stub/${uid}`,
      uid,
      customerSubdomain: 'customer-stub',
    };
  }

  async getStreamStatus(streamUid: string): Promise<CloudflareStreamStatus> {
    if (this.deletedStreamUids.has(streamUid)) {
      return { exists: false, readyToStream: false };
    }
    const known =
      this.knownStreamUids.has(streamUid) || streamUid.startsWith('stub-stream-');
    if (!known) {
      return { exists: false, readyToStream: false };
    }
    const notReady =
      process.env.STUB_CF_STREAM_NOT_READY === '1' ||
      this.notReadyStreamUids.has(streamUid);
    return { exists: true, readyToStream: !notReady };
  }

  /** Test helper: mark stream ready / not ready. */
  markStreamReady(streamUid: string, ready: boolean): void {
    this.knownStreamUids.add(streamUid);
    if (ready) this.notReadyStreamUids.delete(streamUid);
    else this.notReadyStreamUids.add(streamUid);
  }

  async deleteStream(streamUid: string): Promise<void> {
    if (process.env.STUB_CF_DELETE_FAIL === '1') {
      throw new Error('stub CF stream delete forced failure');
    }
    this.deletedStreamUids.add(streamUid);
  }
}
