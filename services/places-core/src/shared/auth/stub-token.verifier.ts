import { Injectable } from '@nestjs/common';
import { AppError } from '../errors/app-error';
import { ErrorCodes } from '../errors/error-codes';
import { AuthUser, PlacesClaim } from './auth-user';
import { TokenVerifierPort } from './token-verifier.port';

/**
 * Documented stub (AUTH_MODE=stub only).
 * Token format: stub.<uid>.<csv-claims>
 * Example: stub.user-1.placesProvider
 */
@Injectable()
export class StubTokenVerifier implements TokenVerifierPort {
  async verify(token: string): Promise<AuthUser> {
    if (!token.startsWith('stub.')) {
      throw new AppError(ErrorCodes.UNAUTHENTICATED, 'Stub token required in AUTH_MODE=stub');
    }
    const parts = token.split('.');
    const uid = parts[1];
    if (!uid) {
      throw new AppError(ErrorCodes.UNAUTHENTICATED, 'Invalid stub token');
    }
    const claims: AuthUser['claims'] = {};
    for (const c of (parts[2] ?? '').split(',').filter(Boolean)) {
      claims[c as PlacesClaim] = true;
    }
    return { uid, claims };
  }
}
