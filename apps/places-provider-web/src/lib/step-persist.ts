import type { PersistedStepMap, PrepareStepId } from "@/lib/prepare-path";

const PREFIX = "places.prepare.steps.v1:";

export function loadPersistedSteps(venueId: string): PersistedStepMap {
  if (typeof window === "undefined") return {};
  try {
    const raw = window.localStorage.getItem(PREFIX + venueId);
    if (!raw) return {};
    const parsed = JSON.parse(raw) as PersistedStepMap;
    return parsed && typeof parsed === "object" ? parsed : {};
  } catch {
    return {};
  }
}

export function markStepVisited(
  venueId: string,
  step: PrepareStepId,
): PersistedStepMap {
  const next = { ...loadPersistedSteps(venueId), [step]: true };
  try {
    window.localStorage.setItem(PREFIX + venueId, JSON.stringify(next));
  } catch {
    // private mode — keep in-memory only
  }
  return next;
}
