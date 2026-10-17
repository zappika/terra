# TERRA iPhone app

Native SwiftUI app from [app-v1-spec.md](../app-v1-spec.md): search a place, preview a walking route from your location, and send it to TERRA. Standard iOS appearance throughout.

## Status against the spec's build order

1. **Search and Route preview — done.** MapKit search suggestions, real `MKDirections` walking routes, start and destination markers, distance and time, location permission asked only when a route needs it, manual start point when it's denied.
2. **RouteV1, validation, fixture, mock transfer — done.** The connection sheet, progress, **Route received** and failure states all run against a mock device. The mock says "Mock TERRA" everywhere, and the hammer menu lets you make it fail on purpose.
3. **Apple Maps share sheet — spike built, device test pending.** A TERRA share extension records exactly what a share contains and saves it for the hammer menu's **Last shared item** screen. The Apple Maps URL parser is unit-tested but not wired into routing. See [docs/apple-maps-share-spike.md](docs/apple-maps-share-spike.md).
4. **Core Bluetooth — not started.** Waiting on the firmware's service UUIDs. The packet format the mock already speaks is in [docs/terra-ble-protocol.md](docs/terra-ble-protocol.md).

## Run it

```bash
brew install xcodegen   # once
./scripts/xcode.sh      # generates TERRA.xcodeproj (not committed)
open TERRA.xcodeproj
```

Run the **TERRA** scheme on a simulator or your iPhone. In the simulator, set a location with Features › Location, or:

```bash
xcrun simctl location booted set 41.387015,2.170047
```

## Tests

```bash
xcodebuild test -project TERRA.xcodeproj -scheme TERRA -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

They cover Apple Maps link parsing, route simplification (turns and bends survive), validation, the packet format and CRC, and replaying the fixture into the mock device, including dropped connections and missing storage confirmation.

`Fixtures/sample-route-v1.json` is a real Apple Maps walking route (Plaça de Catalunya → Sagrada Família). To regenerate it:

```bash
TEST_RUNNER_TERRA_WRITE_FIXTURE="$PWD/Fixtures/sample-route-v1.json" xcodebuild test -project TERRA.xcodeproj -scheme TERRA -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:'TERRATests/FixtureTests/writeFixtureFromAppleMaps()'
```

On a route preview, **Export Route JSON** (in the Development section) shares the same format for firmware work. Exporting doesn't send anything to TERRA.

## TestFlight

```bash
./scripts/testflight.sh upload
```

This archives a Release build, signs it automatically for team 8D6ML34D52, and uploads it as an internal-testing build. You need an app record in App Store Connect with bundle ID `com.zappika.terra` first. The share extension (`com.zappika.terra.share`) and the App Group `group.com.zappika.terra` are registered by automatic signing. The build number is the commit count, so commit before each upload.

## Layout

- `TERRA/Search` — `PlaceSearch` (MKLocalSearchCompleter) and `Place`
- `TERRA/Location` — `LocationProvider` (one location fix, on demand)
- `TERRA/Routing` — `RouteV1` (MapKit-independent), `RouteBuilder` (simplification and turns), `RouteValidator`, `WalkingDirections` (MapKit), `RoutePlanner` (state)
- `TERRA/Transfer` — packet format, `TerraLink` protocol, `RouteTransfer`, mock device, `TransferController`
- `TERRA/Views` — Find place, Route preview sheet, connection sheet, start point picker, Last shared item (debug)
- `TERRAShare` — share extension (Apple Maps spike)
- `Shared` — compiled into both: `AppleMapsLink` parser, shared-item record, App Group store, redirect follower
