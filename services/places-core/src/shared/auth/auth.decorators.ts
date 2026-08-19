import { SetMetadata, createParamDecorator, ExecutionContext } from '@nestjs/common';
import { AuthUser, PlacesClaim } from './auth-user';
import { IS_PUBLIC, REQUIRED_CLAIM, REQUIRED_ANY_CLAIM } from './auth.guard';

export const Public = (): ReturnType<typeof SetMetadata> => SetMetadata(IS_PUBLIC, true);
export const RequireClaim = (claim: PlacesClaim): ReturnType<typeof SetMetadata> =>
  SetMetadata(REQUIRED_CLAIM, claim);
export const RequireAnyClaim = (
  ...claims: PlacesClaim[]
): ReturnType<typeof SetMetadata> => SetMetadata(REQUIRED_ANY_CLAIM, claims);

export const CurrentUser = createParamDecorator((_data: unknown, ctx: ExecutionContext): AuthUser => {
  return ctx.switchToHttp().getRequest<{ user: AuthUser }>().user;
});
