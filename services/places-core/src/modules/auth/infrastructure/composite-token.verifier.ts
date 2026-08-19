import { Inject, Injectable } from '@nestjs/common';
import { AppError } from '../../../shared/errors/app-error';
import { ErrorCodes } from '../../../shared/errors/error-codes';
import { AuthUser } from '../../../shared/auth/auth-user';
import {
  TokenVerifierPort,
} from '../../../shared/auth/token-verifier.port';
import { OperatorAuthService } from '../application/operator-auth.service';

export const BASE_TOKEN_VERIFIER = Symbol('BASE_TOKEN_VERIFIER');

/**
 * Tries Places operator HS256 JWT first; falls back to stub/Firebase verifier.
 */
@Injectable()
export class CompositeTokenVerifier implements TokenVerifierPort {
  constructor(
    @Inject(BASE_TOKEN_VERIFIER) private readonly base: TokenVerifierPort,
    private readonly operators: OperatorAuthService,
  ) {}

  async verify(token: string): Promise<AuthUser> {
    if (token.split('.').length === 3) {
      try {
        const op = await this.operators.verifyAccessToken(token);
        return {
          uid: op.uid,
          claims: { placesInternalOperator: true },
          onBehalfOfProviderId: op.onBehalfOfProviderId,
          jti: op.jti,
        };
      } catch (e) {
        if (!(e instanceof AppError) || e.code !== ErrorCodes.UNAUTHENTICATED) {
          throw e;
        }
      }
    }
    return this.base.verify(token);
  }
}
