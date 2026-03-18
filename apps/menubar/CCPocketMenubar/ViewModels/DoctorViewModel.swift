import Foundation

@MainActor
final class DoctorViewModel: ObservableObject {
    @Published var report: DoctorReport?
    @Published var isRunning = false
    @Published var actionInProgress: String?
    @Published var actionError: String?

    private let doctorRunner = DoctorRunner()
    private let processManager = BridgeProcessManager()

    var requiredChecks: [CheckResult] {
        report?.results.filter { $0.category == "required" } ?? []
    }

    var optionalChecks: [CheckResult] {
        report?.results.filter { $0.category == "optional" } ?? []
    }

    func runDoctor() {
        guard !isRunning else { return }
        isRunning = true
        actionError = nil

        Task {
            do {
                report = try await doctorRunner.runDoctor()
            } catch {
                actionError = error.localizedDescription
            }
            isRunning = false
        }
    }

    func setupBridge(port: Int? = nil, apiKey: String? = nil) {
        performAction("Setting up Bridge…") {
            try await self.processManager.setupService(port: port, apiKey: apiKey)
        }
    }

    func uninstallBridge() {
        performAction("Uninstalling Bridge…") {
            try await self.processManager.uninstallService()
        }
    }

    func installNode() {
        performAction("Installing Node.js…") {
            try await self.processManager.installNodeViaHomebrew()
        }
    }

    func installClaudeCode() {
        performAction("Installing Claude Code…") {
            try await self.processManager.installClaudeCode()
        }
    }

    func updateBridge() {
        performAction("Updating Bridge…") {
            try await self.processManager.installOrUpdateBridge()
        }
    }

    private func performAction(_ label: String, action: @escaping () async throws -> Void) {
        actionInProgress = label
        actionError = nil

        Task {
            do {
                try await action()
                // Re-run doctor after action
                try? await Task.sleep(for: .seconds(1))
                runDoctor()
            } catch {
                actionError = error.localizedDescription
            }
            actionInProgress = nil
        }
    }
}
