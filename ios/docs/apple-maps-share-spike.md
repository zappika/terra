# Apple Maps share-sheet spike (build order step 3)

**Status: extension built, device test not run yet.** The simulator's share sheet doesn't reflect what Apple Maps hands to extensions, so this needs a real iPhone. Until it's done, in-app search is the only way in, and that's the v1 path. The parsed destination is **not** wired into routing yet.

## What's in the build

- **TERRA share extension** (`TERRAShare`, bundle `com.zappika.terra.share`). It appears as **TERRA** in the share sheet for URLs, plain text, map items (`com.apple.mapkit.map-item`) and vCards. It records:
  - every `NSExtensionItem`: title, content text, `userInfo` keys
  - every attachment's registered type identifiers and suggested name
  - the value loaded for each type identifier (URL as the full string, text, data as UTF-8 or a hex prefix, file URLs read), plus `loadObject(MKMapItem)` when the provider offers it
  - every http(s) URL found in any of that, with `maps.apple` short links followed through their redirects (each hop recorded; if the last page is HTML, its canonical / `og:url` Apple Maps link too)
  - what `AppleMapsLink` parses from each URL
- It shows all of this in the share sheet and saves it to the App Group `group.com.zappika.terra`.
- In the app: hammer menu › **Apple Maps share spike › Last shared item** shows the same record, with **Share as JSON** to get it off the phone. Close the route preview first; the menu can't open a second sheet over it.
- `Shared/AppleMapsLink.swift`: the pure parser, covered by `TERRATests/AppleMapsLinkTests.swift`.

## How to run the test

1. Install the TestFlight build (or run the **TERRA** scheme on the iPhone from Xcode).
2. In Apple Maps, for each case below: Share › TERRA (if TERRA isn't in the row, tap **More** and enable it). Read the screen, then **Share as JSON** and paste it into Results below.
3. Then open TERRA › hammer › Last shared item and check the same record is there (proves the App Group works).

Cases to try:

1. A place (POI) card → Share.
2. A dropped pin → Share.
3. A street address search result → Share.
4. A walking route (directions to a place) → Share the route.
5. A walking route to a dropped pin → Share.
6. Anything shared to Messages from Maps and then shared on from Messages (link-only case).

For each, record: which item types appear, whether a URL appears and what it is, whether it's a `maps.apple/p/…` short link, where its redirects land, and what the parser says.

## Parser: expected cases

What `AppleMapsLink.parse` returns today. Source and `saddr` are always ignored: TERRA routes from the phone's current location and never claims to copy the Apple Maps route geometry.

| Link | Result |
| --- | --- |
| `maps.apple.com/?ll=LAT,LON&q=Name` | coordinate + name |
| `maps.apple.com/?address=…&auid=ID&ll=LAT,LON&q=Name` | coordinate + name + place ID (coordinate beats address) |
| `maps.apple.com/place?coordinate=LAT,LON&name=Name&place-id=ID` | coordinate + name + place ID |
| `maps.apple.com/?address=…` | address (geocode it) |
| `maps.apple.com/place?place-id=ID` (no coordinate or address) | place ID (resolve with MapKit) |
| `maps.apple.com/?q=coffee`, `/search?query=…`, `q` + `sll` | **search query only**: prefill search, user chooses |
| `maps.apple.com/?q=LAT,LON` | coordinate |
| `maps.apple.com/?saddr=…&daddr=Address&dirflg=w` | address (from `daddr`) |
| `maps.apple.com/?saddr=…&daddr=LAT,LON` | coordinate (from `daddr`) |
| `maps.apple.com/directions?source=…&destination=LAT,LON&mode=walking` | coordinate (from `destination`) |
| directions link with no `daddr` / `destination` | unusable |
| `maps.apple/p/…`, `maps.apple.com/p/…` | short link: follow redirect, parse the final URL |
| `maps.apple.com/` with no usable parameters, or invalid coordinates and nothing else | unusable |
| any other host (Google Maps, `maps://`, look-alike hosts) | not Apple Maps |
| shared text containing one of the above | the first Apple Maps link in the text |

Coordinates must be finite, latitude −90…90, longitude −180…180. Empty parameters count as missing.

## Plan once we know

- If a usable item comes through reliably: hand the destination to the app (App Group + URL scheme), resolve address / place ID with MapKit, recalculate a **new** walking route from the current location, and show Route preview labelled **TERRA route**. Never imply the Apple Maps route geometry was copied.
- If nothing usable comes through, open the app on search with a plain explanation; never silently pick a place. A search-query-only link prefills search and stops there.
- If Apple Maps doesn't expose a reliable item, keep in-app search as the v1 path and record what was seen here.

## Results

_Fill in after testing on the device: iOS version, item types seen, example URLs, what worked, what didn't. Add every real URL to `AppleMapsLinkTests`._
