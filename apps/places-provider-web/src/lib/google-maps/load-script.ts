export type MapsLoadState = "idle" | "loading" | "ready" | "error" | "unavailable";

type MapsWindow = Window & {
  google?: {
    maps?: {
      importLibrary?: (name: string) => Promise<unknown>;
    };
  };
  __darPlacesMapsReady?: () => void;
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

export function mapsApiIsReady(): boolean {
  if (typeof window === "undefined") return false;
  return Boolean((window as MapsWindow).google?.maps?.importLibrary);
}

export async function waitForGoogleMaps(timeoutMs = 12000): Promise<void> {
  const started = Date.now();
  while (!mapsApiIsReady()) {
    if (Date.now() - started >= timeoutMs) {
      throw new Error("maps_ready_timeout");
    }
    await new Promise((resolve) => setTimeout(resolve, 40));
  }
}

/** Maps JS only. Places/marker load later via importLibrary so a Places outage cannot kill the map. */
export function buildMapsScriptSrc(key: string): string {
  const params = new URLSearchParams({
    key,
    v: "weekly",
    language: "ar",
    region: "SA",
    callback: "__darPlacesMapsReady",
  });
  return `https://maps.googleapis.com/maps/api/js?${params.toString()}`;
}

export function loadGoogleMapsScript(): Promise<void> {
  const key = mapsWebKey();
  if (!key) return Promise.reject(new Error("maps_key_missing"));
  if (typeof window === "undefined") {
    return Promise.reject(new Error("maps_window_missing"));
  }
  if (mapsApiIsReady()) return Promise.resolve();

  return new Promise((resolve, reject) => {
    const win = window as MapsWindow;
    let settled = false;
    const done = (err?: Error) => {
      if (settled) return;
      settled = true;
      window.clearTimeout(watchdog);
      if (err) reject(err);
      else resolve();
    };
    const finish = () => {
      void waitForGoogleMaps()
        .then(() => done())
        .catch((err: unknown) =>
          done(err instanceof Error ? err : new Error("maps_ready_timeout")),
        );
    };
    win.__darPlacesMapsReady = finish;
    const watchdog = window.setTimeout(() => {
      if (mapsApiIsReady()) finish();
      else done(new Error("maps_callback_timeout"));
    }, 15000);

    const existing = document.getElementById(SCRIPT_ID) as HTMLScriptElement | null;
    if (existing) {
      existing.addEventListener("error", () => done(new Error("maps_script_error")), {
        once: true,
      });
      finish();
      return;
    }

    const script = document.createElement("script");
    script.id = SCRIPT_ID;
    script.async = true;
    script.defer = true;
    script.src = buildMapsScriptSrc(key);
    script.onerror = () => done(new Error("maps_script_error"));
    document.head.appendChild(script);
  });
}
