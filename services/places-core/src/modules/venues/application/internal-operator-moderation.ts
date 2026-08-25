import { AuthUser, hasClaim } from "../../../shared/auth/auth-user";
import { AppError } from "../../../shared/errors/app-error";
import { ErrorCodes } from "../../../shared/errors/error-codes";

/**
 * Internal-operator media review is allowed in production when the JWT
 * carries placesInternalOperator. Tenancy still binds the actor to one provider.
 * NODE_ENV is not a substitute for that claim.
 */
export function assertInternalOperatorModeration(actor: AuthUser): void {
  if (!hasClaim(actor, "placesInternalOperator")) {
    throw new AppError(
      ErrorCodes.FORBIDDEN_PROVIDER_SCOPE,
      "placesInternalOperator required",
    );
  }
}
