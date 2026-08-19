/** Jest setupFiles: force stub auth/media before AppModule createAppConfig(). */
process.env.NODE_ENV = 'test';
process.env.AUTH_MODE = 'stub';
process.env.STUB_WEBHOOK_SECRET = 'test-stub-secret';
process.env.CLOUDFLARE_MEDIA_ENABLED = 'false';
process.env.DATABASE_URL =
  process.env.DATABASE_URL || 'postgresql://127.0.0.1:5432/places_core_ci';
