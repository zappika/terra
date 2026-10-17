# TERRA round-screen simulator

Rehearses the device's navigation screen on a 240 × 240 round display, using a `RouteV1` file and simulated GPS, compass and vibration. No hardware, no BLE, and nothing from the iPhone app's mock transfer reaches a device.

## Run

From the repo root (Node 18+, no install step):

```bash
node device-sim/server.js
```

Open http://localhost:4810. It loads `ios/Fixtures/sample-route-v1.json`. Use **Choose File** to load any other `RouteV1` JSON exported by the iPhone app.

Checks:

```bash
node --test device-sim/test/*.test.js
```

## A walk to narrate

1. Untick **Has fix** → *Waiting for GPS*. Tick it and drag **Accuracy** past ±20 m → *Weak GPS* with a wide wedge instead of an arrow.
2. Accuracy back to ±5 m. Progress starts at −150 m (an approach walk) → *Go to start* with distance.
3. Press **Walk ▶** (or drag **Progress**). Within 30 m of the start: *Route started* vibration, then the first turn.
4. Between turns: arrow plus distance to the next turn, and walking distance left.
5. 30 m before each turn: thick ring, turn glyph, one *double* vibration.
6. Drag **Off-route offset** past 35 m → *Off route*, outline arrow pointing back to the path, distance to it. **Back on path** resumes.
7. At the end → *Arrived*. Dragging backward resumes guidance; **Restart** clears everything.

Untick **Face the walking direction** and turn **Heading** to watch the arrow rotate against the compass.

## Files

- `src/geo.js`, `src/route.js`: route loading, validation and path geometry.
- `src/nav.js`: all navigation decisions, as one pure function `navigate(route, memory, input)`. This is the part meant to inform the firmware.
- `src/screen.js`: draws whatever state `navigate` returns. No decisions.
- `src/app.js`, `index.html`: the simulator controls, map and event log.
- `test/nav.test.js`: no fix, weak GPS, go to start, heading, turn proximity and re-arming, off route with hysteresis, along-path distance, arrival, and a full walk of the sample fixture.

## Provisional thresholds

All live in `THRESHOLDS` in `src/nav.js`. Guesses to tune on a real walk.

| What | Value | Why |
| --- | --- | --- |
| Usable GPS accuracy | ≤ 20 m | Phone-grade GNSS on city streets is usually 5–15 m; worse than 20 m can put you on the wrong side of a block. When accuracy is worse, the device makes no decisions. |
| Start reached | 30 m from the first path point | Covers GPS error plus the gap between `start` and `points[0]`. |
| Turn alert | 30 m before the turn, along the path | About 20 s of walking: enough time to notice the vibration. |
| Turn screen ends | 5 m past the turn | Keeps the turn screen up while you round the corner. |
| Turn re-arm | 60 m back from the turn | Walking back that far lets a turn vibrate again. Stops repeat buzzing from GPS jitter. |
| Off route | over 35 m from the path, back under 20 m | Wider than GPS error so jitter doesn't trigger it. The gap between the two values stops flicker. |
| Arrived | 20 m from the destination, or 20 m of path left | The fixture's path ends about 60 m from `destination`, so the end of the path also counts. |
| Leave arrival | over 50 m away again | Lets you back up predictably without losing *Arrived* to jitter. |
| Arrow target | next path point, at most 40 m ahead | On long straight segments, a closer target corrects sideways drift. |

Vibration patterns are labels only: `short` = started, `double` = turn, `long` = off route, `triple` = arrived.

## Decisions worth knowing

- **Turn direction comes from the path geometry**, matching `turnDegrees` (positive = right, as in `RouteV1.swift`). In the sample fixture, most `instruction` strings disagree with the geometry (for example, "Take a left" at a +64° turn). The debug panel shows both. Worth checking in the iOS route builder.
- **Distances are along the path**, measured on the simplified points. That path is 2,563 m against the route's 2,567 m `distanceMeters`. Straight-line distance is never shown as distance left.
- **Guidance starts only at the route start.** Dragging straight to mid-route after a restart shows *Go to start*, as the spec asks.
- **Position snaps to the nearest segment anywhere on the path.** That's fine for this route, but a loop or out-and-back route could snap to the wrong leg. Firmware should search near the last known progress.
- Moving the slider faster than the alert window can skip a turn's vibration. Real 1 Hz GPS at walking speed can't.

## Simulated here vs. needs hardware

Simulated: GPS position, fix and accuracy (as one number), compass heading, vibration (log and screen shake), screen layout at 240 × 240 pixels.

Still needs the physical parts:

- **GC9A01 display**: real brightness, contrast in sunlight, viewing angle, how the fonts look on the panel, refresh speed of a rotating arrow over SPI.
- **GPS module**: time to first fix, how accuracy is actually reported (HDOP vs. meters), jitter and drift between tall buildings, update rate.
- **Compass (CMPS12)**: calibration, tilt while walking, magnetic interference, declination from magnetic to true north (the simulator assumes true north).
- **Haptic driver + motor**: whether the patterns can be told apart through a pocket or wrist, and how strong they feel.
- Battery, the enclosure, and BLE route transfer from the iPhone are not covered.
