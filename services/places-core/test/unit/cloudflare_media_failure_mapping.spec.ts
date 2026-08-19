import { AppEnv } from '../../src/shared/config/env';
import { AppError } from '../../src/shared/errors/app-error';
import { ErrorCodes } from '../../src/shared/errors/error-codes';
import { CloudflareMediaAdapter } from '../../src/modules/media/infrastructure/cloudflare-media.adapter';

const env = {
  cfAccountId: 'acct-1',
  cfImagesToken: 'images-token',
  cfImagesHash: 'images-hash',
  cfStreamToken: 'stream-token',
  cfStreamSubdomain: 'customer-test',
} as AppEnv;

function cfResponse(status: number, code: number, message: string): Response {
  return new Response(JSON.stringify({ success: false, errors: [{ code, message }] }), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

describe('Cloudflare media failure mapping', () => {
  const realFetch = global.fetch;
  let adapter: CloudflareMediaAdapter;
  let fetchMock: jest.Mock;

  beforeEach(() => {
    adapter = new CloudflareMediaAdapter(env);
    fetchMock = jest.fn();
    global.fetch = fetchMock as unknown as typeof fetch;
  });

  afterAll(() => {
    global.fetch = realFetch;
  });

  it('maps Stream 10002 to a non-retryable provider outage', async () => {
    fetchMock.mockResolvedValue(
      cfResponse(403, 10002, 'Authorization Failure: credentials are not authorized'),
    );

    const err: AppError = await adapter.createStreamDirectUpload('clip').catch((e) => e);

    expect(err).toBeInstanceOf(AppError);
    expect(err.code).toBe(ErrorCodes.MEDIA_PROVIDER_UNAVAILABLE);
    expect(err.httpStatus).toBe(503);
    expect(err.retryable).toBe(false);
    expect(err.details).toMatchObject({
      provider: 'cloudflare',
      service: 'stream',
      httpStatus: 403,
      cfCode: 10002,
      reason: 'stream_not_authorized',
    });
  });

  it('maps Images 5403 to service-not-enabled without masking it via the v1 route', async () => {
    fetchMock.mockResolvedValue(
      cfResponse(403, 5403, 'The given account is not valid or is not authorized'),
    );

    const err: AppError = await adapter.createImagesDirectUpload().catch((e) => e);

    expect(err.code).toBe(ErrorCodes.MEDIA_PROVIDER_UNAVAILABLE);
    expect(err.details).toMatchObject({
      service: 'images',
      cfCode: 5403,
      reason: 'images_service_not_enabled',
    });
    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(String(fetchMock.mock.calls[0][0])).toContain('/images/v2/direct_upload');
  });

  it('still falls back to the v1 route when v2 is absent', async () => {
    fetchMock
      .mockResolvedValueOnce(cfResponse(404, 7003, 'Could not route to endpoint'))
      .mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            success: true,
            result: { uploadURL: 'https://upload.imagedelivery.net/x/y', id: 'img-1' },
          }),
          { status: 200, headers: { 'content-type': 'application/json' } },
        ),
      );

    const res = await adapter.createImagesDirectUpload();

    expect(res.uploadURL).toContain('upload.imagedelivery.net');
    expect(res.cloudflareImageId).toBe('img-1');
    expect(fetchMock).toHaveBeenCalledTimes(2);
    expect(String(fetchMock.mock.calls[1][0])).toContain('/images/v1/direct_upload');
  });

  it('surfaces Stream status failures as provider outages, not internal errors', async () => {
    fetchMock.mockResolvedValue(cfResponse(403, 10002, 'Authorization Failure'));

    const err: AppError = await adapter.getStreamStatus('uid-1').catch((e) => e);

    expect(err.code).toBe(ErrorCodes.MEDIA_PROVIDER_UNAVAILABLE);
    expect(err.details).toMatchObject({ reason: 'stream_not_authorized' });
  });

  it('treats provider 5xx as retryable', async () => {
    fetchMock.mockResolvedValue(cfResponse(502, 0, 'bad gateway'));

    const err: AppError = await adapter.createStreamDirectUpload().catch((e) => e);

    expect(err.retryable).toBe(true);
    expect(err.details).toMatchObject({ reason: 'provider_error' });
  });
});
