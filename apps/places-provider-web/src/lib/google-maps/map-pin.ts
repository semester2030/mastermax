import { mapsMapId } from "./load-script";
import { resolveClassicMarkerCtor } from "./marker-ctor";
import { attachOsmMapPin, googleMapLooksBroken } from "./osm-pin";

export type MapPinHandle = {
  setPosition: (lat: number, lng: number) => void;
  destroy: () => void;
};

type MapInstance = {
  setCenter: (c: { lat: number; lng: number }) => void;
  setZoom: (z: number) => void;
  addListener?: (name: string, fn: (e?: { latLng?: { lat: () => number; lng: () => number } }) => void) => void;
};

type MapsLib = {
  Map: new (el: HTMLElement, opts: Record<string, unknown>) => MapInstance;
  RenderingType?: { RASTER: unknown };
  Marker?: new (opts: Record<string, unknown>) => {
    setPosition: (c: { lat: number; lng: number }) => void;
    setMap: (map: unknown) => void;
    addListener: (name: string, fn: () => void) => void;
    getPosition: () => { lat: () => number; lng: () => number } | null;
  };
  OverlayView?: new () => {
    setMap: (map: unknown) => void;
    getPanes?: () => { overlayMouseTarget?: HTMLElement } | null;
    getProjection?: () => {
      fromLatLngToDivPixel: (ll: unknown) => { x: number; y: number } | null;
    };
    onAdd?: () => void;
    draw?: () => void;
    onRemove?: () => void;
  };
  LatLng?: new (lat: number, lng: number) => unknown;
};

type MarkerLib = {
  AdvancedMarkerElement?: new (opts: Record<string, unknown>) => {
    position: { lat: number; lng: number } | null;
    map: unknown;
    addListener: (name: string, fn: () => void) => void;
  };
};

function mapsRoot(): {
  importLibrary?: (name: string) => Promise<unknown>;
  Marker?: MapsLib["Marker"];
} | null {
  return (
    (
      window as unknown as {
        google?: {
          maps?: {
            importLibrary?: (name: string) => Promise<unknown>;
            Marker?: MapsLib["Marker"];
          };
        };
      }
    ).google?.maps ?? null
  );
}

function attachClassicMarker(
  Marker: NonNullable<MapsLib["Marker"]>,
  map: MapInstance,
  lat: number,
  lng: number,
  onMove: (lat: number, lng: number) => void,
): MapPinHandle {
  const marker = new Marker({
    map,
    position: { lat, lng },
    draggable: true,
    title: "موقع المكان",
  });
  marker.addListener("dragend", () => {
    const pos = marker.getPosition();
    if (pos) onMove(pos.lat(), pos.lng());
  });
  return {
    setPosition(nextLat, nextLng) {
      marker.setPosition({ lat: nextLat, lng: nextLng });
      map.setCenter({ lat: nextLat, lng: nextLng });
    },
    destroy() {
      marker.setMap(null);
    },
  };
}

function attachDomPin(
  maps: MapsLib,
  map: MapInstance,
  lat: number,
  lng: number,
  onMove: (lat: number, lng: number) => void,
): MapPinHandle {
  let current = { lat, lng };
  const OverlayView = maps.OverlayView;
  if (typeof OverlayView !== "function" || typeof maps.LatLng !== "function") {
    map.addListener?.("click", (e) => {
      const pair = e?.latLng;
      if (!pair) return;
      current = { lat: pair.lat(), lng: pair.lng() };
      map.setCenter(current);
      onMove(current.lat, current.lng);
    });
    return {
      setPosition(nextLat, nextLng) {
        current = { lat: nextLat, lng: nextLng };
        map.setCenter(current);
      },
      destroy() {},
    };
  }

  const overlay = new OverlayView();
  const pin = document.createElement("button");
  pin.type = "button";
  pin.setAttribute("aria-label", "موقع المكان");
  pin.style.cssText =
    "width:22px;height:22px;margin:0;padding:0;border:3px solid #fff;border-radius:50% 50% 50% 0;background:#3F0071;transform:translate(-50%,-100%) rotate(-45deg);cursor:grab;box-shadow:0 2px 8px rgba(0,0,0,.28)";
  overlay.onAdd = () => {
    overlay.getPanes?.()?.overlayMouseTarget?.appendChild(pin);
  };
  overlay.draw = () => {
    const projection = overlay.getProjection?.();
    const point = projection?.fromLatLngToDivPixel(new maps.LatLng!(current.lat, current.lng));
    if (!point) return;
    pin.style.left = `${point.x}px`;
    pin.style.top = `${point.y}px`;
    pin.style.position = "absolute";
  };
  overlay.onRemove = () => {
    pin.remove();
  };
  overlay.setMap(map);

  if (!pin.style.position) {
    pin.style.position = "absolute";
  }

  map.addListener?.("click", (e) => {
    const pair = e?.latLng;
    if (!pair) return;
    current = { lat: pair.lat(), lng: pair.lng() };
    overlay.draw?.();
    onMove(current.lat, current.lng);
  });

  return {
    setPosition(nextLat, nextLng) {
      current = { lat: nextLat, lng: nextLng };
      map.setCenter(current);
      overlay.draw?.();
    },
    destroy() {
      overlay.setMap(null);
    },
  };
}

async function attachGoogleMapPin(input: {
  element: HTMLElement;
  lat: number;
  lng: number;
  onMove: (lat: number, lng: number) => void;
  useMapId?: boolean;
}): Promise<MapPinHandle> {
  const root = mapsRoot();
  if (!root?.importLibrary) throw new Error("maps_unavailable");
  const maps = (await root.importLibrary("maps")) as MapsLib;
  const mapId = input.useMapId === true ? mapsMapId() : null;
  const map = new maps.Map(input.element, {
    center: { lat: input.lat, lng: input.lng },
    zoom: 15,
    ...(mapId ? { mapId } : {}),
    ...(maps.RenderingType ? { renderingType: maps.RenderingType.RASTER } : {}),
    streetViewControl: false,
    mapTypeControl: false,
    fullscreenControl: false,
  });

  if (mapId) {
    try {
      const markerLib = (await root.importLibrary("marker")) as MarkerLib;
      if (markerLib.AdvancedMarkerElement) {
        const marker = new markerLib.AdvancedMarkerElement({
          map,
          position: { lat: input.lat, lng: input.lng },
          gmpDraggable: true,
          title: "موقع المكان",
        });
        marker.addListener("dragend", () => {
          const pos = marker.position;
          if (pos) input.onMove(pos.lat, pos.lng);
        });
        return {
          setPosition(lat, lng) {
            marker.position = { lat, lng };
            map.setCenter({ lat, lng });
          },
          destroy() {
            marker.map = null;
          },
        };
      }
    } catch {
      // Fall through to a classic or DOM pin. The map is already constructed.
    }
  }

  const Marker = resolveClassicMarkerCtor(maps);
  if (Marker) {
    try {
      return attachClassicMarker(
        Marker as NonNullable<MapsLib["Marker"]>,
        map,
        input.lat,
        input.lng,
        input.onMove,
      );
    } catch {
      // Keep the map; use a DOM pin instead of failing the page.
    }
  }

  return attachDomPin(maps, map, input.lat, input.lng, input.onMove);
}

export async function attachDraggableMapPin(input: {
  element: HTMLElement;
  lat: number;
  lng: number;
  onMove: (lat: number, lng: number) => void;
  useMapId?: boolean;
}): Promise<MapPinHandle> {
  try {
    const handle = await attachGoogleMapPin(input);
    await new Promise((resolve) => window.setTimeout(resolve, 1600));
    if (!googleMapLooksBroken(input.element)) return handle;
    handle.destroy();
  } catch {
    // Google script/auth/tiles failed; OpenStreetMap still lets the operator set a pin.
  }
  input.element.innerHTML = "";
  return attachOsmMapPin(input);
}
