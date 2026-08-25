export type MapsLoadState = "idle" | "loading" | "ready" | "error" | "unavailable";

type MapsWindow = Window & {
  google?: {
    maps?: {
      importLibrary?: (name: string) => Promise<unknown>;
    };
  };
};

const SCRIPT_ID = "dar-places-maps-js";

export function mapsWebKey(): string | null {
  const key = process.env.NEXT_PUBLIC_GOOGLE_MAPS_WEB_API_KEY?.trim();
  return key || null;
}

export function mapsMapId(): string | null {
  const id = process.env.NEXT_PUBLIC_GOOGLE_MAPS_MAP_ID?.trim();
  return id || null;
}

export function loadGoogleMapsScript(): Promise<void> {
  const key = mapsWebKey();
  if (!key) return Promise.reject(new Error("maps_key_missing"));
  if (typeof window === "undefined") {
    return Promise.reject(new Error("maps_window_missing"));
  }
  const existing = document.getElementById(SCRIPT_ID);
  if ((window as MapsWindow).google?.maps?.importLibrary) {
    return Promise.resolve();
  }
  if (existing) {
    return new Promise((resolve, reject) => {
      existing.addEventListener("load", () => resolve(), { once: true });
      existing.addEventListener("error", () => reject(new Error("maps_script_error")), {
        once: true,
      });
    });
  }
  return new Promise((resolve, reject) => {
    const script = document.createElement("script");
    script.id = SCRIPT_ID;
    script.async = true;
    script.defer = true;
    const params = new URLSearchParams({
      key,
      v: "weekly",
      language: "ar",
      region: "SA",
      libraries: "places,marker",
      loading: "async",
    });
    script.src = `https://maps.googleapis.com/maps/api/js?${params.toString()}`;
    script.onload = () => resolve();
    script.onerror = () => reject(new Error("maps_script_error"));
    document.head.appendChild(script);
  });
}
