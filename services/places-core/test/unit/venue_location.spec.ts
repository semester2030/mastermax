import {
  composeFormattedAddress,
  isValidLatitude,
  isValidLongitude,
  isValidLatLng,
  projectVenueLocation,
  venueHasPublishableCoordinates,
} from "../../src/modules/venues/application/venue-location";

describe("venue location contract", () => {
  it("accepts only in-range coordinates", () => {
    expect(isValidLatitude(24.7136)).toBe(true);
    expect(isValidLongitude(46.6753)).toBe(true);
    expect(isValidLatLng(24.7136, 46.6753)).toBe(true);
    expect(isValidLatitude(90)).toBe(true);
    expect(isValidLatitude(-90)).toBe(true);
    expect(isValidLongitude(180)).toBe(true);
    expect(isValidLongitude(-180)).toBe(true);
    expect(isValidLatitude(91)).toBe(false);
    expect(isValidLatitude(-91)).toBe(false);
    expect(isValidLongitude(181)).toBe(false);
    expect(isValidLongitude(-181)).toBe(false);
    expect(isValidLatitude(Number.NaN)).toBe(false);
    expect(isValidLongitude(Number.POSITIVE_INFINITY)).toBe(false);
    expect(isValidLatLng(24.7, null)).toBe(false);
    expect(isValidLatLng(undefined, 46.6)).toBe(false);
  });

  it("prefers stored formatted address and otherwise joins Arabic parts", () => {
    expect(
      composeFormattedAddress({
        formattedAddress: " طريق الملك فهد، العليا، الرياض ",
        street: "ignored",
        city: "ignored",
      }),
    ).toBe("طريق الملك فهد، العليا، الرياض");
    expect(
      composeFormattedAddress({
        street: "طريق الملك فهد",
        district: "العليا",
        city: "الرياض",
      }),
    ).toBe("طريق الملك فهد، العليا، الرياض");
    expect(composeFormattedAddress({})).toBeNull();
  });

  it("does not invent coordinates for legacy rows", () => {
    const projected = projectVenueLocation({
      city: "الرياض",
      district: "العليا",
      street: "طريق الملك فهد",
      lat: null,
      lng: null,
    });
    expect(projected.lat).toBeNull();
    expect(projected.lng).toBeNull();
    expect(projected.latitude).toBeNull();
    expect(projected.longitude).toBeNull();
    expect(projected.locationComplete).toBe(false);
    expect(projected.formattedAddress).toBe("طريق الملك فهد، العليا، الرياض");
    expect(venueHasPublishableCoordinates(projected)).toBe(false);
  });

  it("exposes latitude/longitude aliases from the same Core columns", () => {
    const projected = projectVenueLocation({
      lat: "24.7136",
      lng: "46.6753",
      google_place_id: "ChIJtest",
      formatted_address: "الرياض",
      location_source: "search",
    });
    expect(projected.lat).toBe(24.7136);
    expect(projected.lng).toBe(46.6753);
    expect(projected.latitude).toBe(24.7136);
    expect(projected.longitude).toBe(46.6753);
    expect(projected.googlePlaceId).toBe("ChIJtest");
    expect(projected.locationSource).toBe("search");
    expect(projected.locationComplete).toBe(true);
    expect(venueHasPublishableCoordinates(projected)).toBe(true);
    expect(venueHasPublishableCoordinates({ latitude: 24.7, longitude: 46.6 })).toBe(
      true,
    );
  });

  it("blocks publish when coordinates are missing or out of range", () => {
    expect(venueHasPublishableCoordinates({})).toBe(false);
    expect(venueHasPublishableCoordinates({ lat: 24.7 })).toBe(false);
    expect(venueHasPublishableCoordinates({ lat: 91, lng: 46 })).toBe(false);
    expect(venueHasPublishableCoordinates({ lat: 24.7, lng: 181 })).toBe(false);
  });
});
