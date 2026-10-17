// Simulator wiring: controls -> simulated sensors -> navigate() -> screen, map and event log.

import { normalize360, offset, toLocal } from './geo.js';
import { approachBearing, locate, prepareRoute, simulatePosition, validateRoute } from './route.js';
import { THRESHOLDS, guideTarget, initialMemory, navigate } from './nav.js';
import { drawScreen, formatDistance } from './screen.js';

const APPROACH_M = 200;
const WALK_SPEED = 1.4;
const $ = (id) => document.getElementById(id);
const el = Object.fromEntries(
  ['screen', 'device', 'buzzLabel', 'zoom', 'log', 'debug', 'map', 'closeUp', 'routeFile', 'loadSample', 'routeStatus', 'progress', 'progressOut', 'lateral', 'lateralOut', 'recenter', 'walk', 'speed', 'heading', 'headingNum', 'follow', 'fix', 'accuracy', 'accuracyOut', 'accuracyHint', 'restart'].map((id) => [id, $(id)]),
);
const screenCtx = el.screen.getContext('2d');
const mapCtx = el.map.getContext('2d');

let prep = null;
let memory = initialMemory();
let result = null;
let sim = null; // { position, walkingBearing }
let walking = false;
let lastFrame = 0;
let buzzTimer = 0;

el.accuracyHint.textContent = `Worse than ±${THRESHOLDS.goodAccuracyM} m is treated as uncertain.`;

function loadRoute(route, label) {
  const errors = validateRoute(route);
  if (errors.length) {
    el.routeStatus.textContent = `Rejected ${label}: ${errors.join(' ')}`;
    el.routeStatus.className = 'hint error';
    return;
  }
  prep = prepareRoute(route);
  el.routeStatus.textContent = `${route.name ?? 'Unnamed'} · ${route.points.length} points · ${route.turns.length} turns · path ${formatDistance(prep.length)} (route says ${formatDistance(route.distanceMeters)})`;
  el.routeStatus.className = 'hint';
  el.progress.min = -APPROACH_M;
  el.progress.max = Math.ceil(prep.length);
  restart();
}

async function loadSample() {
  const res = await fetch('/fixtures/sample-route-v1.json');
  loadRoute(await res.json(), 'sample');
}

function restart() {
  memory = initialMemory();
  el.log.replaceChildren();
  setWalking(false);
  el.progress.value = -150;
  el.lateral.value = 0;
  update();
}

function setWalking(on) {
  walking = on;
  el.walk.textContent = on ? 'Pause ❚❚' : 'Walk ▶';
}

function setHeading(deg) {
  const h = Math.round(normalize360(deg)) % 360;
  el.heading.value = h;
  el.headingNum.value = h;
}

function update() {
  if (!prep) return;
  const progress = Number(el.progress.value);
  const lateral = Number(el.lateral.value);
  sim = simulatePosition(prep, progress, lateral);
  if (el.follow.checked) setHeading(sim.walkingBearing);
  el.progressOut.textContent = `${Math.round(progress)} m`;
  el.lateralOut.textContent = lateral === 0 ? 'on path' : `${Math.abs(lateral)} m ${lateral > 0 ? 'right' : 'left'}`;
  el.accuracyOut.textContent = `±${el.accuracy.value} m`;
  el.accuracy.disabled = !el.fix.checked;

  const input = { fix: el.fix.checked, accuracyM: Number(el.accuracy.value), position: sim.position, headingDeg: Number(el.heading.value) };
  result = navigate(prep, memory, input);
  memory = result.memory;
  result.events.forEach((e) => logEvent(e, progress));
  showDebug(input);
  drawMap(input);
}

function logEvent(e, progress) {
  const li = document.createElement('li');
  li.textContent = `${new Date().toLocaleTimeString()}  ${e.pattern.padEnd(6)}  ${e.detail}  @ ${Math.round(progress)} m`;
  el.log.prepend(li);
  el.device.classList.remove('buzz');
  void el.device.offsetWidth; // restart the CSS animation
  el.device.classList.add('buzz');
  el.buzzLabel.textContent = `● VIBRATE: ${e.pattern} — ${e.detail}`;
  el.buzzLabel.classList.add('on');
  clearTimeout(buzzTimer);
  buzzTimer = setTimeout(() => el.buzzLabel.classList.remove('on'), 1200);
}

function showDebug(input) {
  const s = result.state;
  const loc = locate(prep, input.position);
  const rows = [
    ['mode', s.mode],
    ['heading', `${input.headingDeg}°`],
    ['arrow (rel)', s.relDeg != null ? `${s.relDeg.toFixed(1)}°` : '—'],
    ['along path', `${loc.along.toFixed(1)} m`],
    ['from path', `${loc.lateral.toFixed(1)} m`],
    ['to next turn', s.toTurnM != null ? `${s.toTurnM.toFixed(1)} m` : '—'],
    ['remaining', s.remainingM != null ? `${s.remainingM.toFixed(1)} m` : '—'],
    ['turn', s.mode === 'turn' ? `#${s.turnIndex + 1} ${s.direction} (${s.degrees.toFixed(0)}°) — file says “${s.instruction}”` : '—'],
    ['memory', `started=${memory.started} offRoute=${memory.offRoute} arrived=${memory.arrived} fired=[${memory.firedTurns.map((i) => i + 1).join(',')}]`],
    ['position', `${input.position.lat.toFixed(6)}, ${input.position.lon.toFixed(6)}`],
  ];
  el.debug.textContent = rows.map(([k, v]) => `${k.padEnd(13)} ${v}`).join('\n');
}

function drawMap(input) {
  const W = el.map.width;
  const ctx = mapCtx;
  const loc = (p) => toLocal(prep.origin, p);
  const approachEnd = offset(prep.origin, approachBearing(prep), APPROACH_M);
  const pts = prep.points.map(loc);
  const here = loc(input.position);

  let cx, cy, scale;
  if (el.closeUp.checked) {
    cx = here.x;
    cy = here.y;
    scale = W / 250;
  } else {
    const all = [...pts, loc(prep.route.destination), loc(approachEnd)];
    const xs = all.map((p) => p.x);
    const ys = all.map((p) => p.y);
    cx = (Math.min(...xs) + Math.max(...xs)) / 2;
    cy = (Math.min(...ys) + Math.max(...ys)) / 2;
    scale = (W * 0.9) / Math.max(Math.max(...xs) - Math.min(...xs), Math.max(...ys) - Math.min(...ys), 50);
  }
  const X = (p) => W / 2 + (p.x - cx) * scale;
  const Y = (p) => W / 2 - (p.y - cy) * scale;
  const line = (a, b) => {
    ctx.beginPath();
    ctx.moveTo(X(a), Y(a));
    ctx.lineTo(X(b), Y(b));
    ctx.stroke();
  };

  ctx.clearRect(0, 0, W, W);
  ctx.lineCap = 'round';
  ctx.lineJoin = 'round';

  ctx.setLineDash([10, 10]);
  ctx.strokeStyle = '#999';
  ctx.lineWidth = 3;
  line(loc(approachEnd), pts[0]);
  ctx.setLineDash([]);

  const along = locate(prep, input.position).along;
  ctx.lineWidth = 6;
  for (let i = 0; i < pts.length - 1; i++) {
    ctx.strokeStyle = prep.cum[i + 1] <= along && memory.started ? '#aaa' : '#111';
    line(pts[i], pts[i + 1]);
  }

  ctx.font = 'bold 20px system-ui, sans-serif';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  for (const t of prep.turns) {
    const p = pts[t.pointIndex];
    ctx.fillStyle = '#fff';
    ctx.strokeStyle = '#111';
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.arc(X(p), Y(p), 14, 0, Math.PI * 2);
    ctx.fill();
    ctx.stroke();
    ctx.fillStyle = '#111';
    ctx.fillText(String(t.index + 1), X(p), Y(p) + 1);
  }
  const marker = (p, label) => {
    ctx.fillStyle = '#111';
    ctx.fillRect(X(p) - 14, Y(p) - 14, 28, 28);
    ctx.fillStyle = '#fff';
    ctx.fillText(label, X(p), Y(p) + 1);
  };
  marker(pts[0], 'S');
  marker(loc(prep.route.destination), 'D');

  // Arrow target and off-route connector.
  const s = result.state;
  let target = null;
  if (s.mode === 'guiding' || (s.mode === 'uncertain' && memory.started)) target = guideTarget(prep, along);
  else if (s.mode === 'goToStart' || s.mode === 'uncertain') target = prep.origin;
  else if (s.mode === 'offRoute') target = locate(prep, input.position).nearest;
  if (target) {
    const t = loc(target);
    ctx.strokeStyle = '#c00';
    ctx.lineWidth = 2;
    ctx.setLineDash([6, 6]);
    line(here, t);
    ctx.setLineDash([]);
    ctx.lineWidth = 4;
    line({ x: t.x - 8 / scale, y: t.y - 8 / scale }, { x: t.x + 8 / scale, y: t.y + 8 / scale });
    line({ x: t.x - 8 / scale, y: t.y + 8 / scale }, { x: t.x + 8 / scale, y: t.y - 8 / scale });
  }

  if (input.fix) {
    ctx.fillStyle = 'rgba(204,0,0,0.12)';
    ctx.beginPath();
    ctx.arc(X(here), Y(here), Math.max(4, input.accuracyM * scale), 0, Math.PI * 2);
    ctx.fill();
  }
  const h = (input.headingDeg * Math.PI) / 180;
  ctx.strokeStyle = '#c00';
  ctx.lineWidth = 4;
  ctx.beginPath();
  ctx.moveTo(X(here), Y(here));
  ctx.lineTo(X(here) + Math.sin(h) * 40, Y(here) - Math.cos(h) * 40);
  ctx.stroke();
  ctx.fillStyle = input.fix ? '#c00' : '#fff';
  ctx.beginPath();
  ctx.arc(X(here), Y(here), 9, 0, Math.PI * 2);
  ctx.fill();
  ctx.stroke();
}

// A timer rather than requestAnimationFrame so walking keeps going in a background tab.
function tick() {
  const t = performance.now();
  const dt = lastFrame ? Math.min(0.25, (t - lastFrame) / 1000) : 0;
  lastFrame = t;
  if (walking && prep) {
    const next = Number(el.progress.value) + WALK_SPEED * Number(el.speed.value) * dt;
    if (next >= Number(el.progress.max)) setWalking(false);
    el.progress.value = Math.min(next, Number(el.progress.max)).toFixed(1);
    update();
  }
  drawScreen(screenCtx, result?.state, t);
}

el.progress.addEventListener('input', update);
el.lateral.addEventListener('input', update);
el.recenter.addEventListener('click', () => { el.lateral.value = 0; update(); });
el.fix.addEventListener('change', update);
el.accuracy.addEventListener('input', update);
el.follow.addEventListener('change', update);
el.closeUp.addEventListener('change', update);
for (const input of [el.heading, el.headingNum]) {
  input.addEventListener('input', () => {
    el.follow.checked = false;
    setHeading(Number(input.value) || 0);
    update();
  });
}
el.walk.addEventListener('click', () => {
  if (!walking && Number(el.progress.value) >= Number(el.progress.max)) el.progress.value = el.progress.min;
  setWalking(!walking);
});
el.restart.addEventListener('click', restart);
el.zoom.addEventListener('change', () => document.body.classList.toggle('zoom', el.zoom.checked));
el.loadSample.addEventListener('click', loadSample);
el.routeFile.addEventListener('change', async () => {
  const file = el.routeFile.files[0];
  if (!file) return;
  try {
    loadRoute(JSON.parse(await file.text()), file.name);
  } catch (err) {
    el.routeStatus.textContent = `Could not read ${file.name}: ${err.message}`;
    el.routeStatus.className = 'hint error';
  }
});

loadSample();
setInterval(tick, 50);
