import assert from "node:assert/strict";
import test from "node:test";
import {
  buildPrepareSnapshot,
  collectGaps,
  isStepComplete,
  nextStepHref,
  type PrepareEvidence,
} from "../src/lib/prepare-path.ts";
import { eachIsoDate, isIsoDate, monthGrid } from "../src/lib/calendar-range.ts";
import { operatorErrorAr } from "../src/lib/operator-errors.ts";

function evidence(partial: Partial<PrepareEvidence> = {}): PrepareEvidence {
  return {
    hasName: false,
    hasCity: false,
    hasDistrict: false,
    hasStreet: false,
    imageCount: 0,
    approvedVenueImages: 0,
    hasCover: false,
    hasVenueVideo: false,
    videoCount: 0,
    unitCount: 0,
    allActiveUnitsHaveMedia: true,
    ratePlanCount: 0,
    availabilityMarked: false,
    hasBasePrice: false,
    status: "draft",
    contentOnly: false,
    ...partial,
  };
}

test("empty venue starts at basics and blocks publish", () => {
  const snap = buildPrepareSnapshot(evidence());
  assert.equal(snap.percent, 0);
  assert.equal(snap.nextStep?.id, "basics");
  assert.equal(snap.canPublish, false);
  const labels = snap.gaps.map((g) => g.labelAr);
  assert.ok(labels.includes("اسم المكان"));
  assert.ok(labels.includes("المدينة"));
  assert.ok(labels.includes("الحي"));
  assert.ok(labels.includes("الشارع"));
  assert.ok(labels.includes("فيديو رئيسي معتمد"));
  assert.ok(labels.includes("صورة غلاف معتمدة على مستوى المكان"));
  assert.equal(
    labels.some((l) => /inventory|rate plan|moderation|uuid/i.test(l)),
    false,
  );
});

test("venue → media → availability → review path", () => {
  const afterBasics = evidence({
    hasName: true,
    hasCity: true,
    hasDistrict: true,
    hasStreet: true,
  });
  assert.equal(isStepComplete("basics", afterBasics), true);
  assert.equal(buildPrepareSnapshot(afterBasics).nextStep?.id, "media");

  const afterMedia = evidence({
    hasName: true,
    hasCity: true,
    hasDistrict: true,
    hasStreet: true,
    imageCount: 2,
    approvedVenueImages: 1,
    hasCover: true,
    hasVenueVideo: true,
    allActiveUnitsHaveMedia: true,
  });
  assert.equal(isStepComplete("media", afterMedia), true);
  assert.equal(buildPrepareSnapshot(afterMedia).nextStep?.id, "availability");

  const afterAvail = evidence({
    hasName: true,
    hasCity: true,
    hasDistrict: true,
    hasStreet: true,
    imageCount: 2,
    approvedVenueImages: 1,
    hasCover: true,
    hasVenueVideo: true,
    allActiveUnitsHaveMedia: true,
    unitCount: 1,
    ratePlanCount: 1,
    hasBasePrice: true,
    availabilityMarked: true,
  });
  const ready = buildPrepareSnapshot(afterAvail);
  assert.equal(isStepComplete("availability", afterAvail), true);
  assert.equal(ready.nextStep?.id, "review");
  assert.equal(ready.canPublish, true);
  assert.equal(ready.percent, 75);
  assert.equal(nextStepHref("venue-1", ready), "/venues/venue-1#review");

  const published = buildPrepareSnapshot({
    ...afterAvail,
    status: "published",
  });
  assert.equal(published.percent, 100);
  assert.equal(published.nextStep, null);
  assert.equal(published.statusLabelAr, "منشور");
});

test("review lists Arabic blockers before publish", () => {
  const gaps = collectGaps(
    evidence({
      hasName: true,
      hasCity: true,
      hasDistrict: true,
      hasStreet: true,
      imageCount: 1,
      approvedVenueImages: 0,
      hasCover: false,
      hasVenueVideo: true,
      unitCount: 1,
      allActiveUnitsHaveMedia: true,
      hasBasePrice: false,
    }),
  );
  const labels = gaps.map((g) => g.labelAr);
  assert.ok(labels.includes("صورة غلاف معتمدة على مستوى المكان"));
  assert.ok(labels.includes("السعر الأساسي"));
  assert.ok(gaps.some((g) => g.labelAr === "صورة غلاف معتمدة على مستوى المكان" && g.blocksPublish));
});

test("content-only venues skip availability", () => {
  const snap = buildPrepareSnapshot(
    evidence({
      hasName: true,
      hasCity: true,
      hasDistrict: true,
      hasStreet: true,
      imageCount: 1,
      approvedVenueImages: 1,
      hasCover: true,
      hasVenueVideo: true,
      contentOnly: true,
    }),
  );
  assert.equal(snap.steps.find((s) => s.id === "availability")?.complete, true);
  assert.equal(snap.nextStep?.id, "review");
});

test("persisted visit does not mark a step complete", () => {
  const snap = buildPrepareSnapshot(evidence(), {
    basics: true,
    media: true,
    availability: true,
    review: true,
  });
  assert.equal(snap.percent, 0);
  assert.equal(snap.steps.every((s) => s.visited), true);
  assert.equal(snap.steps.every((s) => !s.complete), true);
});

test("calendar range expands inclusive days and rejects invalid", () => {
  assert.deepEqual(eachIsoDate("2026-08-18", "2026-08-20"), [
    "2026-08-18",
    "2026-08-19",
    "2026-08-20",
  ]);
  assert.deepEqual(eachIsoDate("2026-08-20", "2026-08-18"), []);
  assert.equal(isIsoDate("2026-02-30"), false);
  assert.equal(monthGrid(2026, 7).filter(Boolean).length, 31);
});

test("operator errors never leak JSON, IDs, or technical codes", () => {
  const raw = operatorErrorAr(
    'VALIDATION_ERROR {"code":"X","id":"11111111-1111-4111-8111-111111111111"} HTTP 500 /v1/provider/venues',
  );
  assert.equal(raw.includes("{"), false);
  assert.equal(raw.includes("11111111"), false);
  assert.equal(raw.includes("/v1/"), false);
  assert.equal(raw.includes("HTTP"), false);
  assert.match(raw, /ناقصة|غير صحيحة|أعد المحاولة/);

  assert.equal(
    operatorErrorAr("Publish requires at least one approved venue-level image"),
    "يلزم مدينة وحي وشارع، وفيديو رئيسي معتمد، وصورة غلاف، وسعر وإتاحة، ووسائط معتمدة لكل وحدة نشطة.",
  );
  assert.equal(operatorErrorAr("Missing onBehalfOfProviderId claim").includes("onBehalf"), false);
});
