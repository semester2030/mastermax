/**
 * Gate 7B.4 — Diversity applicability (pure, no SQL).
 * Mixed feed only: surface=feed ∧ no category ∧ sort ∈ {best, newest}.
 */
import {
  DIVERSITY_K_DEFAULT,
  DIVERSITY_VERSION_CURRENT,
  DiversityCursorMode,
} from './discovery-cursor-v2';
import { DiscoverySurface, normalizeSurface } from './discovery-surface';

export interface DiversityPolicy {
  /** True when Mixed Feed Diversity mutates page ordering. */
  applied: boolean;
  mode: DiversityCursorMode;
  /** Values hashed into queryHash (1/2 when applied; 0/0 otherwise). */
  version: number;
  k: number;
}

export interface DiversityPolicyInput {
  surface?: string;
  category?: string | null;
  sort?: string | null;
}

/**
 * Resolve Diversity policy AFTER applyDiscoveryDefaults (effective sort/q/surface).
 * Diversity state never enters queryHash — only version + K.
 */
export function resolveDiversityPolicy(input: DiversityPolicyInput): DiversityPolicy {
  const surface: DiscoverySurface = normalizeSurface(input.surface);
  const sort = input.sort ?? 'best';
  const category =
    typeof input.category === 'string' && input.category.trim() !== ''
      ? input.category.trim()
      : null;
  const applied =
    surface === 'feed' && category == null && (sort === 'best' || sort === 'newest');
  if (applied) {
    return {
      applied: true,
      mode: 'required',
      version: DIVERSITY_VERSION_CURRENT,
      k: DIVERSITY_K_DEFAULT,
    };
  }
  return { applied: false, mode: 'forbidden', version: 0, k: 0 };
}

/** Canonical Same-Type rail = documented request template (not a new endpoint). */
export function resolveAppliedProfile(input: {
  surface?: string;
  sort?: string | null;
  sameTypeOnly?: boolean;
}): 'same_type_near_place' | null {
  const surface = normalizeSurface(input.surface);
  if (surface === 'circle' && input.sort === 'near_place' && input.sameTypeOnly === true) {
    return 'same_type_near_place';
  }
  return null;
}

export function diversityAppliedMeta(policy: DiversityPolicy): {
  applied: boolean;
  version: number;
  k: number;
} {
  return {
    applied: policy.applied,
    version: policy.applied ? DIVERSITY_VERSION_CURRENT : 0,
    k: policy.applied ? DIVERSITY_K_DEFAULT : 0,
  };
}
