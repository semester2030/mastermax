import { AuthUser } from './auth-user';

export interface TokenVerifierPort {
  verify(token: string): Promise<AuthUser>;
}

export const TOKEN_VERIFIER = Symbol('TOKEN_VERIFIER');
