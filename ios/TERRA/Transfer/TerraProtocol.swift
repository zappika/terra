import Foundation

/// Draft v1 of the app↔TERRA route transfer. See ios/docs/terra-ble-protocol.md.
/// Every packet starts with [protocolVersion, type]; integers are little-endian.
nonisolated enum TerraPacket: Equatable, Sendable {
    static let protocolVersion: UInt8 = 1

    /// App → device: a route of `totalLength` bytes follows in `chunkCount` chunks.
    case begin(routeID: UUID, totalLength: UInt32, chunkCount: UInt16, crc32: UInt32)
    /// App → device: one slice of the route JSON.
    case chunk(index: UInt16, payload: Data)
    /// App → device: all chunks sent; verify and save.
    case commit(routeID: UUID)
    /// Device → app: the packet was accepted. `index` is the chunk index, or 0.
    case ack(type: UInt8, index: UInt16)
    /// Device → app: the complete route is verified and saved to flash.
    case stored(routeID: UUID, crc32: UInt32)
    /// Device → app: the packet was rejected.
    case error(code: ErrorCode)

    enum Kind: UInt8 { case begin = 0x01, chunk = 0x02, commit = 0x03, ack = 0x81, stored = 0x82, error = 0xE0 }

    enum ErrorCode: UInt8, Sendable {
        case badPacket = 1, unexpected = 2, outOfOrder = 3, checksum = 4, tooLarge = 5, invalidRoute = 6, storage = 7
    }

    var kind: Kind {
        switch self {
        case .begin: .begin
        case .chunk: .chunk
        case .commit: .commit
        case .ack: .ack
        case .stored: .stored
        case .error: .error
        }
    }

    func encoded() -> Data {
        var d = Data([Self.protocolVersion, kind.rawValue])
        switch self {
        case let .begin(id, length, count, crc):
            d.append(uuid: id); d.append(le: length); d.append(le: count); d.append(le: crc)
        case let .chunk(index, payload):
            d.append(le: index); d.append(payload)
        case let .commit(id):
            d.append(uuid: id)
        case let .ack(type, index):
            d.append(type); d.append(le: index)
        case let .stored(id, crc):
            d.append(uuid: id); d.append(le: crc)
        case let .error(code):
            d.append(code.rawValue)
        }
        return d
    }

    init?(_ data: Data) {
        var r = ByteReader(data)
        guard r.u8() == Self.protocolVersion, let raw = r.u8(), let kind = Kind(rawValue: raw) else { return nil }
        switch kind {
        case .begin:
            guard let id = r.uuid(), let len = r.u32(), let count = r.u16(), let crc = r.u32() else { return nil }
            self = .begin(routeID: id, totalLength: len, chunkCount: count, crc32: crc)
        case .chunk:
            guard let index = r.u16() else { return nil }
            self = .chunk(index: index, payload: r.rest())
        case .commit:
            guard let id = r.uuid() else { return nil }
            self = .commit(routeID: id)
        case .ack:
            guard let type = r.u8(), let index = r.u16() else { return nil }
            self = .ack(type: type, index: index)
        case .stored:
            guard let id = r.uuid(), let crc = r.u32() else { return nil }
            self = .stored(routeID: id, crc32: crc)
        case .error:
            guard let code = r.u8().flatMap(ErrorCode.init) else { return nil }
            self = .error(code: code)
        }
    }
}

nonisolated enum CRC32 {
    private static let table: [UInt32] = (0..<256).map { i in
        (0..<8).reduce(UInt32(i)) { c, _ in c & 1 == 1 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1 }
    }

    /// IEEE 802.3 / zlib CRC-32, the same as `esp_crc32_le` on ESP32.
    static func checksum(_ data: Data) -> UInt32 {
        ~data.reduce(~UInt32(0)) { table[Int(($0 ^ UInt32($1)) & 0xFF)] ^ ($0 >> 8) }
    }
}

nonisolated private extension Data {
    mutating func append<T: FixedWidthInteger>(le value: T) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }

    mutating func append(uuid: UUID) {
        Swift.withUnsafeBytes(of: uuid.uuid) { append(contentsOf: $0) }
    }
}

nonisolated private struct ByteReader {
    let bytes: [UInt8]
    var offset = 0
    init(_ data: Data) { bytes = [UInt8](data) }

    mutating func take(_ n: Int) -> [UInt8]? {
        guard offset + n <= bytes.count else { return nil }
        defer { offset += n }
        return Array(bytes[offset..<offset + n])
    }

    mutating func u8() -> UInt8? { take(1)?[0] }
    mutating func u16() -> UInt16? { take(2).map { UInt16($0[0]) | UInt16($0[1]) << 8 } }
    mutating func u32() -> UInt32? { take(4).map { $0.enumerated().reduce(0) { $0 | UInt32($1.element) << (8 * $1.offset) } } }
    mutating func uuid() -> UUID? {
        guard let b = take(16) else { return nil }
        return UUID(uuid: (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]))
    }
    mutating func rest() -> Data { defer { offset = bytes.count }; return Data(bytes[offset...]) }
}
