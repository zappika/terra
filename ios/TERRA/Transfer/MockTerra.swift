import Foundation

/// The device side of the transfer protocol, as the firmware should behave:
/// reassemble chunks, check length and CRC, decode and validate, then report `stored`.
nonisolated final class MockTerraFirmware {
    private(set) var storedRoute: RouteV1?
    private var pending: (id: UUID, length: Int, chunkCount: Int, crc: UInt32, body: Data, nextChunk: Int)?

    static let maxRouteBytes = 256 * 1024

    func handle(_ data: Data) -> TerraPacket {
        guard let packet = TerraPacket(data) else { return .error(code: .badPacket) }
        switch packet {
        case let .begin(id, length, count, crc):
            guard Int(length) <= Self.maxRouteBytes else { return .error(code: .tooLarge) }
            pending = (id, Int(length), Int(count), crc, Data(), 0)
            return .ack(type: TerraPacket.Kind.begin.rawValue, index: 0)

        case let .chunk(index, payload):
            guard var p = pending else { return .error(code: .unexpected) }
            guard Int(index) == p.nextChunk else { return .error(code: .outOfOrder) }
            p.body.append(payload)
            p.nextChunk += 1
            guard p.body.count <= p.length else { return .error(code: .tooLarge) }
            pending = p
            return .ack(type: TerraPacket.Kind.chunk.rawValue, index: index)

        case let .commit(id):
            guard let p = pending, p.id == id, p.nextChunk == p.chunkCount, p.body.count == p.length else {
                return .error(code: .unexpected)
            }
            pending = nil
            guard CRC32.checksum(p.body) == p.crc else { return .error(code: .checksum) }
            guard let route = try? RouteV1.makeDecoder().decode(RouteV1.self, from: p.body),
                  route.id == id, RouteValidator.validate(route).isEmpty else {
                return .error(code: .invalidRoute)
            }
            storedRoute = route
            return .stored(routeID: id, crc32: p.crc)

        case .ack, .stored, .error:
            return .error(code: .unexpected)
        }
    }
}

/// How the mock behaves, so every UI state can be tried without hardware.
enum MockTerraBehavior: String, CaseIterable, Identifiable {
    case works
    case notFound
    case dropsConnection
    case neverConfirms

    var id: String { rawValue }

    var label: String {
        switch self {
        case .works: "Stores the route"
        case .notFound: "Not found"
        case .dropsConnection: "Disconnects during transfer"
        case .neverConfirms: "Never confirms storage"
        }
    }
}

final class MockTerraLink: TerraLink {
    let name = "Mock TERRA"
    let maxPacketLength = 180
    let firmware = MockTerraFirmware()
    var behavior: MockTerraBehavior
    var packetDelay: Duration
    private var packetsSeen = 0

    init(behavior: MockTerraBehavior = .works, packetDelay: Duration = .milliseconds(25)) {
        self.behavior = behavior
        self.packetDelay = packetDelay
    }

    func exchange(_ packet: Data) async throws -> Data {
        if packetDelay > .zero { try await Task.sleep(for: packetDelay) }
        packetsSeen += 1
        if behavior == .dropsConnection, packetsSeen > 6 { throw TransferFailure.connectionLost }
        let reply = firmware.handle(packet)
        if behavior == .neverConfirms, case .stored = reply { throw TransferFailure.timedOut }
        return reply.encoded()
    }

    func disconnect() {}
}

struct MockTerraScanner: TerraScanner {
    var behavior: MockTerraBehavior
    var searchDelay: Duration = .seconds(1.5)

    func connect() async throws -> TerraLink {
        try await Task.sleep(for: searchDelay)
        if behavior == .notFound { throw TransferFailure.notFound }
        return MockTerraLink(behavior: behavior)
    }
}
