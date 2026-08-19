export type PlacesClaim =
  | 'placesProvider'
  | 'placesAdmin'
  | 'placesFinance'
  | 'placesSupport'
  | 'placesInternalOperator';

export interface AuthUser {
  uid: string;
  claims: Partial<Record<PlacesClaim, boolean>>;
  /** Bound trial provider for placesInternalOperator sessions. */
  onBehalfOfProviderId?: string;
  /** Operator session id (auth_sessions.jti). */
  jti?: string;
}

export function hasClaim(user: AuthUser, claim: PlacesClaim): boolean {
  return user.claims[claim] === true;
}
