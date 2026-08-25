"use client";

import { useEffect, useMemo, useRef, useState, useTransition } from "react";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Input, Label, Select } from "@/components/ui/field";
import { ErrorState } from "@/components/ui/error-state";
import {
  geocodeManualAddressAction,
  loadDistrictsAction,
  patchVenueLocationAction,
  reverseGeocodeAction,
} from "@/lib/core/actions";
import type { LocationCity, LocationDistrict } from "@/lib/core/types";
import {
  attachDraggableMapPin,
  type MapPinHandle,
} from "@/lib/google-maps/map-pin";
import { bootLocationMaps } from "@/lib/google-maps/boot-maps";
import { loadGoogleMapsScript, mapsWebKey, type MapsLoadState } from "@/lib/google-maps/load-script";
import {
  createPlacesSessionToken,
  fetchSaudiPlaceSuggestions,
  resolveSaudiPlace,
  type PlaceSuggestion,
} from "@/lib/google-maps/places-client";
import {
  LOCATION_API_UNAVAILABLE_AR,
  LOCATION_GEO_DENIED_AR,
  LOCATION_GEOCODE_FAILED_AR,
  LOCATION_INCOMPLETE_AR,
  LOCATION_PIN_CONFIRM_AR,
  SAUDI_DEFAULT_CENTER,
  buildVenueLocationPatch,
  canPersistCoordinates,
  composeAddressPreview,
  matchCatalogName,
  type LocationSource,
  venueHasCoordinates,
} from "@/lib/location/venue-location";

type Props = {
  venueId: string;
  initial: {
    city?: string | null;
    cityId?: string | null;
    district?: string | null;
    districtId?: string | null;
    street?: string | null;
    formattedAddress?: string | null;
    googlePlaceId?: string | null;
    lat?: number | null;
    lng?: number | null;
    locationSource?: string | null;
    locationComplete?: boolean;
  };
  cities: LocationCity[];
  initialDistricts: LocationDistrict[];
};

export function VenueLocationForm({
  venueId,
  initial,
  cities,
  initialDistricts,
}: Props) {
  const [mapsState, setMapsState] = useState<MapsLoadState>("idle");
  const [mapsBoot, setMapsBoot] = useState(0);
  const [query, setQuery] = useState("");
  const [suggestions, setSuggestions] = useState<PlaceSuggestion[]>([]);
  const [searchError, setSearchError] = useState<string | null>(null);
  const [geoDenied, setGeoDenied] = useState(false);
  const [cityId, setCityId] = useState(initial.cityId ?? "");
  const [districtId, setDistrictId] = useState(initial.districtId ?? "");
  const [districts, setDistricts] = useState(initialDistricts);
  const [street, setStreet] = useState(initial.street ?? "");
  const [formattedAddress, setFormattedAddress] = useState(
    initial.formattedAddress ?? "",
  );
  const [googlePlaceId, setGooglePlaceId] = useState(initial.googlePlaceId ?? "");
  const [lat, setLat] = useState<number | null>(initial.lat ?? null);
  const [lng, setLng] = useState<number | null>(initial.lng ?? null);
  const [locationSource, setLocationSource] = useState<LocationSource>(
    (initial.locationSource as LocationSource) ?? "manual",
  );
  const [pinConfirmed, setPinConfirmed] = useState(
    venueHasCoordinates(initial),
  );
  const [needsPinConfirm, setNeedsPinConfirm] = useState(false);
  const [geocodeFailed, setGeocodeFailed] = useState(false);
  const [status, setStatus] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();
  const mapEl = useRef<HTMLDivElement | null>(null);
  const pinRef = useRef<MapPinHandle | null>(null);
  const sessionRef = useRef<unknown>(null);
  const searchTimer = useRef<number | null>(null);
  const initialCenter = useRef({
    lat: initial.lat ?? SAUDI_DEFAULT_CENTER.lat,
    lng: initial.lng ?? SAUDI_DEFAULT_CENTER.lng,
  });

  const cityName =
    cities.find((c) => c.id === cityId)?.nameAr ?? initial.city ?? "";
  const districtName =
    districts.find((d) => d.id === districtId)?.nameAr ?? initial.district ?? "";
  const preview = composeAddressPreview({
    street,
    district: districtName,
    city: cityName,
    formattedAddress,
  });
  const complete = venueHasCoordinates({ lat, lng });

  const mapsMessage = useMemo(() => {
    if (mapsState === "unavailable") return LOCATION_API_UNAVAILABLE_AR;
    if (mapsState === "error") return "تعذّر تحميل الخريطة. أعد المحاولة أو أكمل العنوان يدويًا.";
    return null;
  }, [mapsState]);

  useEffect(() => {
    let cancelled = false;
    async function waitForMapElement(): Promise<HTMLElement> {
      const started = Date.now();
      while (!mapEl.current) {
        if (Date.now() - started > 3000) throw new Error("maps_element_missing");
        await new Promise((resolve) => window.setTimeout(resolve, 16));
      }
      return mapEl.current;
    }
    async function boot() {
      if (!mapsWebKey()) {
        setMapsState("unavailable");
        return;
      }
      setMapsState("loading");
      try {
        const el = await waitForMapElement();
        const onMove = (nextLat: number, nextLng: number) => {
          setLat(nextLat);
          setLng(nextLng);
          setLocationSource("pin");
          setPinConfirmed(true);
          setNeedsPinConfirm(false);
          setGeocodeFailed(false);
        };
        const pinOpts = {
          lat: initialCenter.current.lat,
          lng: initialCenter.current.lng,
          onMove,
        };
        const booted = await bootLocationMaps({
          loadScript: loadGoogleMapsScript,
          createSession: createPlacesSessionToken,
          attachPin: async () => {
            pinRef.current = await attachDraggableMapPin({
              element: el,
              ...pinOpts,
              useMapId: false,
            });
          },
          attachPinFallback: async () => {
            pinRef.current = await attachDraggableMapPin({
              element: el,
              ...pinOpts,
              useMapId: false,
            });
          },
        });
        if (cancelled) return;
        sessionRef.current = booted.session;
        setMapsState("ready");
      } catch {
        if (!cancelled) setMapsState(mapsWebKey() ? "error" : "unavailable");
      }
    }
    void boot();
    return () => {
      cancelled = true;
      pinRef.current?.destroy();
      pinRef.current = null;
    };
  }, [mapsBoot]);

  function applyCoords(
    nextLat: number,
    nextLng: number,
    source: LocationSource,
    confirmed: boolean,
  ) {
    setLat(nextLat);
    setLng(nextLng);
    setLocationSource(source);
    setPinConfirmed(confirmed);
    setNeedsPinConfirm(!confirmed);
    setGeocodeFailed(false);
    pinRef.current?.setPosition(nextLat, nextLng);
  }

  function applyCatalogHints(cityHint: string | null, districtHint: string | null) {
    const city = matchCatalogName(cities, cityHint);
    if (!city) return;
    setCityId(city.id);
    startTransition(async () => {
      const res = await loadDistrictsAction(city.id);
      if (!res.ok) return;
      const rows = res.districts as LocationDistrict[];
      setDistricts(rows);
      const district = matchCatalogName(rows, districtHint);
      if (district) setDistrictId(district.id);
    });
  }

  function onSearchChange(value: string) {
    setQuery(value);
    setSearchError(null);
    if (searchTimer.current) window.clearTimeout(searchTimer.current);
    if (value.trim().length < 2 || mapsState !== "ready") {
      setSuggestions([]);
      return;
    }
    searchTimer.current = window.setTimeout(() => {
      void (async () => {
        try {
          if (!sessionRef.current) {
            sessionRef.current = await createPlacesSessionToken();
          }
          const rows = await fetchSaudiPlaceSuggestions(value, sessionRef.current);
          setSuggestions(rows);
        } catch {
          setSearchError("تعذّر البحث. أعد المحاولة أو أدخل العنوان يدويًا.");
          setSuggestions([]);
        }
      })();
    }, 280);
  }

  async function onSelectSuggestion(row: PlaceSuggestion) {
    try {
      const place = await resolveSaudiPlace(row.prediction ?? row.placeId, sessionRef.current);
      sessionRef.current = await createPlacesSessionToken();
      setQuery(row.label);
      setSuggestions([]);
      setFormattedAddress(place.formattedAddress);
      setGooglePlaceId(place.googlePlaceId ?? "");
      if (place.street) setStreet(place.street);
      applyCatalogHints(place.city, place.district);
      applyCoords(place.lat, place.lng, "search", true);
      setStatus("تم اختيار المكان. راجع المعاينة ثم احفظ.");
    } catch {
      setSearchError("تعذّر فتح المكان المختار. أعد المحاولة أو أدخل العنوان يدويًا.");
    }
  }

  function onCityChange(next: string) {
    setCityId(next);
    setDistrictId("");
    if (!next) {
      setDistricts([]);
      return;
    }
    startTransition(async () => {
      const res = await loadDistrictsAction(next);
      if (res.ok) setDistricts(res.districts as LocationDistrict[]);
    });
  }

  async function onUseCurrentLocation() {
    setGeoDenied(false);
    setError(null);
    if (!navigator.geolocation) {
      setGeoDenied(true);
      return;
    }
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        applyCoords(pos.coords.latitude, pos.coords.longitude, "geolocation", true);
        startTransition(async () => {
          const geo = await reverseGeocodeAction({
            lat: pos.coords.latitude,
            lng: pos.coords.longitude,
          });
          if (!geo.ok) return;
          setFormattedAddress(geo.formattedAddress);
          setGooglePlaceId(geo.googlePlaceId ?? "");
          if (geo.street) setStreet(geo.street);
          applyCatalogHints(geo.city, geo.district);
        });
      },
      () => setGeoDenied(true),
      { enableHighAccuracy: true, timeout: 12000 },
    );
  }

  async function onGeocodeManual() {
    setError(null);
    setGeocodeFailed(false);
    const geo = await geocodeManualAddressAction({
      city: cityName,
      district: districtName,
      street,
    });
    if (!geo.ok) {
      setGeocodeFailed(true);
      setPinConfirmed(false);
      setNeedsPinConfirm(false);
      setLat(null);
      setLng(null);
      setLocationSource("manual");
      return;
    }
    setFormattedAddress(geo.formattedAddress || preview);
    setGooglePlaceId(geo.googlePlaceId ?? "");
    applyCoords(geo.lat, geo.lng, "manual", false);
  }

  function onSave() {
    setError(null);
    setStatus(null);
    if (needsPinConfirm && !pinConfirmed) {
      setError(LOCATION_PIN_CONFIRM_AR);
      return;
    }
    const patch = buildVenueLocationPatch({
      cityId: cityId || null,
      districtId: districtId || null,
      city: cityName || null,
      district: districtName || null,
      street,
      formattedAddress: formattedAddress || preview,
      googlePlaceId,
      lat,
      lng,
      locationSource,
      pinConfirmed,
    });
    startTransition(async () => {
      const res = await patchVenueLocationAction(venueId, patch);
      if (!res.ok) {
        setError(res.error);
        return;
      }
      if (!canPersistCoordinates({ lat, lng, pinConfirmed })) {
        setStatus("تم حفظ المسودة. الموقع غير مكتمل ولن يُنشر للاكتشاف قبل الإحداثيات.");
        return;
      }
      setStatus("تم حفظ الموقع. أعد تحميل الصفحة للتحقق.");
    });
  }

  return (
    <div className="space-y-6">
      {!complete ? (
        <p
          className="rounded-[var(--radius-md)] border border-[var(--color-warning)]/40 bg-[color-mix(in_srgb,var(--color-warning)_12%,white)] px-3 py-2 text-sm"
          role="status"
        >
          {LOCATION_INCOMPLETE_AR}. أكمل البحث أو الدبوس أو العنوان اليدوي ثم احفظ.
        </p>
      ) : null}

      {mapsState === "error" ? (
        <ErrorState
          title="تعذّر تحميل الخريطة"
          description={mapsMessage ?? ""}
          onRetry={() => setMapsBoot((n) => n + 1)}
        />
      ) : null}
      {mapsState === "unavailable" ? (
        <p className="text-sm text-[var(--color-warning)]" role="status">
          {LOCATION_API_UNAVAILABLE_AR}
        </p>
      ) : null}
      {mapsState === "loading" ? (
        <p className="text-sm text-[var(--color-text-secondary)]" role="status">
          جارٍ تحميل الخريطة…
        </p>
      ) : null}

      <div className="space-y-2">
        <Label htmlFor="place-search">البحث باسم المكان أو العنوان</Label>
        <Input
          id="place-search"
          value={query}
          onChange={(e) => onSearchChange(e.target.value)}
          placeholder="مثال: شالية في الرياض"
          disabled={mapsState !== "ready"}
        />
        {searchError ? (
          <p className="text-sm text-[var(--color-error)]" role="alert">
            {searchError}
          </p>
        ) : null}
        {suggestions.length > 0 ? (
          <ul className="divide-y divide-[var(--color-border)] rounded-[var(--radius-md)] border border-[var(--color-border)] bg-white">
            {suggestions.map((row) => (
              <li key={row.id}>
                <button
                  type="button"
                  className="w-full px-3 py-2 text-right text-sm hover:bg-[var(--color-primary-light)]"
                  onClick={() => void onSelectSuggestion(row)}
                >
                  {row.label}
                </button>
              </li>
            ))}
          </ul>
        ) : null}
      </div>

      <div className="space-y-2">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <Label>الخريطة والدبوس</Label>
          <Button type="button" variant="secondary" size="sm" onClick={() => void onUseCurrentLocation()}>
            استخدام موقعي الحالي
          </Button>
        </div>
        {geoDenied ? (
          <p className="text-sm text-[var(--color-warning)]" role="status">
            {LOCATION_GEO_DENIED_AR}
          </p>
        ) : null}
        <div
          ref={mapEl}
          className="h-72 w-full overflow-hidden rounded-[var(--radius-md)] border border-[var(--color-border)] bg-[var(--color-primary-light)]"
          aria-label="خريطة موقع المكان"
        />
        {needsPinConfirm ? (
          <div className="flex flex-wrap items-center gap-2">
            <p className="text-sm text-[var(--color-warning)]">{LOCATION_PIN_CONFIRM_AR}</p>
            <Button
              type="button"
              variant="secondary"
              size="sm"
              onClick={() => {
                setPinConfirmed(true);
                setNeedsPinConfirm(false);
              }}
            >
              تأكيد موقع الدبوس
            </Button>
          </div>
        ) : null}
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        <div>
          <Label htmlFor="loc-city">المدينة</Label>
          <Select
            id="loc-city"
            value={cityId}
            onChange={(e) => onCityChange(e.target.value)}
          >
            <option value="">اختر المدينة</option>
            {cities.map((c) => (
              <option key={c.id} value={c.id}>
                {c.nameAr}
              </option>
            ))}
          </Select>
        </div>
        <div>
          <Label htmlFor="loc-district">الحي</Label>
          <Select
            id="loc-district"
            value={districtId}
            onChange={(e) => setDistrictId(e.target.value)}
            disabled={!cityId}
          >
            <option value="">اختر الحي</option>
            {districts.map((d) => (
              <option key={d.id} value={d.id}>
                {d.nameAr}
              </option>
            ))}
          </Select>
        </div>
        <div className="sm:col-span-2">
          <Label htmlFor="loc-street">الشارع</Label>
          <Input
            id="loc-street"
            value={street}
            onChange={(e) => setStreet(e.target.value)}
          />
        </div>
      </div>

      <div className="flex flex-wrap gap-2">
        <Button type="button" variant="outline" onClick={() => void onGeocodeManual()}>
          تحويل العنوان اليدوي إلى إحداثيات
        </Button>
      </div>
      {geocodeFailed ? (
        <p className="text-sm text-[var(--color-warning)]" role="status">
          {LOCATION_GEOCODE_FAILED_AR}
        </p>
      ) : null}

      <div className="rounded-[var(--radius-md)] border border-[var(--color-border)] bg-white/80 px-4 py-3">
        <p className="text-xs font-semibold text-[var(--color-text-secondary)]">
          معاينة العنوان قبل الحفظ
        </p>
        <p className="mt-1 text-sm">{preview || "—"}</p>
        <p className="mt-1 text-xs text-[var(--color-on-surface-muted)]" dir="ltr">
          {complete ? `${lat}, ${lng}` : "بدون إحداثيات"}
        </p>
      </div>

      {error ? (
        <p className="text-sm text-[var(--color-error)]" role="alert">
          {error}
        </p>
      ) : null}
      {status ? (
        <p className="text-sm text-[#22C063]" role="status">
          {status}
        </p>
      ) : null}

      <div className="flex flex-wrap gap-2">
        <Button type="button" onClick={onSave} disabled={pending}>
          {pending ? "جارٍ الحفظ…" : "حفظ الموقع"}
        </Button>
        <Button asChild variant="ghost">
          <Link href={`/venues/${venueId}`}>العودة إلى بيانات المكان</Link>
        </Button>
      </div>
    </div>
  );
}
