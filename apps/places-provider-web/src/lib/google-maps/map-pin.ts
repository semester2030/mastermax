import { mapsMapId } from "./load-script";

export type MapPinHandle = {
  setPosition: (lat: number, lng: number) => void;
  destroy: () => void;
};

type MapsLib = {
  Map: new (
    el: HTMLElement,
    opts: Record<string, unknown>,
  ) => {
    setCenter: (c: { lat: number; lng: number }) => void;
    setZoom: (z: number) => void;
  };
  Marker: new (opts: Record<string, unknown>) => {
    setPosition: (c: { lat: number; lng: number }) => void;
    setMap: (map: unknown) => void;
    addListener: (name: string, fn: () => void) => void;
    getPosition: () => { lat: () => number; lng: () => number } | null;
  };
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
} | null {
  return (
    (
      window as unknown as {
        google?: { maps?: { importLibrary?: (name: string) => Promise<unknown> } };
      }
    ).google?.maps ?? null
  );
}

export async function attachDraggableMapPin(input: {
  element: HTMLElement;
  lat: number;
  lng: number;
  onMove: (lat: number, lng: number) => void;
  useMapId?: boolean;
}): Promise<MapPinHandle> {
  const root = mapsRoot();
  if (!root?.importLibrary) throw new Error("maps_unavailable");
  const maps = (await root.importLibrary("maps")) as MapsLib;
  // Classic map first. A bad or unauthorized Map ID renders Google's
  // gray error overlay without throwing, so it must stay opt-in.
  const mapId = input.useMapId === true ? mapsMapId() : null;
  const map = new maps.Map(input.element, {
    center: { lat: input.lat, lng: input.lng },
    zoom: 15,
    ...(mapId ? { mapId } : {}),
    streetViewControl: false,
    mapTypeControl: false,
    fullscreenControl: false,
  });

  if (mapId) {
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
  }

  const marker = new maps.Marker({
    map,
    position: { lat: input.lat, lng: input.lng },
    draggable: true,
    title: "موقع المكان",
  });
  marker.addListener("dragend", () => {
    const pos = marker.getPosition();
    if (pos) input.onMove(pos.lat(), pos.lng());
  });
  return {
    setPosition(lat, lng) {
      marker.setPosition({ lat, lng });
      map.setCenter({ lat, lng });
    },
    destroy() {
      marker.setMap(null);
    },
  };
}
