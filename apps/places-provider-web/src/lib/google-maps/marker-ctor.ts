type MarkerCtor = new (opts: Record<string, unknown>) => unknown;

type MapsLike = {
  Marker?: MarkerCtor;
};

type MapsWindow = {
  google?: {
    maps?: {
      Marker?: MarkerCtor;
    };
  };
};

/** importLibrary("maps") omits Marker; the weekly build keeps it on google.maps. */
export function resolveClassicMarkerCtor(maps: MapsLike): MarkerCtor | null {
  const fromLib = maps.Marker;
  const fromGlobal =
    typeof window === "undefined"
      ? undefined
      : (window as MapsWindow).google?.maps?.Marker;
  if (typeof fromLib === "function") return fromLib;
  if (typeof fromGlobal === "function") return fromGlobal;
  return null;
}
