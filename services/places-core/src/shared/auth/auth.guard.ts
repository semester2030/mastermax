import { CanActivate, ExecutionContext, Inject, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { AppError } from '../errors/app-error';
import { ErrorCodes } from '../errors/error-codes';
import { AuthUser, PlacesClaim, hasClaim } from './auth-user';
import { TOKEN_VERIFIER, TokenVerifierPort } from './token-verifier.port';

export const IS_PUBLIC = 'IS_PUBLIC';
export const REQUIRED_CLAIM = 'REQUIRED_CLAIM';
export const REQUIRED_ANY_CLAIM = 'REQUIRED_ANY_CLAIM';

@Injectable()
export class AuthGuard implements CanActivate {
  constructor(
    @Inject(TOKEN_VERIFIER) private readonly verifier: TokenVerifierPort,
    // Explicit Inject: tsx/esbuild load harness does not emit design:paramtypes.
    @Inject(Reflector) private readonly reflector: Reflector,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (isPublic) {
      return true;
    }
    const req = context.switchToHttp().getRequest<{ headers: Record<string, string | undefined>; user?: AuthUser }>();
    const header = req.headers.authorization ?? req.headers.Authorization;
    if (!header || !header.startsWith('Bearer ')) {
      throw new AppError(ErrorCodes.UNAUTHENTICATED, 'Missing bearer token');
    }
    const user = await this.verifier.verify(header.slice(7));
    req.user = user;
    const claim = this.reflector.getAllAndOverride<PlacesClaim>(REQUIRED_CLAIM, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (claim && !hasClaim(user, claim)) {
      throw new AppError(ErrorCodes.FORBIDDEN_PROVIDER_SCOPE, `Missing claim ${claim}`);
    }
    const anyClaims = this.reflector.getAllAndOverride<PlacesClaim[]>(
      REQUIRED_ANY_CLAIM,
      [context.getHandler(), context.getClass()],
    );
    if (anyClaims?.length && !anyClaims.some((c) => hasClaim(user, c))) {
      throw new AppError(
        ErrorCodes.FORBIDDEN_PROVIDER_SCOPE,
        `Missing one of claims ${anyClaims.join('|')}`,
      );
    }
    return true;
  }
}
