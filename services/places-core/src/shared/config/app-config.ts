import { AppEnv, loadEnv } from './env';

export const APP_CONFIG = 'APP_CONFIG';

export function createAppConfig(): AppEnv {
  return loadEnv();
}
