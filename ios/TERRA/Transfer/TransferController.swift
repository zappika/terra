import Foundation
import Observation

/// Connection and transfer state for the Send to TERRA sheet.
@Observable
final class TransferController {
    enum State: Equatable {
        case idle
        case searching
        case transferring(progress: Double)
        case received(RouteReceipt)
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var connectedName: String?
    /// Until Core Bluetooth lands, every TERRA is the mock device.
    var mockBehavior: MockTerraBehavior = .works {
        didSet { disconnect() }
    }

    @ObservationIgnored private var link: TerraLink?
    @ObservationIgnored private var task: Task<Void, Never>?

    var isBusy: Bool {
        switch state {
        case .searching, .transferring: true
        default: false
        }
    }

    /// Connects if needed, then sends. Succeeds only when the device confirms storage.
    func send(_ route: RouteV1) {
        task?.cancel()
        task = Task {
            do {
                let link = try await connectedLink()
                state = .transferring(progress: 0)
                let receipt = try await RouteTransfer.send(route, over: link) { [weak self] p in
                    self?.state = .transferring(progress: p)
                }
                state = .received(receipt)
            } catch is CancellationError {
                state = .idle
            } catch {
                // After any failure, reconnect from scratch next time.
                disconnect()
                state = .failed((error as? TransferFailure)?.message ?? error.localizedDescription)
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        if isBusy { state = .idle }
    }

    func reset() {
        cancel()
        state = .idle
    }

    private func connectedLink() async throws -> TerraLink {
        if let link { return link }
        state = .searching
        let link = try await MockTerraScanner(behavior: mockBehavior).connect()
        self.link = link
        connectedName = link.name
        return link
    }

    private func disconnect() {
        link?.disconnect()
        link = nil
        connectedName = nil
    }
}
