# Apple Maps share-sheet spike (build order step 3)

**Status: not run yet.** This needs a real iPhone; the simulator's share sheet doesn't reflect what Apple Maps hands to extensions. Until it's done, in-app search is the only way in, and that's the v1 path.

## What to find out

On the iPhone, in Apple Maps:

1. Open a place → Share. Which item types does the share sheet offer an extension? (`public.url`, `public.plain-text`, `com.apple.mapkit.map-item`, a `.vcf`?)
2. Plan a walking route → Share the route. Same question.
3. For each, record the exact URL: `maps.apple.com/?…` (which parameters: `q`, `ll`, `daddr`, `address`, `auid`, `place-id`?) or a shortened `maps.apple/p/…` link that needs a redirect.
4. Does the route share expose the destination coordinate, only an address string, or nothing usable?

## Plan once we know

- Add a share extension that accepts URLs, resolves `maps.apple` short links by following the redirect, and extracts the destination (coordinate first, then address via `MKLocalSearch`).
- Hand the destination to the app (app group + URL scheme), recalculate a **new** walking route from the current location, and show Route preview labelled **TERRA route**. Never imply the Apple Maps route geometry was copied.
- If nothing usable comes through, open the app on search with a plain explanation; never silently pick a place.

## Results

_Fill in after testing on the device: iOS version, item types seen, example URLs, what worked, what didn't._
