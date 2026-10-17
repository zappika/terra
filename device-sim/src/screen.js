// Renders a navigation `state` onto the 240 × 240 round display. Display only: no decisions here.

export const SIZE = 240;
const C = SIZE / 2;
const FONT = '"Helvetica Neue", Helvetica, Arial, sans-serif';

export function formatDistance(m) {
  if (m >= 1000) return `${(m / 1000).toFixed(1)} km`;
  if (m >= 50) return `${Math.round(m / 5) * 5} m`;
  return `${Math.round(m)} m`;
}

function text(ctx, str, y, size, weight = 'bold') {
  ctx.font = `${weight} ${size}px ${FONT}`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText(str, C, y);
}

function rotated(ctx, deg, cy, draw) {
  ctx.save();
  ctx.translate(C, cy);
  ctx.rotate((deg * Math.PI) / 180);
  draw();
  ctx.restore();
}

const ARROW = [[0, -46], [30, -8], [11, -8], [11, 38], [-11, 38], [-11, -8], [-30, -8]];

function arrow(ctx, deg, cy, outline = false) {
  rotated(ctx, deg, cy, () => {
    ctx.beginPath();
    ARROW.forEach(([x, y], i) => (i ? ctx.lineTo(x, y) : ctx.moveTo(x, y)));
    ctx.closePath();
    if (outline) {
      ctx.lineWidth = 4;
      ctx.lineJoin = 'round';
      ctx.stroke();
    } else ctx.fill();
  });
}

function turnGlyph(ctx, direction, cy) {
  ctx.save();
  ctx.translate(C, cy);
  if (direction === 'left') ctx.scale(-1, 1);
  ctx.lineWidth = 16;
  ctx.lineJoin = 'round';
  ctx.beginPath();
  if (direction === 'ahead') {
    ctx.moveTo(0, 42);
    ctx.lineTo(0, -16);
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(-26, -14);
    ctx.lineTo(0, -46);
    ctx.lineTo(26, -14);
  } else {
    ctx.moveTo(-18, 42);
    ctx.lineTo(-18, -8);
    ctx.lineTo(18, -8);
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(14, -36);
    ctx.lineTo(46, -8);
    ctx.lineTo(14, 20);
  }
  ctx.closePath();
  ctx.fill();
  ctx.restore();
}

function wedge(ctx, deg, spread, cy) {
  if (spread >= 360) {
    ctx.setLineDash([6, 8]);
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.arc(C, cy, 40, 0, Math.PI * 2);
    ctx.stroke();
    ctx.setLineDash([]);
    text(ctx, '?', cy, 40);
    return;
  }
  const a = ((deg - 90) * Math.PI) / 180;
  const h = ((spread / 2) * Math.PI) / 180;
  ctx.beginPath();
  ctx.moveTo(C, cy);
  ctx.arc(C, cy, 58, a - h, a + h);
  ctx.closePath();
  ctx.fillStyle = '#777';
  ctx.fill();
  ctx.lineWidth = 2;
  ctx.setLineDash([4, 4]);
  ctx.stroke();
  ctx.setLineDash([]);
  ctx.fillStyle = '#fff';
}

export function drawScreen(ctx, state, timeMs = 0) {
  ctx.save();
  ctx.clearRect(0, 0, SIZE, SIZE);
  ctx.beginPath();
  ctx.arc(C, C, C, 0, Math.PI * 2);
  ctx.clip();
  ctx.fillStyle = '#000';
  ctx.fillRect(0, 0, SIZE, SIZE);
  ctx.fillStyle = '#fff';
  ctx.strokeStyle = '#fff';

  const glyphY = 110;
  switch (state?.mode) {
    case 'waiting': {
      ctx.lineWidth = 3;
      ctx.setLineDash([10, 12]);
      ctx.lineDashOffset = -timeMs / 40;
      ctx.beginPath();
      ctx.arc(C, C, 92, 0, Math.PI * 2);
      ctx.stroke();
      ctx.setLineDash([]);
      text(ctx, 'Waiting', C - 14, 28);
      text(ctx, 'for GPS', C + 18, 28);
      break;
    }
    case 'uncertain':
      text(ctx, 'WEAK GPS', 52, 15);
      wedge(ctx, state.relDeg, state.spreadDeg, glyphY);
      text(ctx, `±${Math.round(state.accuracyM)} m`, 178, 30);
      text(ctx, `~${formatDistance(state.approxDistanceM)} ${state.started ? 'to go' : 'to start'}`, 206, 13, 'normal');
      break;
    case 'goToStart':
      text(ctx, 'GO TO START', 52, 15);
      arrow(ctx, state.relDeg, glyphY);
      text(ctx, formatDistance(state.distanceM), 178, 34);
      break;
    case 'guiding':
      text(ctx, state.toTurnM == null ? 'DESTINATION' : 'NEXT TURN', 52, 15);
      arrow(ctx, state.relDeg, glyphY);
      text(ctx, formatDistance(state.toTurnM ?? state.remainingM), 178, 34);
      if (state.toTurnM != null) text(ctx, `${formatDistance(state.remainingM)} to go`, 206, 13, 'normal');
      break;
    case 'turn':
      ctx.lineWidth = 8;
      ctx.beginPath();
      ctx.arc(C, C, C - 4, 0, Math.PI * 2);
      ctx.stroke();
      text(ctx, state.direction === 'ahead' ? 'CONTINUE' : `TURN ${state.direction.toUpperCase()}`, 52, 17);
      turnGlyph(ctx, state.direction, glyphY);
      text(ctx, formatDistance(state.toTurnM), 178, 34);
      break;
    case 'offRoute':
      text(ctx, 'OFF ROUTE', 52, 17);
      arrow(ctx, state.relDeg, glyphY, true);
      text(ctx, formatDistance(state.distanceToPathM), 178, 34);
      text(ctx, 'to path', 206, 13, 'normal');
      break;
    case 'arrived':
      ctx.lineWidth = 12;
      ctx.lineCap = 'round';
      ctx.lineJoin = 'round';
      ctx.beginPath();
      ctx.moveTo(C - 34, glyphY);
      ctx.lineTo(C - 8, glyphY + 26);
      ctx.lineTo(C + 36, glyphY - 24);
      ctx.stroke();
      text(ctx, 'Arrived', 178, 32);
      break;
    default:
      text(ctx, 'No route', C, 20, 'normal');
  }
  ctx.restore();
}
