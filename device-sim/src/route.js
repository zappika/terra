// RouteV1 loading and path geometry. Mirrors the checks in ios/TERRA/Routing/RouteValidator.swift
// closely enough to reject files the device could not follow.

import { bearing, distance, lerp, normalize180, normalize360, offset, toLocal } from './geo.js';

const MAX_POINTS = 2000;

function isCoord(c) {
  return c && Number.isFinite(c.lat) && Number.isFinite(c.lon) && Math.abs(c.lat) <= 90 && Math.abs(c.lon) <= 180 && !(c.lat === 0 && c.lon === 0);
}

/** Returns a list of human-readable problems; empty means the route is usable. */
export function validateRoute(r) {
  if (!r || typeof r !== 'object') return ['Not a JSON object.'];
  const errors = [];
  if (r.version !== 1) errors.push(`Unsupported version ${r.version}; expected 1.`);
  if (!Array.isArray(r.points) || r.points.length < 2) return [...errors, 'Route needs at least 2 points.'];
  if (r.points.length > MAX_POINTS) errors.push(`Route has ${r.points.length} points; limit is ${MAX_POINTS}.`);
  const bad = r.points.findIndex((p) => !isCoord(p));
  if (bad >= 0) errors.push(`Point ${bad} is not a valid coordinate.`);
  if (!isCoord(r.start)) errors.push('Missing or invalid start.');
  if (!isCoord(r.destination)) errors.push('Missing or invalid destination.');
  if (!Array.isArray(r.turns)) errors.push('Missing turns array.');
  else {
    let last = 0;
    r.turns.forEach((t, i) => {
      if (!Number.isInteger(t.pointIndex) || t.pointIndex <= last || t.pointIndex >= r.points.length - 1) errors.push(`Turn ${i} has an invalid pointIndex.`);
      else last = t.pointIndex;
    });
  }
  return errors;
}

/** Signed heading change at a path vertex. Positive is a right turn, matching RouteV1.turnDegrees. */
export function turnAngleAt(points, i) {
  return normalize180(bearing(points[i], points[i + 1]) - bearing(points[i - 1], points[i]));
}

export function turnLabel(degrees) {
  if (Math.abs(degrees) < 25) return 'ahead';
  return degrees > 0 ? 'right' : 'left';
}

/** Precomputes cumulative distances and turn positions along the path. */
export function prepareRoute(route) {
  const points = route.points;
  const origin = points[0];
  const local = points.map((p) => toLocal(origin, p));
  const cum = [0];
  for (let i = 1; i < points.length; i++) cum.push(cum[i - 1] + distance(points[i - 1], points[i]));
  const turns = route.turns.map((t, index) => {
    // Direction comes from the path geometry; `instruction` text is only shown for debugging.
    const degrees = turnAngleAt(points, t.pointIndex);
    return { index, pointIndex: t.pointIndex, along: cum[t.pointIndex], degrees, direction: turnLabel(degrees), instruction: t.instruction };
  });
  return { route, points, origin, local, cum, length: cum[cum.length - 1], turns };
}

/** Nearest point on the path: distance along it, distance from it, and the snapped coordinate. */
export function locate(prep, pos) {
  const p = toLocal(prep.origin, pos);
  let best = null;
  for (let i = 0; i < prep.points.length - 1; i++) {
    const a = prep.local[i];
    const b = prep.local[i + 1];
    const dx = b.x - a.x;
    const dy = b.y - a.y;
    const len2 = dx * dx + dy * dy;
    const t = len2 === 0 ? 0 : Math.max(0, Math.min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2));
    const d = Math.hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy));
    if (!best || d < best.lateral) best = { segment: i, t, lateral: d };
  }
  const { segment, t } = best;
  return {
    segment,
    lateral: best.lateral,
    along: prep.cum[segment] + t * (prep.cum[segment + 1] - prep.cum[segment]),
    nearest: lerp(prep.points[segment], prep.points[segment + 1], t),
  };
}

function segmentAt(prep, along) {
  let i = 0;
  while (i < prep.points.length - 2 && prep.cum[i + 1] <= along) i++;
  return i;
}

export function pointAt(prep, along) {
  const a = Math.max(0, Math.min(prep.length, along));
  const i = segmentAt(prep, a);
  const span = prep.cum[i + 1] - prep.cum[i];
  return lerp(prep.points[i], prep.points[i + 1], span === 0 ? 0 : (a - prep.cum[i]) / span);
}

/** Walking direction of the path at `along`. */
export function directionAt(prep, along) {
  const i = segmentAt(prep, Math.max(0, Math.min(prep.length, along)));
  return bearing(prep.points[i], prep.points[i + 1]);
}

/** Where the simulated walker approaches from before reaching the path's first point. */
export function approachBearing(prep) {
  const { start } = prep.route;
  if (distance(prep.origin, start) > 5) return bearing(prep.origin, start);
  return normalize360(directionAt(prep, 0) + 180);
}

/**
 * Simulator-only: turns slider values into a GPS position.
 * progress < 0 places the walker on a straight approach leg before the path starts.
 * lateral > 0 moves the walker to the right of the walking direction.
 */
export function simulatePosition(prep, progress, lateral = 0) {
  let base;
  let dir;
  if (progress < 0) {
    const away = approachBearing(prep);
    base = offset(prep.origin, away, -progress);
    dir = normalize360(away + 180);
  } else {
    base = pointAt(prep, progress);
    dir = directionAt(prep, progress);
  }
  return { position: lateral ? offset(base, dir + 90, lateral) : base, walkingBearing: dir };
}
