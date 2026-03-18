import Foundation
import SwiftUI

enum BridgeStatus {
    case running
    case stopped
    case checking

    var label: String {
        switch self {
        case .running: return "Running"
        case .stopped: return "Stopped"
        case .checking: return "Checking…"
        }
    }

    var color: Color {
        switch self {
        case .running: return .green
        case .stopped: return .red
        case .checking: return .gray
        }
    }

    var icon: String {
        switch self {
        case .running: return "circle.fill"
        case .stopped: return "circle.fill"
        case .checking: return "circle.dotted"
        }
    }
}

enum AppTab: Int, CaseIterable, Identifiable {
    case usage = 0
    case qrCode = 1
    case doctor = 2

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .usage: return "Usage"
        case .qrCode: return "Connect"
        case .doctor: return "Doctor"
        }
    }

    var icon: String {
        switch self {
        case .usage: return "chart.bar"
        case .qrCode: return "qrcode"
        case .doctor: return "stethoscope"
        }
    }
}

@MainActor
final class AppViewModel: ObservableObject {
    @Published var bridgeStatus: BridgeStatus = .checking
    @Published var bridgeVersion: String?
    @Published var selectedTab: AppTab = .usage

    private let bridgeClient = BridgeClient()
    private let processManager = BridgeProcessManager()
    private var healthTimer: Timer?

    func startPolling() {
        checkHealth()
        healthTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkHealth()
            }
        }
    }

    func stopPolling() {
        healthTimer?.invalidate()
        healthTimer = nil
    }

    func onPopoverOpen() {
        checkHealth()
    }

    func toggleBridge() {
        Task {
            do {
                if bridgeStatus == .running {
                    try await processManager.stopService()
                    bridgeStatus = .stopped
                } else {
                    try await processManager.startService()
                    bridgeStatus = .checking
                    // Wait a bit for startup
                    try? await Task.sleep(for: .seconds(2))
                    checkHealth()
                }
            } catch {
                print("Bridge toggle failed: \(error)")
            }
        }
    }

    private func checkHealth() {
        Task {
            let running = await bridgeClient.isRunning()
            bridgeStatus = running ? .running : .stopped

            if running {
                if let version = try? await bridgeClient.version() {
                    bridgeVersion = version.version
                }
            }
        }
    }
}
