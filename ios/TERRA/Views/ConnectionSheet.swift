import SwiftUI

/// Finds TERRA, sends the route and shows progress until the device confirms storage.
struct ConnectionSheet: View {
    var route: RouteV1
    @Environment(TransferController.self) private var transfer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                status
                Spacer(minLength: 0)
                actions
            }
            .padding()
            .navigationTitle("Send to TERRA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isDone {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            transfer.cancel()
                            dismiss()
                        }
                    }
                }
            }
        }
        .interactiveDismissDisabled(transfer.isBusy)
        .onAppear {
            if !transfer.isBusy { transfer.reset() }
            // Already connected: go straight to the transfer.
            if transfer.connectedName != nil { transfer.send(route) }
        }
    }

    private var isDone: Bool {
        if case .received(let receipt) = transfer.state { receipt.routeID == route.id } else { false }
    }

    @ViewBuilder private var status: some View {
        switch transfer.state {
        case .idle:
            StatusRow(systemImage: "antenna.radiowaves.left.and.right.slash", title: "Not connected",
                      detail: "Turn on TERRA and keep it near your phone.")
        case .searching:
            StatusRow(title: "Searching for TERRA…", detail: "Keep TERRA close to your phone.") {
                ProgressView()
            }
        case .transferring(let progress):
            VStack(alignment: .leading, spacing: 8) {
                Text("Sending route to \(transfer.connectedName ?? "TERRA")…")
                    .font(.headline)
                ProgressView(value: progress)
                Text("Keep TERRA nearby until it confirms the route is saved.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .received(let receipt):
            StatusRow(systemImage: "checkmark.circle.fill", tint: .green, title: "Route received",
                      detail: "\(receipt.deviceName) saved the route. You can put your phone away.")
        case .failed(let message):
            StatusRow(systemImage: "exclamationmark.triangle.fill", tint: .orange, title: "Transfer failed",
                      detail: message)
        }
    }

    @ViewBuilder private var actions: some View {
        switch transfer.state {
        case .idle:
            Button { transfer.send(route) } label: {
                Text("Find TERRA").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        case .failed:
            Button { transfer.send(route) } label: {
                Text("Try Again").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        case .received:
            Button { dismiss() } label: {
                Text("Done").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        case .searching, .transferring:
            EmptyView()
        }
    }
}

private struct StatusRow<Accessory: View>: View {
    var title: String
    var detail: String
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            accessory
                .font(.title2)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

private extension StatusRow where Accessory == AnyView {
    init(systemImage: String, tint: Color = .secondary, title: String, detail: String) {
        self.init(title: title, detail: detail) {
            AnyView(Image(systemName: systemImage).foregroundStyle(tint))
        }
    }
}
