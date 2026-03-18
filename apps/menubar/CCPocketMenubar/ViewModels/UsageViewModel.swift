import Foundation
import SwiftUI

@MainActor
final class UsageViewModel: ObservableObject {
    @Published var providers: [UsageInfo] = []
    @Published var isLoading = false
    @Published var error: String?

    private let bridgeClient = BridgeClient()
    private var refreshTimer: Timer?

    func startAutoRefresh() {
        fetchUsage()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fetchUsage()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func fetchUsage() {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        Task {
            do {
                let response = try await bridgeClient.usage()
                providers = response.providers
                error = nil
            } catch {
                self.error = "Bridge is not running"
            }
            isLoading = false
        }
    }
}
