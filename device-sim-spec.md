# TERRA round-screen simulator — handoff

Build a small local simulator in `device-sim/` so we can rehearse the device's navigation screen before the ESP32 and display arrive. This is separate from the iPhone app in `ios/`; do not change that app or the original Arduino project for this task.

## The first satisfying demo

Load [the sample walking route](ios/Fixtures/sample-route-v1.json). Show a **240 × 240 pixel round device screen** beside a simple route map and controls. Drag a position slider from start to destination; turn a compass-heading control. The screen changes from **Go to start** to a direction arrow and distance, shows a turn arriving, then **Arrived**. A small event log says when a vibration would fire. No hardware or BLE connection is implied.

## Inputs

- Read the existing `RouteV1` JSON: `points` in walking order, `turns[].pointIndex`, `start`, `destination`, and `distanceMeters`. Keep it compatible with a route JSON exported by the iPhone app.
- Simulated GPS: route progress slider, plus a draggable position or explicit lateral offset to test being off route. Controls for no fix and poor accuracy.
- Simulated compass heading in degrees, with a visible numeric value for debugging.
- A restart control resets navigation state and event history.

## Behavior to exercise

1. Before a reliable GPS fix, show **Waiting for GPS**. Poor accuracy should stay visibly uncertain; do not imply a precise direction.
2. If the user is far from the route start, show **Go to start**, with distance to the start.
3. Once near the start, guide along the stored route. Pick the next useful path point or turn ahead, compute its bearing from the simulated position, subtract the device heading, and show a relative arrow. Show distance to the next turn and the destination without treating a straight-line distance as the remaining walking distance.
4. Near a turn, show a clear turn state and record a simulated vibration event. Avoid firing the same event continuously.
5. When deliberately moved off the path, show **Off route** and distance to the path. Do not invent a new walking route.
6. At the destination, show **Arrived**. Moving the slider backward or restarting should yield predictable behavior.

Choose and document provisional thresholds for GPS accuracy, start/turn/arrival proximity, and off-route distance. Keep route geometry and navigation decisions in plain functions that can be checked with deterministic examples; the circular rendering should only display the current state. Avoid replaying the 2024 Arduino state machine verbatim: it was written for fixed checkpoints, whereas `RouteV1` contains a walking path and turns.

## Visual boundary

Keep the **simulator controls** plain and utilitarian. The round screen should be sized and clipped like the 1.28-inch, 240 × 240 GC9A01 display in the plan. Start with a readable monochrome arrow, distance, and short state message. The original firmware's bitmap assets in `Arduino Code/Terra/images/` are a reference for what the old device drew, not a required dependency or a final design decision. This task is about seeing whether navigation information makes sense at device scale.

## Deliverable

- A local simulator with a short `device-sim/README.md` containing one run command.
- It loads the sample fixture and accepts another valid `RouteV1` file through a file picker or documented equivalent.
- A few focused checks for geometry and state transitions: no fix, go to start, heading changes, turn proximity, off route, and arrival.
- A note listing what is simulated and what still needs the physical display, GPS, compass, and haptic motor to verify.

The simulator is complete when we can narrate a full walk through those states without touching the iPhone app or claiming that its mock transfer reaches a real device.
