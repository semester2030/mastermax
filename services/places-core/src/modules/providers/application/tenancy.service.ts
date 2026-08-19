import { Injectable } from '@nestjs/common';
import { PgService } from '../../../shared/database/pg.service';
import { AppError } from '../../../shared/errors/app-error';
import { ErrorCodes } from '../../../shared/errors/error-codes';
import { AuthUser, hasClaim } from '../../../shared/auth/auth-user';
import { Permission, ProviderRole, can } from '../../../shared/rbac/permissions';

export interface ProviderMembership {
  providerId: string;
  role: ProviderRole;
  /** Present when placesInternalOperator acts on bound trial provider. */
  onBehalfOfProviderId?: string;
  actorRole: 'provider' | 'placesInternalOperator';
}

/** Wave1 operator allowlist (AUTH_INTERNAL_OPERATOR_FINAL). Fail-closed: any
 * permission not listed here is denied — no implicit grants via owner role. */
const OPERATOR_PERMS = new Set<Permission>([
  'venue.crud',
  'venue.publish',
  'calendar.edit',
  'media.upload',
  'bookings.view',
  'bookings.cancel',
  'inventory.block',
  'pricing.edit',
]);

@Injectable()
export class TenancyService {
  constructor(private readonly pg: PgService) {}

  async memberships(uid: string): Promise<ProviderMembership[]> {
    const res = await this.pg.query<{ provider_id: string; role: ProviderRole }>(
      `SELECT pu.provider_id, pu.role
       FROM provider_users pu
       JOIN providers p ON p.id = pu.provider_id
       WHERE pu.firebase_uid = $1
         AND pu.status = 'active'
         AND p.status = 'active'`,
      [uid],
    );
    return res.rows.map((r) => ({
      providerId: r.provider_id,
      role: r.role,
      actorRole: 'provider' as const,
    }));
  }

  /**
   * Provider self OR internal operator bound to PLACES_INTERNAL_OPERATOR_PROVIDER_ID.
   * Active status alone is insufficient for operator — UUID must match onBehalfOf.
   */
  async require(
    actor: string | AuthUser,
    providerId: string,
    permission: Permission,
  ): Promise<ProviderMembership> {
    if (typeof actor !== 'string' && hasClaim(actor, 'placesInternalOperator')) {
      return this.requireOperator(actor, providerId, permission);
    }
    const uid = typeof actor === 'string' ? actor : actor.uid;
    const list = await this.memberships(uid);
    const m = list.find((x) => x.providerId === providerId);
    if (!m) {
      throw new AppError(ErrorCodes.FORBIDDEN_PROVIDER_SCOPE, 'Not a member of this provider');
    }
    if (!can(m.role, permission)) {
      throw new AppError(ErrorCodes.FORBIDDEN_PROVIDER_SCOPE, `Role ${m.role} lacks ${permission}`);
    }
    return m;
  }

  private async requireOperator(
    user: AuthUser,
    providerId: string,
    permission: Permission,
  ): Promise<ProviderMembership> {
    const bound = user.onBehalfOfProviderId;
    if (!bound || bound !== providerId) {
      throw new AppError(
        ErrorCodes.FORBIDDEN_PROVIDER_SCOPE,
        'Operator not bound to this provider',
      );
    }
    if (!OPERATOR_PERMS.has(permission)) {
      throw new AppError(
        ErrorCodes.FORBIDDEN_PROVIDER_SCOPE,
        `Operator lacks ${permission}`,
      );
    }
    const prov = await this.pg.query<{ status: string }>(
      `SELECT status FROM providers WHERE id = $1`,
      [providerId],
    );
    if (!prov.rowCount || prov.rows[0].status !== 'active') {
      throw new AppError(
        ErrorCodes.FORBIDDEN_PROVIDER_SCOPE,
        'Bound provider not active',
      );
    }
    return {
      providerId,
      role: 'owner',
      onBehalfOfProviderId: bound,
      actorRole: 'placesInternalOperator',
    };
  }

  async requireAny(uid: string, permission: Permission): Promise<ProviderMembership> {
    const list = await this.memberships(uid);
    const m = list.find((x) => can(x.role, permission));
    if (!m) {
      throw new AppError(ErrorCodes.FORBIDDEN_PROVIDER_SCOPE, 'No provider permission');
    }
    return m;
  }
}
