import { CloudflareMediaStubAdapter } from '../../src/modules/media/infrastructure/cloudflare-media.stub.adapter';
import {
  isAllowedCloudflareDeliveryUrl,
  isAllowedCloudflareMediaHostname,
} from '../../src/modules/media/domain/cloudflare-hostname-allowlist';
import { resolveStreamUrl } from '../../src/modules/filters/application/discovery-surface';

describe('pre-provider Cloudflare media reuse', () => {
  const cf = new CloudflareMediaStubAdapter();

  it('builds imagedelivery variants like DAR CAR Images', () => {
    const base = cf.imageDeliveryUrl('acctHash', 'img-123', 'public');
    expect(base).toBe('https://imagedelivery.net/acctHash/img-123/public');
    expect(cf.imageDeliveryUrl('acctHash', 'img-123', 'gallery')).toContain('/gallery');
    expect(cf.imageDeliveryUrl('acctHash', 'img-123', 'thumbnail')).toContain('/thumbnail');
    expect(cf.imageDeliveryUrl('acctHash', 'img-123', 'cover')).toContain('/cover');
  });

  it('builds Stream HLS playback like DAR CAR Stream', () => {
    const url = cf.streamPlaybackUrl('uid-abc');
    expect(url).toBe(
      'https://customer-stub.cloudflarestream.com/uid-abc/manifest/video.m3u8',
    );
  });

  it('direct image upload returns uploadURL without Nest byte path', async () => {
    const d = await cf.createImagesDirectUpload();
    expect(d.uploadURL).toMatch(/^https:\/\//);
    expect(d.imagesHash).toBeTruthy();
    expect(d.cloudflareImageId).toBeTruthy();
  });

  it('getImageStatus verifies stub-minted and verified- ids with readiness', async () => {
    const d = await cf.createImagesDirectUpload();
    const ok = await cf.getImageStatus(d.cloudflareImageId!);
    expect(ok.exists).toBe(true);
    expect(ok.ready).toBe(true);
    expect(ok.draft).toBe(false);
    expect((await cf.getImageStatus('verified-abc')).exists).toBe(true);
    expect((await cf.getImageStatus('unknown-client-only')).exists).toBe(false);
    cf.markImageDraft(d.cloudflareImageId!);
    const draft = await cf.getImageStatus(d.cloudflareImageId!);
    expect(draft.ready).toBe(false);
    expect(draft.draft).toBe(true);
  });

  it('getStreamStatus reports readyToStream', async () => {
    const d = await cf.createStreamDirectUpload('venue-hero');
    expect((await cf.getStreamStatus(d.uid)).readyToStream).toBe(true);
    cf.markStreamReady(d.uid, false);
    expect((await cf.getStreamStatus(d.uid)).readyToStream).toBe(false);
  });

  it('direct stream upload returns uploadURL + uid', async () => {
    const d = await cf.createStreamDirectUpload('venue-hero');
    expect(d.uploadURL).toMatch(/^https:\/\//);
    expect(d.uid).toBeTruthy();
    expect(d.customerSubdomain).toBeTruthy();
  });

  it('exact hostname allowlist rejects substring spoofs', () => {
    expect(isAllowedCloudflareMediaHostname('imagedelivery.net')).toBe(true);
    expect(isAllowedCloudflareMediaHostname('upload.imagedelivery.net')).toBe(true);
    expect(isAllowedCloudflareMediaHostname('evil-imagedelivery.net')).toBe(false);
    expect(isAllowedCloudflareMediaHostname('notimagedelivery.net')).toBe(false);
    expect(
      isAllowedCloudflareDeliveryUrl('https://evil.example/path/imagedelivery.net'),
    ).toBe(false);
    const url = 'https://firebasestorage.googleapis.com/v0/b/x/o/y';
    expect(isAllowedCloudflareDeliveryUrl(url)).toBe(false);
    expect(resolveStreamUrl(url)).toBeNull();
  });

  it('stub refuses construction when NODE_ENV=production', () => {
    const prev = process.env.NODE_ENV;
    process.env.NODE_ENV = 'production';
    try {
      expect(() => new CloudflareMediaStubAdapter()).toThrow(/production/);
    } finally {
      process.env.NODE_ENV = prev;
    }
  });
});
