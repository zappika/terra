# TERRA route transfer protocol — draft v1

The app and firmware share this so the mock device and the real TERRA behave the same way. Nothing here is final until the firmware side agrees; the BLE service and characteristic UUIDs are **not defined yet**.

Implemented in the app by `TERRA/Transfer/TerraProtocol.swift` (packets), `TerraLink.swift` (sender) and `MockTerra.swift` (`MockTerraFirmware` is the reference device behaviour).

## Transport (to agree)

- One GATT service, e.g. `TERRA Route v1`, with one characteristic the app writes (with response) and the device notifies on. Every app packet gets exactly one device reply packet.
- Packet size: the app uses the negotiated MTU minus ATT overhead. The mock uses 180 bytes.

## Packets

Every packet: `[protocolVersion = 1][type]` followed by the fields below. Integers are little-endian. UUIDs are the 16 raw bytes of the route ID.

| Type | Hex | Direction | Fields |
|---|---|---|---|
| BEGIN | `0x01` | app → device | route UUID (16), total length u32, chunk count u16, CRC-32 u32 |
| CHUNK | `0x02` | app → device | chunk index u16, payload bytes |
| COMMIT | `0x03` | app → device | route UUID (16) |
| ACK | `0x81` | device → app | acknowledged type u8, chunk index u16 (0 for BEGIN) |
| STORED | `0x82` | device → app | route UUID (16), CRC-32 u32 of what was saved |
| ERROR | `0xE0` | device → app | code u8 |

Error codes: `1` bad packet, `2` unexpected packet, `3` chunk out of order, `4` checksum mismatch, `5` too large, `6` route invalid, `7` storage failed.

CRC-32 is IEEE/zlib (`esp_crc32_le` on ESP32). Check value: `"123456789"` → `0xCBF43926`.

## Sequence

1. App sends BEGIN; device clears any pending transfer and replies ACK.
2. App sends CHUNKs in order 0…n-1; device replies ACK with the same index. Out-of-order → ERROR 3.
3. App sends COMMIT. Device checks length and CRC, decodes the JSON, validates it, **writes it to flash**, and only then replies STORED with the route UUID and CRC.
4. The app reports **Route received** only when STORED matches the route it sent. A dropped connection, a missing reply, or any ERROR is a failure, and the UI says the route was not saved.

## Payload

The payload is the compact JSON encoding of `RouteV1` (see `ios/Fixtures/sample-route-v1.json`, pretty-printed there):

- `version` — `1`
- `id` — route UUID string
- `name` — destination name
- `start`, `destination` — `{ "lat", "lon" }` in WGS84 degrees, 6 decimals
- `points` — simplified path in walking order; first point near `start`, last near `destination`
- `turns` — `{ pointIndex, turnDegrees, instruction, distanceFromStartMeters }`; `turnDegrees` is negative for left, positive for right; `instruction` is display text only
- `distanceMeters`, `expectedTravelTimeSeconds`, `createdAt` (ISO 8601)

Simplification keeps every maneuver point and every bend more than 3 m off a straight line, so the device can follow the path, not just the turns.

## Device behaviour after storing

The device navigates from the stored route with its own GPS and compass after the phone disconnects. If the walker is far from `points[0]` when the walk begins, it should show **Go to start** instead of assuming the walk has begun.
