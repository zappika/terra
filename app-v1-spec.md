# TERRA iPhone app — v1 handoff

This is the build spec for the first native iPhone app. The [two-screen sketch](design/app-v1-screens.svg) shows the intended feel. Build the app in a new `ios/` directory; leave the 2024 web app and Arduino code untouched until the device interface is ready.

## The promise

Find a destination while holding the phone. Check a **walking route**, send it to TERRA, and put the phone away. TERRA then navigates with its own GPS and compass. The app prepares the walk; it does not need to run during it.

For v1, this is a **single-destination walking route**. No accounts, saved collections, AI prompts, custom loops, live phone tracking, or on-device rerouting.

## Two ways in

1. **Search in TERRA — required.** Search for an address or place with MapKit. Choose a result. Use the phone's current location as the start. Ask MapKit for walking directions and open the Route preview.
2. **Share from Apple Maps — desired, subject to a short technical spike.** Apple Maps has a route Share action. Add a share extension for URLs if the shared item exposes a usable Apple Maps URL. Accept both `maps.apple.com` links and shortened `maps.apple` links (the latter may need redirect resolution). Extract the destination, then calculate a *new* walking route from the phone's current location in TERRA. Show the Route preview before sending.

**Important:** A Maps share link is not a documented export of the selected `MKRoute` geometry. Do not claim that the exact path selected in Apple Maps transfers to TERRA. The import is a convenient way to bring in a destination. The app must label its own calculated route clearly. If the share payload or destination cannot be read, offer a search field with a plain explanation; never silently pick a place. Test the real share sheet on an iPhone early. If Apple Maps does not expose a reliable item to the extension, keep in-app search as the v1 path and document what was observed.

## Screen 1 — Find a place

- A map treated as a surface the route can grow across. A prominent search field says **Where are we going?** The surrounding art can feel soft, strange, and handmade; the actual search result stays legible.
- As the user types, show MapKit place/address suggestions. On selection, center the map and calculate a walking route.
- A small **My position** control returns the map to the user's position. Decorative marks may surround the map, but fake coordinates or fake instrument readings should not appear.
- On first use, ask for location permission only when it is needed to calculate a route. If denied, explain why a start point is needed and offer a way to try permission again or choose a start point manually.
- If opened from a successful Apple Maps share, skip typing and proceed to Route preview after calculating.

## Screen 2 — Route preview

- Show the entire route on the map, with clear start and destination markers. Keep the actual route visible above the bottom sheet.
- A lower, soft-edged route area: destination name and address, **Walking**, distance, estimated time, and start point. Show the chosen route as **TERRA route** so an Apple Maps import is not mistaken for an exact copy.
- Primary action: **Send to TERRA**. If no device is connected, this opens a compact connection sheet with **Find TERRA**, connection state, and retry. During transfer show progress; finish only after the device confirms that it stored the route.
- Secondary action: **Change destination**. Before hardware is available, a development-only **Export route JSON** action may help test the route model; it should not pretend that the device received anything.
- If directions fail or the route is empty, explain the problem and offer **Try again** or **Change destination**. Do not enable Send.

## Visual direction — organic and alien

TERRA is a little art object with a navigation function. The supplied references are the centre of this direction: the first image shows black, hand-drawn creature/flower/splatter marks with uneven edges and holes of negative space; the second shows soft, almost living objects in pink, stone, and translucent glowing green. The subculture feeling comes from odd personal symbols, worn print, charms, colour, and humour. It should feel found at an experimental music show or carried as a talisman, not issued as equipment. Draw original marks and forms; do not trace the supplied symbols or copy logos, posters, or album artwork.

- **Palette and material:** ink black `#171614`, warm bone `#F2EFE7`, translucent acid green `#B9EA70`, deep plum `#44233F`, fleshy pink `#C96193`, and occasional tarnished silver `#AAA7A0`. Dark areas can glow, but give them warm, tactile surroundings. The app need not be uniformly dark.
- **Type:** expressive, slightly awkward display lettering paired with a clean readable face for addresses, distance, and actions. Try swollen or stretched letterforms and imperfect registration in the artwork. Avoid military stencil, all-caps telemetry, serial numbers, and dashboard microtype.
- **Marks:** invent a small family of organic glyphs: seed/eye, mushroom/flower, tendril, cell cluster. Use irregular painted edges, open holes, dots, and grain. Some marks can seem to grow along a route. Each has character; none needs to decode as a navigation instruction.
- **Shape:** soft asymmetry, bulges, puddles, hand-cut edges, translucent plastic, glossy light trapped beneath a skin. A route line may look luminous and alive, but must still trace the actual walking path accurately.
- **Motion:** a mark can slowly breathe or a route can gently appear. No radar sweep, scanning grid, constant flicker, or attention-grabbing animation. Respect Reduce Motion and battery life.
- **Voice:** human and slightly mysterious. **Where are we going?**, **A way through**, **Send to TERRA**, **TERRA has it** are starting points. Let the images carry the weirdness; the action and recovery words can be plain.

The sketch is a visual direction, not pixel-perfect layout. Use native SwiftUI behavior, Dynamic Type, VoiceOver labels, and strong contrast for functional text. Put atmosphere around the decisions, not over them. The screen should still make the destination, walking route, and transfer result easy to understand.

## Navigation data and Bluetooth boundary

- Use `MKLocalSearch` or `MKLocalSearchCompleter` for search; `MKDirections` with `.walking` for routing. Extract the selected `MKRoute` geometry, distance, expected travel time, and step information.
- Keep an app-level `RouteV1` model independent of MapKit: version, route ID, name, start and destination coordinates, route points, turn markers, distance, and creation time. Store coordinates as a stable numeric format, not formatted address strings. Save a sample route fixture in the repo.
- Simplify the route for the device **without deleting turns or path bends needed for navigation**. Validate finite coordinates, nonempty geometry, sensible order, and destination proximity before Send.
- Define one versioned BLE service between app and firmware. Split payloads into chunks, check acknowledgments, and confirm that the device has saved the complete route. A connection or completed write alone is not success. Keep the transport behind a protocol so a mock device can exercise the UI before hardware arrives.
- The app shows the exact route it sends. The device navigates from that stored route after the phone disconnects. If the user begins far from its start, the device should show **Go to start** rather than assume the walk has begun.

## States worth designing, even if they share a screen

Searching; resolving a shared link; calculating; route ready; location denied; no walking route; searching for device; transferring; route received; failed transfer. Every failure must leave the user able to retry or change destination.

## Done when

- A person can search an address, preview a walking route and its distance/time, and choose another destination.
- A shared Apple Maps route or place link imports its destination **if the real iPhone share-sheet spike proves feasible**; the app recalculates and previews its own route.
- The route preview does not claim a successful transfer until a mock or real TERRA acknowledges storage.
- The app can export a `RouteV1` fixture for firmware work, and the same fixture can be replayed in a mock-device test.
- The app builds and runs on the developer's iPhone. Search, permission denial, no-route, and transfer failure have visible, usable outcomes.

## Build order for Claude

1. Create a small SwiftUI iOS project in `ios/` with Search and Route preview, using MapKit and Core Location. Prove a real walking route on an iPhone.
2. Add `RouteV1`, validation, sample fixture, and a mock transfer service. Make the connection sheet and success/failure states work without hardware.
3. Run the Apple Maps share-sheet spike on a device. Inspect the actual shared item and URL. Add the share extension if reliable; record the exact supported and unsupported cases in the repo.
4. Add Core Bluetooth transport against the agreed firmware service once its UUIDs and packet format are defined. Verify complete-route acknowledgment on hardware.

## Source notes

- [Apple Maps route sharing](https://support.apple.com/en-lamr/guide/iphone/iph1b3553719/ios)
- [Unified Maps URLs and shortened links](https://developer.apple.com/documentation/mapkit/unified-map-urls)
- [MapKit search](https://developer.apple.com/documentation/mapkit/mklocalsearch), [walking directions](https://developer.apple.com/documentation/mapkit/mkdirections), and [route geometry](https://developer.apple.com/documentation/mapkit/mkroute)
- [Share-extension item providers](https://developer.apple.com/documentation/foundation/nsitemprovider)
