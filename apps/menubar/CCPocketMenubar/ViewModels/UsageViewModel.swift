import Foundation
import SwiftUI

@MainActor
final class UsageViewModel: ObservableObject {
    @Published var providers: [UsageInfo] = []
    @Published var isLoading = false
    @Published var error: String?

    private let bridgeClient = BridgeClient()

    func fetchUsage() {
        guard !isLoading else { return }
        isLoading = true
        error = nil

        Task {
            do {
                let response = try await bridgeClient.usage()
                providers = response.providers.sorted { lhs, rhs in
                    rank(for: lhs.provider) < rank(for: rhs.provider)
                }
                error = nil
            } catch {
                // Only show error if we had no previous data
                if providers.isEmpty {
                    self.error = String(localized: "Failed to load usage data")
                }
            }
            isLoading = false
        }
    }

    private func rank(for provider: String) -> Int {
        switch provider {
        case "codex": return 0
        case "claude": return 1
        default: return 2
        }
    }
}
