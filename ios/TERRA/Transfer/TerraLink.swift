import Foundation

/// A transport to one TERRA. Core Bluetooth and the mock device both implement this,
/// so the transfer logic and UI never know which one they are talking to.
protocol TerraLink: AnyObject {
    var name: String { get }
    /// Largest packet the link can carry in one write.
    var maxPacketLength: Int { get }
    /// Writes one packet and waits for the device's reply packet.
    func exchange(_ packet: Data) async throws -> Data
    func disconnect()
}

/// Finds and connects to a nearby TERRA.
protocol TerraScanner {
    func connect() async throws -> TerraLink
}

enum TransferFailure: Error, Equatable {
    case notFound
    case connectionLost
    case timedOut
    case rejected(TerraPacket.ErrorCode)
    case unexpectedReply
    case notConfirmed

    var message: String {
        switch self {
        case .notFound: "No TERRA found nearby. Make sure it's on and close to your phone."
        case .connectionLost: "The connection to TERRA was lost before it saved the route."
        case .timedOut: "TERRA stopped responding before it saved the route."
        case .rejected(let code): "TERRA rejected the route (\(code)) and didn't save it."
        case .unexpectedReply: "TERRA sent an unexpected reply and didn't confirm the route."
        case .notConfirmed: "TERRA didn't confirm that it saved this route."
        }
    }
}

/// The device's confirmation that it stored a specific route.
struct RouteReceipt: Equatable {
    var routeID: UUID
    var deviceName: String
    var byteCount: Int
}

/// Sends a `RouteV1` in chunks and succeeds only on a matching `stored` reply.
enum RouteTransfer {
    static func send(_ route: RouteV1, over link: TerraLink, progress: (Double) -> Void) async throws -> RouteReceipt {
        let body = try route.jsonData()
        let crc = CRC32.checksum(body)
        let chunkSize = link.maxPacketLength - 4 // version, type, u16 index
        let chunks = stride(from: 0, to: body.count, by: chunkSize).map { body[$0..<min($0 + chunkSize, body.count)] }
        guard chunks.count <= Int(UInt16.max) else { throw TransferFailure.rejected(.tooLarge) }

        progress(0)
        try await expectAck(.begin, index: 0, from: link.exchange(
            TerraPacket.begin(routeID: route.id, totalLength: UInt32(body.count), chunkCount: UInt16(chunks.count), crc32: crc).encoded()
        ))
        for (i, chunk) in chunks.enumerated() {
            try Task.checkCancellation()
            try await expectAck(.chunk, index: UInt16(i), from: link.exchange(
                TerraPacket.chunk(index: UInt16(i), payload: Data(chunk)).encoded()
            ))
            progress(Double(i + 1) / Double(chunks.count + 1))
        }

        let reply = try await link.exchange(TerraPacket.commit(routeID: route.id).encoded())
        switch TerraPacket(reply) {
        case .stored(let id, let storedCRC) where id == route.id && storedCRC == crc:
            progress(1)
            return RouteReceipt(routeID: id, deviceName: link.name, byteCount: body.count)
        case .stored: throw TransferFailure.notConfirmed
        case .error(let code): throw TransferFailure.rejected(code)
        default: throw TransferFailure.unexpectedReply
        }
    }

    private static func expectAck(_ kind: TerraPacket.Kind, index: UInt16, from reply: Data) throws {
        switch TerraPacket(reply) {
        case .ack(kind.rawValue, index): return
        case .error(let code): throw TransferFailure.rejected(code)
        default: throw TransferFailure.unexpectedReply
        }
    }
}
