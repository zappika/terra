// Small-scale geodesy for walking routes. Distances in meters, angles in degrees.
// Bearings are clockwise from true north, 0–360.

const R = 6371008.8;
const rad = (d) => (d * Math.PI) / 180;
const deg = (r) => (r * 180) / Math.PI;

export function distance(a, b) {
  const dLat = rad(b.lat - a.lat);
  const dLon = rad(b.lon - a.lon);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.min(1, Math.sqrt(h)));
}

export function bearing(a, b) {
  const y = Math.sin(rad(b.lon - a.lon)) * Math.cos(rad(b.lat));
  const x = Math.cos(rad(a.lat)) * Math.sin(rad(b.lat)) - Math.sin(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.cos(rad(b.lon - a.lon));
  return normalize360(deg(Math.atan2(y, x)));
}

/** The point `meters` away from `p` along `bearingDeg`. */
export function offset(p, bearingDeg, meters) {
  const d = meters / R;
  const t = rad(bearingDeg);
  const lat1 = rad(p.lat);
  const lat2 = Math.asin(Math.sin(lat1) * Math.cos(d) + Math.cos(lat1) * Math.sin(d) * Math.cos(t));
  const lon2 = rad(p.lon) + Math.atan2(Math.sin(t) * Math.sin(d) * Math.cos(lat1), Math.cos(d) - Math.sin(lat1) * Math.sin(lat2));
  return { lat: deg(lat2), lon: deg(lon2) };
}

export function normalize360(a) {
  return ((a % 360) + 360) % 360;
}

/** Signed angle in (-180, 180]. Positive is clockwise (to the right). */
export function normalize180(a) {
  const x = normalize360(a + 180) - 180;
  return x === -180 ? 180 : x;
}

/** Flat x/y meters around `origin` (east, north). Good enough within a few km. */
export function toLocal(origin, p) {
  return {
    x: rad(p.lon - origin.lon) * R * Math.cos(rad(origin.lat)),
    y: rad(p.lat - origin.lat) * R,
  };
}

export function lerp(a, b, t) {
  return { lat: a.lat + (b.lat - a.lat) * t, lon: a.lon + (b.lon - a.lon) * t };
}
