// Navigation decisions for the TERRA device. Pure: (route, memory, sensor input) -> (screen state, memory, events).
// Nothing here draws; the round screen only renders the returned `state`.

import { bearing, distance, normalize180 } from './geo.js';
import { locate, pointAt } from './route.js';

/** Provisional thresholds. Tune on a real walk; see README.md. */
export const THRESHOLDS = Object.freeze({
  goodAccuracyM: 20, // Reported accuracy worse than this shows "Weak GPS" and freezes decisions.
  startRadiusM: 30, // Within this of the path's first point, guidance begins.
  turnAlertM: 30, // Along-path distance before a turn where the turn screen and vibration start.
  turnPassedM: 5, // The turn screen stays this far past the turn point.
  turnRearmM: 60, // Walking back this far before a turn lets its vibration fire again.
  offRouteEnterM: 35, // Farther than this from the path shows "Off route".
  offRouteExitM: 20, // ...and back under this returns to guidance (hysteresis).
  arriveRadiusM: 20, // Within this of the destination, or of the path's end, is "Arrived".
  arriveExitM: 50, // Leaving arrival requires moving this far away again.
  lookaheadM: 40, // The arrow aims at the next path point, or this far ahead on long straight segments.
});

export const VIBRATION = Object.freeze({
  start: 'short',
  turn: 'double',
  offRoute: 'long',
  arrived: 'triple',
});

export function initialMemory() {
  return { started: false, arrived: false, offRoute: false, firedTurns: [] };
}

const relative = (bearingDeg, headingDeg) => normalize180(bearingDeg - headingDeg);

/** The path point the arrow should aim at while on route. */
export function guideTarget(prep, along, T = THRESHOLDS) {
  const nextVertex = prep.cum.find((c) => c > along + 1) ?? prep.length;
  return pointAt(prep, Math.min(nextVertex, along + T.lookaheadM));
}

/**
 * @param prep  prepareRoute() output
 * @param memory  previous memory (initialMemory() after restart)
 * @param input  { fix: boolean, accuracyM: number, position: {lat, lon}, headingDeg: number }
 * @returns { state, memory, events }
 */
export function navigate(prep, memory, input, T = THRESHOLDS) {
  const events = [];
  const vibrate = (type, detail) => events.push({ type, pattern: VIBRATION[type], detail });

  if (!input.fix) return { state: { mode: 'waiting' }, memory, events };

  const pos = input.position;
  const loc = locate(prep, pos);
  const remainingM = Math.max(0, prep.length - loc.along);

  if (input.accuracyM > T.goodAccuracyM) {
    // Keep showing the rough direction, but widen it by how much the fix could be wrong
    // and make no decisions (start, turns, off route) on it.
    const target = memory.started ? guideTarget(prep, loc.along, T) : prep.origin;
    const toTarget = distance(pos, target);
    const spreadDeg = toTarget <= input.accuracyM ? 360 : Math.max(60, (2 * Math.asin(input.accuracyM / toTarget) * 180) / Math.PI);
    return {
      state: {
        mode: 'uncertain',
        accuracyM: input.accuracyM,
        relDeg: relative(bearing(pos, target), input.headingDeg),
        spreadDeg,
        approxDistanceM: memory.started ? remainingM : distance(pos, prep.origin),
        started: memory.started,
      },
      memory,
      events,
    };
  }

  let m = { ...memory };

  if (!m.started) {
    const toStart = distance(pos, prep.origin);
    if (toStart > T.startRadiusM) {
      return { state: { mode: 'goToStart', distanceM: toStart, relDeg: relative(bearing(pos, prep.origin), input.headingDeg) }, memory: m, events };
    }
    m.started = true;
    vibrate('start', 'Route started');
  }

  const toDestination = distance(pos, prep.route.destination);
  if (m.arrived) {
    const left = toDestination > T.arriveExitM && (remainingM > T.arriveExitM || loc.lateral > T.offRouteEnterM);
    if (left) m.arrived = false;
  } else if (toDestination <= T.arriveRadiusM || (remainingM <= T.arriveRadiusM && loc.lateral <= T.offRouteEnterM)) {
    m.arrived = true;
    m.offRoute = false;
    vibrate('arrived', 'Arrived');
  }
  if (m.arrived) return { state: { mode: 'arrived', name: prep.route.name }, memory: m, events };

  const wasOff = m.offRoute;
  m.offRoute = wasOff ? loc.lateral > T.offRouteExitM : loc.lateral > T.offRouteEnterM;
  if (m.offRoute) {
    if (!wasOff) vibrate('offRoute', `Off route by ${Math.round(loc.lateral)} m`);
    return {
      state: { mode: 'offRoute', distanceToPathM: loc.lateral, relDeg: relative(bearing(pos, loc.nearest), input.headingDeg), remainingM },
      memory: m,
      events,
    };
  }

  // Re-arm turns the walker has backed away from, so a replay vibrates again.
  m.firedTurns = m.firedTurns.filter((i) => prep.turns[i].along - loc.along <= T.turnRearmM);

  const nextTurn = prep.turns.find((t) => t.along > loc.along - T.turnPassedM);
  const toTurnM = nextTurn ? nextTurn.along - loc.along : null;

  if (nextTurn && toTurnM <= T.turnAlertM) {
    if (!m.firedTurns.includes(nextTurn.index)) {
      m.firedTurns = [...m.firedTurns, nextTurn.index];
      vibrate('turn', `Turn ${nextTurn.direction} (#${nextTurn.index + 1})`);
    }
    return {
      state: { mode: 'turn', direction: nextTurn.direction, degrees: nextTurn.degrees, toTurnM: Math.max(0, toTurnM), remainingM, turnIndex: nextTurn.index, instruction: nextTurn.instruction },
      memory: m,
      events,
    };
  }

  const target = guideTarget(prep, loc.along, T);
  return {
    state: { mode: 'guiding', relDeg: relative(bearing(pos, target), input.headingDeg), toTurnM, remainingM, target },
    memory: m,
    events,
  };
}
