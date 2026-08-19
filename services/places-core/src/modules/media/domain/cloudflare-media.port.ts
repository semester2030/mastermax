/**
 * Cloudflare media port — mirrors DAR CAR Cloud Functions contracts
 * (functions/index.js createImagesDirectUpload / createStreamDirectUpload / delete).
 * Places Core issues signed upload URLs; bytes never transit NestJS.
 */
export interface ImagesDirectUploadResult {
  uploadURL: string;
  imagesHash: string;
  /** Cloudflare may return id early on some API versions; often null until complete. */
  cloudflareImageId?: string | null;
}

export interface StreamDirectUploadResult {
  uploadURL: string;
  uid: string;
  customerSubdomain: string;
}

export interface CloudflareImageStatus {
  exists: boolean;
  /** False while still a draft / not fully uploaded. */
  ready: boolean;
  draft: boolean;
}

export interface CloudflareStreamStatus {
  exists: boolean;
  readyToStream: boolean;
}

export interface CloudflareMediaPort {
  readonly providerName: 'cloudflare';
  createImagesDirectUpload(): Promise<ImagesDirectUploadResult>;
  deleteImage(cloudflareImageId: string): Promise<void>;
  /** Provider verification before binding a client-supplied image id. */
  getImageStatus(cloudflareImageId: string): Promise<CloudflareImageStatus>;
  createStreamDirectUpload(title?: string): Promise<StreamDirectUploadResult>;
  deleteStream(streamUid: string): Promise<void>;
  getStreamStatus(streamUid: string): Promise<CloudflareStreamStatus>;
  /** Delivery URL helper — same scheme as CloudflareImagesService. */
  imageDeliveryUrl(imagesHash: string, cloudflareImageId: string, variant?: string): string;
  /** HLS playback — same scheme as CloudflareStreamService / DAR CAR. */
  streamPlaybackUrl(streamUid: string): string;
}

export const CLOUDFLARE_MEDIA_PORT = Symbol('CLOUDFLARE_MEDIA_PORT');
