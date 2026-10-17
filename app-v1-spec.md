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

- A dark map surface that feels like a scan rather than a consumer map. A prominent search field says **Enter destination** under the oversized prompt **WHERE TO?**
- As the user types, show MapKit place/address suggestions. On selection, center the map and calculate a walking route.
- A small **MY POSITION** control returns the map to the user's position. A coordinate readout may be present as atmosphere, but it must reflect real data or be labeled as decorative in mockups.
- On first use, ask for location permission only when it is needed to calculate a route. If denied, explain why a start point is needed and offer a way to try permission again or choose a start point manually.
- If opened from a successful Apple Maps share, skip typing and proceed to Route preview after calculating.

## Screen 2 — Route preview

- Show the entire route on the map, with clear start and destination markers. Keep the actual route visible above the bottom sheet.
- A lower information plate: destination name and address, **Walking**, distance, estimated time, and start point. Show the chosen route as **TERRA route** so an Apple Maps import is not mistaken for an exact copy.
- Primary action: **TRANSMIT ROUTE**, with the plain-language subtitle **Send to TERRA**. If no device is connected, this opens a compact connection sheet with **Find TERRA**, connection state, and retry. During transfer show progress; finish only after the device confirms that it stored the route.
- Secondary action: **Change destination**. Before hardware is available, a development-only **Export route JSON** action may help test the route model; it should not pretend that the device received anything.
- If directions fail or the route is empty, explain the problem and offer **Try again** or **Change destination**. Do not enable Send.

## Visual direction — a strange field instrument

TERRA is a small art object with a navigation function. It should feel like a recovered 1990s electronic field instrument: black bag hardware, paranormal signal graphics, worn electronic-band print, after-dark maps, and phosphor light. The user references are 1990s Crumpler, *The X-Files*, and electronic band T-shirts. Draw from their energy, materials, and period texture; do not copy logos, posters, or album artwork.

- **Palette:** near-black `#080D0B`, bruised green-black `#142019`, phosphor chartreuse `#BAF75E`, cold signal cyan `#70E7DF`, bone `#D5D9C5`, and an occasional warning orange `#F36C42`. Most of the screen stays dark. Colour appears like emitted light or ink on worn material.
- **Type:** oversized compressed display words, small monospaced telemetry, visible numbering and labels. Type can feel misregistered or rubbed away in decorative layers. Search results, addresses, distance, and errors remain crisp.
- **Marks:** radar rings, survey crosses, route traces, static grain, halftone, contour lines, stamped codes, and little inexplicable symbols. Give the route a soft glow, like a signal acquired through darkness.
- **Shape:** off-centre composition, hard edges, cut corners, narrow rules, and layered panels. Avoid rounded white cards, generic map pins, cheerful gradients, and dashboard tiles.
- **Motion:** subtle acquisition pulse or brief scan on transition; no constant flicker. Respect Reduce Motion. Grain and glow must not obscure route geometry or drain the phone through continuous animation.
- **Voice:** curious and slightly coded: **WHERE TO?**, **PATH FOUND**, **TRANSMIT ROUTE**, **SIGNAL LOST**. Pair unusual terms with plain explanations when action or recovery matters. This app is allowed to feel strange; the user must still know which route they are sending and whether TERRA received it.

The sketch is a visual direction, not pixel-perfect layout. Use native SwiftUI behavior, Dynamic Type, VoiceOver labels, and high contrast for functional text. This is not a growth funnel or a general-purpose navigation dashboard. There is one meaningful decision per screen.

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
