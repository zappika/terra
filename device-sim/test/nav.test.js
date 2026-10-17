import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { bearing, distance, normalize180, offset } from '../src/geo.js';
import { locate, prepareRoute, simulatePosition, validateRoute } from '../src/route.js';
import { THRESHOLDS as T, initialMemory, navigate } from '../src/nav.js';

// Synthetic L-shaped route: 200 m north, turn right, 200 m east, turn left, 100 m north.
const p0 = { lat: 41.4, lon: 2.17 };
const p1 = offset(p0, 0, 200);
const p2 = offset(p1, 90, 200);
const p3 = offset(p2, 0, 100);
const L = prepareRoute({
  version: 1,
  name: 'L route',
  start: p0,
  destination: p3,
  points: [p0, p1, p2, p3],
  turns: [
    { pointIndex: 1, turnDegrees: 90, instruction: 'Turn right', distanceFromStartMeters: 200 },
    { pointIndex: 2, turnDegrees: -90, instruction: 'Turn left', distanceFromStartMeters: 400 },
  ],
  distanceMeters: 500,
});

const good = (position, headingDeg = 0) => ({ fix: true, accuracyM: 5, position, headingDeg });
const at = (progress, lateral = 0) => simulatePosition(L, progress, lateral).position;

/** Runs a sequence of inputs, returning every step's result. */
function walk(prep, inputs, memory = initialMemory()) {
  return inputs.map((input) => {
    const r = navigate(prep, memory, input);
    memory = r.memory;
    return r;
  });
}

test('geometry: bearings, distances and path location', () => {
  assert.ok(Math.abs(bearing(p0, p1) - 0) < 0.01);
  assert.ok(Math.abs(bearing(p1, p2) - 90) < 0.1);
  assert.ok(Math.abs(distance(p0, p1) - 200) < 0.01);
  assert.equal(normalize180(270), -90);
  assert.ok(Math.abs(L.length - 500) < 0.5);
  assert.equal(L.turns[0].direction, 'right');
  assert.equal(L.turns[1].direction, 'left');

  const loc = locate(L, at(100, 15));
  assert.ok(Math.abs(loc.along - 100) < 0.5);
  assert.ok(Math.abs(loc.lateral - 15) < 0.5);
});

test('no fix: waiting for GPS, nothing decided', () => {
  const memory = initialMemory();
  const r = navigate(L, memory, { fix: false, accuracyM: 5, position: p0, headingDeg: 0 });
  assert.equal(r.state.mode, 'waiting');
  assert.equal(r.memory, memory);
  assert.deepEqual(r.events, []);
});

test('poor accuracy: uncertain wide arrow, does not start the route', () => {
  const r = navigate(L, initialMemory(), { fix: true, accuracyM: 40, position: at(0), headingDeg: 0 });
  assert.equal(r.state.mode, 'uncertain');
  assert.ok(r.state.spreadDeg >= 60);
  assert.equal(r.memory.started, false);
  assert.deepEqual(r.events, []);
});

test('go to start when far away, then begin guidance near it', () => {
  const [far, near] = walk(L, [good(at(-120)), good(at(-10))]);
  assert.equal(far.state.mode, 'goToStart');
  assert.ok(Math.abs(far.state.distanceM - 120) < 1);
  assert.equal(near.state.mode, 'guiding');
  assert.deepEqual(near.events.map((e) => e.type), ['start']);
});

test('heading changes rotate the arrow by the opposite amount', () => {
  const memory = { ...initialMemory(), started: true };
  const pos = at(50);
  const north = navigate(L, memory, good(pos, 0)).state;
  const east = navigate(L, memory, good(pos, 90)).state;
  const west = navigate(L, memory, good(pos, 270)).state;
  assert.equal(north.mode, 'guiding');
  assert.ok(Math.abs(north.relDeg) < 1, 'walking north, facing north: arrow straight up');
  assert.ok(Math.abs(east.relDeg + 90) < 1, 'facing east: arrow points left');
  assert.ok(Math.abs(west.relDeg - 90) < 1, 'facing west: arrow points right');
});

test('turn proximity: turn screen and one vibration, re-armed after backing away', () => {
  const steps = walk(L, [good(at(0)), good(at(150)), good(at(180)), good(at(190)), good(at(198)), good(at(100)), good(at(185))]);
  const modes = steps.map((s) => s.state.mode);
  assert.deepEqual(modes, ['guiding', 'guiding', 'turn', 'turn', 'turn', 'guiding', 'turn']);
  assert.equal(steps[2].state.direction, 'right');
  assert.ok(Math.abs(steps[2].state.toTurnM - 20) < 0.5);
  const turnEvents = steps.map((s) => s.events.filter((e) => e.type === 'turn').length);
  assert.deepEqual(turnEvents, [0, 0, 1, 0, 0, 0, 1]);
});

test('off route: enters past 35 m, holds until back under 20 m, no new route invented', () => {
  const steps = walk(L, [good(at(0)), good(at(100, 50)), good(at(100, 28)), good(at(100, 10))]);
  assert.deepEqual(steps.map((s) => s.state.mode), ['guiding', 'offRoute', 'offRoute', 'guiding']);
  assert.ok(Math.abs(steps[1].state.distanceToPathM - 50) < 1);
  // Arrow points back toward the path: walker is east of a north-going path, facing north.
  assert.ok(Math.abs(steps[1].state.relDeg + 90) < 2);
  assert.deepEqual(steps[1].events.map((e) => e.type), ['offRoute']);
  assert.deepEqual(steps[2].events, []);
});

test('remaining distance follows the path, not a straight line', () => {
  const [, r] = walk(L, [good(at(0)), good(at(100))]);
  assert.ok(Math.abs(r.state.remainingM - 400) < 1);
  assert.ok(distance(at(100), p3) < 300, 'straight-line distance is much shorter');
});

test('arrival: arrives once, backing away resumes guidance, restart goes back to start', () => {
  const steps = walk(L, [good(at(0)), good(at(485)), good(at(495)), good(at(300))]);
  assert.deepEqual(steps.map((s) => s.state.mode), ['guiding', 'arrived', 'arrived', 'guiding']);
  assert.deepEqual(steps[1].events.map((e) => e.type), ['arrived']);
  assert.deepEqual(steps[2].events, []);

  const restarted = navigate(L, initialMemory(), good(at(300)));
  assert.equal(restarted.state.mode, 'goToStart');
});

test('sample fixture: full walk passes through every state in order', () => {
  const route = JSON.parse(readFileSync(new URL('../../ios/Fixtures/sample-route-v1.json', import.meta.url)));
  assert.deepEqual(validateRoute(route), []);
  const prep = prepareRoute(route);
  const seen = [];
  let memory = initialMemory();
  let vibrations = 0;
  const step = (input) => {
    const r = navigate(prep, memory, input);
    memory = r.memory;
    vibrations += r.events.length;
    if (seen[seen.length - 1] !== r.state.mode) seen.push(r.state.mode);
  };
  const pos = (p, lat = 0) => simulatePosition(prep, p, lat).position;
  step({ fix: false, accuracyM: 5, position: pos(-150), headingDeg: 0 });
  step({ fix: true, accuracyM: 60, position: pos(-150), headingDeg: 0 });
  for (let p = -150; p <= prep.length; p += 2) step(good(pos(p), simulatePosition(prep, p).walkingBearing));
  assert.deepEqual(seen.slice(0, 3), ['waiting', 'uncertain', 'goToStart']);
  assert.ok(seen.includes('guiding') && seen.includes('turn'));
  assert.equal(seen[seen.length - 1], 'arrived');
  // start + one per turn reached before arrival + arrival; never repeated continuously.
  assert.ok(vibrations >= 3 && vibrations <= prep.turns.length + 2, `vibrations: ${vibrations}`);
});

test('validateRoute rejects routes the device cannot follow', () => {
  assert.ok(validateRoute({ version: 2, points: [] }).length > 0);
  const bad = { version: 1, start: p0, destination: p3, points: [p0, p1, p2], turns: [{ pointIndex: 2 }] };
  assert.match(validateRoute(bad).join(' '), /Turn 0/);
});
