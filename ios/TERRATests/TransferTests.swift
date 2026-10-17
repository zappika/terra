import Foundation
import Testing
@testable import TERRA

struct ProtocolTests {
    @Test func packetsRoundTrip() {
        let id = UUID()
        let packets: [TerraPacket] = [
            .begin(routeID: id, totalLength: 12_345, chunkCount: 70, crc32: 0xDEAD_BEEF),
            .chunk(index: 513, payload: Data("hello".utf8)),
            .commit(routeID: id),
            .ack(type: 0x02, index: 513),
            .stored(routeID: id, crc32: 0x0102_0304),
            .error(code: .checksum),
        ]
        for packet in packets {
            #expect(TerraPacket(packet.encoded()) == packet)
        }
    }

    @Test func crcMatchesZlib() {
        // Standard check value for CRC-32/ISO-HDLC.
        #expect(CRC32.checksum(Data("123456789".utf8)) == 0xCBF4_3926)
    }
}

struct MockTransferTests {
    @Test func fixtureReplaysIntoMockDevice() async throws {
        let route = try loadFixture()
        let link = MockTerraLink(packetDelay: .zero)
        var progress: [Double] = []
        let receipt = try await RouteTransfer.send(route, over: link) { progress.append($0) }
        #expect(receipt.routeID == route.id)
        #expect(link.firmware.storedRoute == route)
        #expect(progress.last == 1)
        #expect(progress == progress.sorted())
    }

    @Test func dropsConnectionWithoutClaimingSuccess() async throws {
        let route = try loadFixture()
        let link = MockTerraLink(behavior: .dropsConnection, packetDelay: .zero)
        await #expect(throws: TransferFailure.connectionLost) {
            _ = try await RouteTransfer.send(route, over: link) { _ in }
        }
        #expect(link.firmware.storedRoute == nil)
    }

    @Test func missingStorageConfirmationIsAFailure() async throws {
        let route = try loadFixture()
        let link = MockTerraLink(behavior: .neverConfirms, packetDelay: .zero)
        await #expect(throws: TransferFailure.timedOut) {
            _ = try await RouteTransfer.send(route, over: link) { _ in }
        }
    }

    @Test func firmwareRejectsCorruptedData() throws {
        let route = try loadFixture()
        let body = try route.jsonData()
        let firmware = MockTerraFirmware()
        _ = firmware.handle(TerraPacket.begin(routeID: route.id, totalLength: UInt32(body.count), chunkCount: 1, crc32: CRC32.checksum(body) ^ 1).encoded())
        _ = firmware.handle(TerraPacket.chunk(index: 0, payload: body).encoded())
        #expect(firmware.handle(TerraPacket.commit(routeID: route.id).encoded()) == .error(code: .checksum))
        #expect(firmware.storedRoute == nil)
    }

    @Test func firmwareRejectsOutOfOrderChunks() throws {
        let firmware = MockTerraFirmware()
        _ = firmware.handle(TerraPacket.begin(routeID: UUID(), totalLength: 10, chunkCount: 2, crc32: 0).encoded())
        #expect(firmware.handle(TerraPacket.chunk(index: 1, payload: Data([1])).encoded()) == .error(code: .outOfOrder))
    }
}
