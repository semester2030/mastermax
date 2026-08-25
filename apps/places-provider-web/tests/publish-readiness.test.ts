import assert from "node:assert/strict";
import test from "node:test";
import {
  canPublish,
  canPublishFromEvidence,
  countApprovedVenueImages,
  describeVenuePublishError,
  hasApprovedVenueCover,
  hasApprovedVenueVideo,
  PUBLISH_REQUIRES_IMAGE_AR,
  unitHasApprovedImageAndVideo,
  type PublishUiEvidence,
} from "../src/lib/core/publish-readiness.ts";
import type { MediaRow } from "../src/lib/core/types.ts";

const approvedVideo: MediaRow = {
  id: "v1",
  kind: "video",
  moderationStatus: "approved",
  inventoryTypeId: null,
};

const pendingVenueImage: MediaRow = {
  id: "i1",
  kind: "image",
  moderationStatus: "pending",
  inventoryTypeId: null,
};

const approvedVenueCover: MediaRow = {
  id: "i2",
  kind: "image",
  moderationStatus: "approved",
  inventoryTypeId: null,
  isCover: true,
};

const approvedUnitImage: MediaRow = {
  id: "i3",
  kind: "image",
  moderationStatus: "approved",
  inventoryTypeId: "unit-1",
};

const approvedUnitVideo: MediaRow = {
  id: "v2",
  kind: "video",
  moderationStatus: "approved",
  inventoryTypeId: "unit-1",
};

function evidence(partial: Partial<PublishUiEvidence> = {}): PublishUiEvidence {
  return {
    hasCityId: true,
    hasDistrictId: true,
    hasStreet: true,
    hasCoordinates: true,
    approvedVenueImages: 1,
    hasCover: true,
    hasVenueVideo: true,
    hasPrice: true,
    hasAvailability: true,
    allActiveUnitsHaveMedia: true,
    ...partial,
  };
}

test("approved video and pending image do not count as an approved venue image", () => {
  const media = [approvedVideo, pendingVenueImage];
  assert.equal(countApprovedVenueImages(media), 0);
  assert.equal(hasApprovedVenueCover(media), false);
  assert.equal(hasApprovedVenueVideo(media), true);
  assert.equal(canPublish(countApprovedVenueImages(media)), false);
});

test("cover + venue video + location + unit media unlock publish", () => {
  const media = [
    approvedVideo,
    pendingVenueImage,
    approvedVenueCover,
    approvedUnitImage,
    approvedUnitVideo,
  ];
  assert.equal(countApprovedVenueImages(media), 1);
  assert.equal(hasApprovedVenueCover(media), true);
  assert.equal(unitHasApprovedImageAndVideo(media, "unit-1"), true);
  assert.equal(canPublishFromEvidence(evidence()), true);
});

test("approved unit-level image never unlocks venue cover", () => {
  assert.equal(countApprovedVenueImages([approvedUnitImage]), 0);
  assert.equal(hasApprovedVenueCover([approvedUnitImage]), false);
  assert.equal(canPublishFromEvidence(evidence({ hasCover: false })), false);
});

test("snake_case rows from Core are counted the same", () => {
  const media: MediaRow[] = [
    { id: "s1", kind: "image", moderation_status: "approved", inventory_type_id: null, is_cover: true },
    { id: "s2", kind: "image", moderation_status: "approved", inventory_type_id: "u" },
  ];
  assert.equal(countApprovedVenueImages(media), 1);
  assert.equal(hasApprovedVenueCover(media), true);
});

test("unknown media count leaves publish to Core instead of guessing", () => {
  assert.equal(canPublish(null), true);
  assert.equal(
    canPublishFromEvidence(evidence({ approvedVenueImages: null })),
    true,
  );
});

test("Core publish rejection is explained in Arabic", () => {
  const message = describeVenuePublishError({
    code: "VALIDATION_ERROR",
    message: "Publish requires cityId, districtId, and street",
  });
  assert.ok(message);
  assert.ok(message.includes(PUBLISH_REQUIRES_IMAGE_AR));
});

test("physical type without an active unit is explained in Arabic", () => {
  const message = describeVenuePublishError({
    code: "VALIDATION_ERROR",
    message: "Publish requires an active independent unit on each physical type",
    details: { reason: "physical_unit_required_for_publish" },
  });
  assert.equal(
    message,
    "تعذّر النشر — الوحدات المستقلة تحتاج اسم وحدة نشطة واحدة على الأقل.",
  );
});

test("missing coordinates block publish", () => {
  assert.equal(canPublishFromEvidence(evidence({ hasCoordinates: false })), false);
});

test("Core publish rejection for coordinates is explained in Arabic", () => {
  const message = describeVenuePublishError({
    code: "VALIDATION_ERROR",
    message: "Publish requires valid latitude and longitude",
    details: { reason: "location_coordinates_required_for_publish" },
  });
  assert.ok(message);
  assert.ok(message.includes(PUBLISH_REQUIRES_IMAGE_AR));
});

test("unrelated validation errors keep their original message", () => {
  assert.equal(
    describeVenuePublishError({
      code: "VALIDATION_ERROR",
      message: "venueId required",
    }),
    null,
  );
  assert.equal(describeVenuePublishError({ code: "NOT_FOUND" }), null);
  assert.equal(describeVenuePublishError(null), null);
});
