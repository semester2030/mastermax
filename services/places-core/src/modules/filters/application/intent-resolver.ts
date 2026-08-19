import { PgService } from '../../../shared/database/pg.service';
import { AppError } from '../../../shared/errors/app-error';
import { ErrorCodes } from '../../../shared/errors/error-codes';
import { DiscoverySearchDto } from '../../../shared/api/dto/discovery-search.dto';

export interface IntentResolution {
  dto: DiscoverySearchDto;
  appliedIntent: string | null;
  intentNotes: string[];
  scopedVenueTypes: string[] | null;
  appliedConstraints: Record<string, unknown>;
}

/**
 * Explicit user filters always win. Intent never silently mutates conflicting fields.
 * applicable_venue_types enforced (Gate 7A.2).
 */
export async function resolveIntent(
  pg: PgService,
  raw: DiscoverySearchDto,
): Promise<IntentResolution> {
  if (!raw.intent) {
    return {
      dto: { ...raw },
      appliedIntent: null,
      intentNotes: [],
      scopedVenueTypes: null,
      appliedConstraints: {},
    };
  }
  const res = await pg.query<{
    expands_to_jsonb: Record<string, unknown>;
    status: string;
    applicable_venue_types: string[];
  }>(`SELECT expands_to_jsonb, status, applicable_venue_types FROM intent_presets WHERE code = $1`, [
    raw.intent,
  ]);
  if (!res.rowCount || res.rows[0].status !== 'active') {
    throw new AppError(
      ErrorCodes.VALIDATION_ERROR,
      `Unknown or inactive intent: ${raw.intent}`,
      { conflictReason: 'intent_inactive_or_unknown' },
    );
  }
  const applicable = res.rows[0].applicable_venue_types ?? ['*'];
  const isWildcard = applicable.includes('*');
  if (raw.category && !isWildcard && !applicable.includes(raw.category)) {
    throw new AppError(
      ErrorCodes.VALIDATION_ERROR,
      `Intent ${raw.intent} not applicable to category ${raw.category}`,
      { conflictReason: 'intent_category_mismatch', applicableVenueTypes: applicable },
    );
  }
  // Without category: either scope candidates to applicable types, or reject non-wildcard
  let scopedVenueTypes: string[] | null = null;
  if (!raw.category && !isWildcard) {
    scopedVenueTypes = applicable;
  }

  const exp = res.rows[0].expands_to_jsonb ?? {};
  const notes: string[] = [];
  const appliedConstraints: Record<string, unknown> = {};
  const out: DiscoverySearchDto = { ...raw };

  if (exp.pricePercentile != null || exp.nightsMin != null || exp.intentHint != null) {
    throw new AppError(
      ErrorCodes.VALIDATION_ERROR,
      `Intent ${raw.intent} expands to unimplemented fields (deferred)`,
      { conflictReason: 'intent_unimplemented_expansion' },
    );
  }

  const amenities = [
    ...new Set([...(raw.amenities ?? []), ...((exp.amenities as string[]) ?? [])]),
  ].sort((a, b) => a.localeCompare(b));
  out.amenities = amenities;
  if ((exp.amenities as string[] | undefined)?.length) {
    appliedConstraints.amenitiesUnion = amenities;
    notes.push('amenities union applied');
  }

  if (exp.guestsMin != null) {
    const gmin = Number(exp.guestsMin);
    if (raw.guests != null && raw.guests < gmin) {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        `Intent ${raw.intent} requires guests >= ${gmin}; explicit guests=${raw.guests} conflicts`,
        { conflictReason: 'guests_min_conflict' },
      );
    }
    if (raw.guests == null) {
      out.guests = gmin;
      appliedConstraints.guestsMin = gmin;
      notes.push(`applied guestsMin=${gmin}`);
    } else {
      notes.push('skipped guestsMin; explicit guests wins');
      appliedConstraints.guestsExplicit = raw.guests;
    }
  }

  if (exp.guestsMax != null) {
    const gmax = Number(exp.guestsMax);
    if (raw.guests != null && raw.guests > gmax) {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        `Intent ${raw.intent} requires guests <= ${gmax}; explicit guests=${raw.guests} conflicts`,
        { conflictReason: 'guests_max_conflict' },
      );
    }
    notes.push('guestsMax checked without silent overwrite');
  }

  if (exp.starsMin != null) {
    const smin = Number(exp.starsMin);
    if (raw.starsMin != null && raw.starsMin < smin) {
      throw new AppError(
        ErrorCodes.VALIDATION_ERROR,
        `Intent ${raw.intent} requires starsMin >= ${smin}; explicit starsMin=${raw.starsMin} conflicts`,
        { conflictReason: 'stars_min_conflict' },
      );
    }
    if (raw.starsMin == null) {
      out.starsMin = smin;
      appliedConstraints.starsMin = smin;
      notes.push(`applied starsMin=${smin}`);
    } else {
      notes.push('skipped starsMin; explicit starsMin wins');
    }
  }

  if (scopedVenueTypes) {
    appliedConstraints.scopedVenueTypes = scopedVenueTypes;
    notes.push(`scoped venue types: ${scopedVenueTypes.join(',')}`);
  }

  return {
    dto: out,
    appliedIntent: raw.intent,
    intentNotes: notes,
    scopedVenueTypes,
    appliedConstraints,
  };
}
