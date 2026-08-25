type LeafletMap = {
  setView: (c: [number, number], z?: number) => void;
  remove: () => void;
  on: (name: string, fn: (e: { latlng: { lat: number; lng: number } }) => void) => void;
};

type LeafletMarker = {
  setLatLng: (c: [number, number]) => void;
  on: (name: string, fn: (e: { latlng: { lat: number; lng: number } }) => void) => void;
};

type LeafletNs = {
  map: (el: HTMLElement) => LeafletMap & { addTo?: unknown };
  tileLayer: (url: string, opts: Record<string, unknown>) => { addTo: (m: LeafletMap) => void };
  marker: (c: [number, number], opts: Record<string, unknown>) => LeafletMarker & {
    addTo: (m: LeafletMap) => LeafletMarker;
  };
};

const CSS_ID = "dar-places-osm-leaflet-css";
const JS_ID = "dar-places-osm-leaflet-js";
const LEAFLET_VERSION = "1.9.4";

function leafletNs(): LeafletNs | null {
  return (window as unknown as { L?: LeafletNs }).L ?? null;
}

async function loadLeaflet(): Promise<LeafletNs> {
  const existing = leafletNs();
  if (existing) return existing;
  if (!document.getElementById(CSS_ID)) {
    const css = document.createElement("link");
    css.id = CSS_ID;
    css.rel = "stylesheet";
    css.href = `https://unpkg.com/leaflet@${LEAFLET_VERSION}/dist/leaflet.css`;
    document.head.appendChild(css);
  }
  await new Promise<void>((resolve, reject) => {
    const existingScript = document.getElementById(JS_ID) as HTMLScriptElement | null;
    if (existingScript) {
      existingScript.addEventListener("load", () => resolve(), { once: true });
      existingScript.addEventListener("error", () => reject(new Error("osm_script_error")), {
        once: true,
      });
      if (leafletNs()) resolve();
      return;
    }
    const script = document.createElement("script");
    script.id = JS_ID;
    script.src = `https://unpkg.com/leaflet@${LEAFLET_VERSION}/dist/leaflet.js`;
    script.async = true;
    script.onload = () => resolve();
    script.onerror = () => reject(new Error("osm_script_error"));
    document.head.appendChild(script);
  });
  const loaded = leafletNs();
  if (!loaded) throw new Error("osm_unavailable");
  return loaded;
}

export function googleMapLooksBroken(element: HTMLElement): boolean {
  const text = element.innerText || "";
  if (/عفو|لم تحم|Google Maps/i.test(text)) return true;
  const tiles = element.querySelectorAll("img, canvas").length;
  if (tiles >= 2) return false;
  return tiles === 0 && element.innerHTML.length < 80;
}

export async function attachOsmMapPin(input: {
  element: HTMLElement;
  lat: number;
  lng: number;
  onMove: (lat: number, lng: number) => void;
}): Promise<{
  setPosition: (lat: number, lng: number) => void;
  destroy: () => void;
}> {
  const L = await loadLeaflet();
  input.element.innerHTML = "";
  input.element.style.minHeight = "18rem";
  const map = L.map(input.element);
  map.setView([input.lat, input.lng], 15);
  L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
    attribution: "&copy; OpenStreetMap",
    maxZoom: 19,
  }).addTo(map);
  const marker = L.marker([input.lat, input.lng], { draggable: true }).addTo(map);
  marker.on("dragend", (e) => {
    input.onMove(e.latlng.lat, e.latlng.lng);
  });
  map.on("click", (e) => {
    marker.setLatLng([e.latlng.lat, e.latlng.lng]);
    input.onMove(e.latlng.lat, e.latlng.lng);
  });
  return {
    setPosition(lat, lng) {
      marker.setLatLng([lat, lng]);
      map.setView([lat, lng]);
    },
    destroy() {
      map.remove();
    },
  };
}
