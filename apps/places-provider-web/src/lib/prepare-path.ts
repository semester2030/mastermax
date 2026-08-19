/**
 * Venue prepare path — UI-only. Completion is derived from Core reads
 * plus locally persisted step visits. Does not invent Core rules.
 */

export const PREPARE_STEPS = [
  "basics",
  "media",
  "availability",
  "review",
] as const;

export type PrepareStepId = (typeof PREPARE_STEPS)[number];

export type PrepareStepDef = {
  id: PrepareStepId;
  titleAr: string;
  hrefSuffix: string;
};

export const PREPARE_STEP_DEFS: readonly PrepareStepDef[] = [
  { id: "basics", titleAr: "بيانات المكان", hrefSuffix: "" },
  { id: "media", titleAr: "الصور والفيديو", hrefSuffix: "/media" },
  { id: "availability", titleAr: "الإتاحة والسعر", hrefSuffix: "/availability" },
  { id: "review", titleAr: "المراجعة والنشر", hrefSuffix: "#review" },
];

export const VENUE_STATUS_LABEL_AR: Record<string, string> = {
  draft: "مسودة",
  published: "منشور",
  suspended: "موقوف",
};

export type PrepareEvidence = {
  hasName: boolean;
  hasCity: boolean;
  hasDistrict: boolean;
  hasStreet: boolean;
  imageCount: number;
  approvedVenueImages: number | null;
  hasCover: boolean;
  hasVenueVideo: boolean;
  videoCount: number;
  unitCount: number;
  allActiveUnitsHaveMedia: boolean;
  ratePlanCount: number;
  availabilityMarked: boolean;
  hasBasePrice: boolean;
  status: string;
  contentOnly: boolean;
};

export type GapItem = {
  step: PrepareStepId;
  labelAr: string;
  hrefSuffix: string;
  blocksPublish: boolean;
};

export type StepState = {
  id: PrepareStepId;
  titleAr: string;
  hrefSuffix: string;
  complete: boolean;
  visited: boolean;
};

export type PrepareSnapshot = {
  steps: StepState[];
  percent: number;
  nextStep: StepState | null;
  gaps: GapItem[];
  canPublish: boolean;
  status: string;
  statusLabelAr: string;
};

export type PersistedStepMap = Partial<Record<PrepareStepId, boolean>>;

export function venueHref(venueId: string, suffix: string): string {
  if (suffix.startsWith("#")) return `/venues/${venueId}${suffix}`;
  return `/venues/${venueId}${suffix}`;
}

export function isStepComplete(
  id: PrepareStepId,
  evidence: PrepareEvidence,
): boolean {
  switch (id) {
    case "basics":
      return evidence.hasName && evidence.hasCity && evidence.hasDistrict && evidence.hasStreet;
    case "media":
      return (
        evidence.hasCover &&
        evidence.hasVenueVideo &&
        (evidence.contentOnly ||
          evidence.unitCount === 0 ||
          evidence.allActiveUnitsHaveMedia)
      );
    case "availability":
      if (evidence.contentOnly) return true;
      return (
        evidence.unitCount > 0 &&
        evidence.hasBasePrice &&
        evidence.availabilityMarked
      );
    case "review":
      return evidence.status === "published";
  }
}

export function collectGaps(evidence: PrepareEvidence): GapItem[] {
  const gaps: GapItem[] = [];
  if (!evidence.hasName) {
    gaps.push({
      step: "basics",
      labelAr: "اسم المكان",
      hrefSuffix: "",
      blocksPublish: true,
    });
  }
  if (!evidence.hasCity) {
    gaps.push({
      step: "basics",
      labelAr: "المدينة",
      hrefSuffix: "",
      blocksPublish: true,
    });
  }
  if (!evidence.hasDistrict) {
    gaps.push({
      step: "basics",
      labelAr: "الحي",
      hrefSuffix: "",
      blocksPublish: true,
    });
  }
  if (!evidence.hasStreet) {
    gaps.push({
      step: "basics",
      labelAr: "الشارع",
      hrefSuffix: "",
      blocksPublish: true,
    });
  }
  if (!evidence.hasVenueVideo) {
    gaps.push({
      step: "media",
      labelAr: "فيديو رئيسي معتمد",
      hrefSuffix: "/media",
      blocksPublish: true,
    });
  }
  if (evidence.approvedVenueImages === 0 || !evidence.hasCover) {
    gaps.push({
      step: "media",
      labelAr: "صورة غلاف معتمدة على مستوى المكان",
      hrefSuffix: "/media",
      blocksPublish: true,
    });
  }
  if (!evidence.contentOnly && evidence.unitCount > 0 && !evidence.allActiveUnitsHaveMedia) {
    gaps.push({
      step: "media",
      labelAr: "فيديو وصورة معتمدان لكل وحدة نشطة",
      hrefSuffix: "/media",
      blocksPublish: true,
    });
  }
  if (!evidence.contentOnly && evidence.unitCount === 0) {
    gaps.push({
      step: "availability",
      labelAr: "وحدة واحدة على الأقل",
      hrefSuffix: "/units",
      blocksPublish: true,
    });
  }
  if (!evidence.contentOnly && !evidence.hasBasePrice) {
    gaps.push({
      step: "availability",
      labelAr: "السعر الأساسي",
      hrefSuffix: "/availability",
      blocksPublish: true,
    });
  }
  if (!evidence.contentOnly && !evidence.availabilityMarked) {
    gaps.push({
      step: "availability",
      labelAr: "تحديد الإتاحة (يوم أو نطاق أيام)",
      hrefSuffix: "/availability",
      blocksPublish: false,
    });
  }
  return gaps;
}

export function buildPrepareSnapshot(
  evidence: PrepareEvidence,
  persisted: PersistedStepMap = {},
): PrepareSnapshot {
  const steps: StepState[] = PREPARE_STEP_DEFS.map((def) => ({
    ...def,
    complete: isStepComplete(def.id, evidence),
    visited: persisted[def.id] === true,
  }));
  const done = steps.filter((s) => s.complete).length;
  const percent = Math.round((done / steps.length) * 100);
  const nextStep = steps.find((s) => !s.complete) ?? null;
  const blocking = collectGaps(evidence).filter((g) => g.blocksPublish);
  return {
    steps,
    percent,
    nextStep,
    gaps: collectGaps(evidence),
    canPublish: blocking.length === 0,
    status: evidence.status,
    statusLabelAr: VENUE_STATUS_LABEL_AR[evidence.status] ?? "مسودة",
  };
}

export function nextStepHref(venueId: string, snapshot: PrepareSnapshot): string {
  if (!snapshot.nextStep) return venueHref(venueId, "#review");
  return venueHref(venueId, snapshot.nextStep.hrefSuffix);
}
