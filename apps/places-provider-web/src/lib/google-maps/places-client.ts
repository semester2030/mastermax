import { PLACES_SEARCH_CONSTRAINTS } from "@/lib/location/venue-location";

export type PlaceSuggestion = {
  id: string;
  label: string;
  placeId: string;
  prediction: unknown;
};

export type ResolvedPlace = {
  googlePlaceId: string | null;
  formattedAddress: string;
  lat: number;
  lng: number;
  city: string | null;
  district: string | null;
  street: string | null;
};

type LatLngLike = { lat: () => number; lng: () => number } | { lat: number; lng: number };

type PlaceLike = {
  id?: string;
  formattedAddress?: string;
  displayName?: string | { text?: string };
  location?: LatLngLike;
  addressComponents?: Array<{ longText?: string; types?: string[] }>;
  fetchFields: (opts: { fields: string[] }) => Promise<void>;
};

type PredictionLike = {
  placeId?: string;
  text?: { text?: string };
  mainText?: { text?: string };
  toPlace?: () => PlaceLike;
};

function readLatLng(value: LatLngLike | undefined): { lat: number; lng: number } | null {
  if (!value) return null;
  if (typeof (value as { lat?: unknown }).lat === "function") {
    const pair = value as { lat: () => number; lng: () => number };
    return { lat: pair.lat(), lng: pair.lng() };
  }
  const literal = value as { lat: number; lng: number };
  if (typeof literal.lat === "number" && typeof literal.lng === "number") {
    return literal;
  }
  return null;
}

function displayNameOf(place: PlaceLike): string {
  const name = place.displayName;
  if (typeof name === "string") return name;
  return name?.text ?? "";
}

function componentOf(place: PlaceLike, ...types: string[]): string | null {
  const found = place.addressComponents?.find((c) =>
    (c.types ?? []).some((t) => types.includes(t)),
  );
  return found?.longText ?? null;
}

export async function fetchSaudiPlaceSuggestions(
  query: string,
  sessionToken: unknown,
): Promise<PlaceSuggestion[]> {
  const trimmed = query.trim();
  if (trimmed.length < 2) return [];
  const maps = (
    window as unknown as {
      google?: {
        maps?: {
          importLibrary?: (name: string) => Promise<Record<string, unknown>>;
        };
      };
    }
  ).google?.maps;
  if (!maps?.importLibrary) throw new Error("maps_unavailable");
  const lib = await maps.importLibrary("places");
  const AutocompleteSuggestion = lib.AutocompleteSuggestion as {
    fetchAutocompleteSuggestions: (req: Record<string, unknown>) => Promise<{
      suggestions?: Array<{ placePrediction?: PredictionLike }>;
    }>;
  };
  if (!AutocompleteSuggestion?.fetchAutocompleteSuggestions) {
    throw new Error("places_new_unavailable");
  }
  const { suggestions } = await AutocompleteSuggestion.fetchAutocompleteSuggestions({
    input: trimmed,
    sessionToken,
    includedRegionCodes: [...PLACES_SEARCH_CONSTRAINTS.includedRegionCodes],
    language: PLACES_SEARCH_CONSTRAINTS.language,
    region: PLACES_SEARCH_CONSTRAINTS.region,
  });
  return (suggestions ?? [])
    .map((row, index) => {
      const pred = row.placePrediction;
      const label = pred?.text?.text ?? pred?.mainText?.text ?? "";
      const placeId = pred?.placeId ?? `${index}`;
      return { id: placeId, placeId, label, prediction: pred };
    })
    .filter((row) => row.label.length > 0);
}

export async function resolveSaudiPlace(
  prediction: PredictionLike | string,
  sessionToken: unknown,
): Promise<ResolvedPlace> {
  const maps = (
    window as unknown as {
      google?: {
        maps?: {
          importLibrary?: (name: string) => Promise<Record<string, unknown>>;
        };
      };
    }
  ).google?.maps;
  if (!maps?.importLibrary) throw new Error("maps_unavailable");
  const lib = await maps.importLibrary("places");
  let place: PlaceLike;
  if (typeof prediction === "string") {
    const Place = lib.Place as new (opts: { id: string }) => PlaceLike;
    place = new Place({ id: prediction });
  } else if (prediction.toPlace) {
    place = prediction.toPlace();
  } else {
    const Place = lib.Place as new (opts: { id: string }) => PlaceLike;
    place = new Place({ id: prediction.placeId ?? "" });
  }
  await place.fetchFields({
    fields: ["id", "displayName", "formattedAddress", "location", "addressComponents"],
  });
  void sessionToken;
  const coords = readLatLng(place.location);
  if (!coords) throw new Error("place_missing_location");
  return {
    googlePlaceId: place.id ?? null,
    formattedAddress: place.formattedAddress?.trim() || displayNameOf(place),
    lat: coords.lat,
    lng: coords.lng,
    city: componentOf(place, "locality", "administrative_area_level_1"),
    district: componentOf(place, "sublocality", "sublocality_level_1", "neighborhood"),
    street: componentOf(place, "route", "street_address"),
  };
}

export async function createPlacesSessionToken(): Promise<unknown> {
  const maps = (
    window as unknown as {
      google?: {
        maps?: {
          importLibrary?: (name: string) => Promise<Record<string, unknown>>;
        };
      };
    }
  ).google?.maps;
  if (!maps?.importLibrary) return null;
  const lib = await maps.importLibrary("places");
  const Token = lib.AutocompleteSessionToken as new () => unknown;
  return new Token();
}
