import AppKit
import Foundation

@MainActor
final class DoctorViewModel: ObservableObject {
    @Published var report: DoctorReport?
    @Published var isRunning = false
    @Published var actionInProgress: String?
    @Published var actionError: String?

    #if DEBUG
    @Published var mockScenario: MockDoctorScenario?
    /// Commands that have been "completed" (copied) during mock testing.
    var completedCommands: Set<String> = []
    #endif

    private let doctorRunner = DoctorRunner()
    private let processManager = BridgeProcessManager()

    init() {
        #if DEBUG
        // Pick up mock scenario from launch arguments (set by AppDelegate)
        if let raw = UserDefaults.standard.string(forKey: "mockDoctorScenario"),
           let scenario = MockDoctorScenario(rawValue: raw) {
            mockScenario = scenario
            // Clear so subsequent launches aren't affected
            UserDefaults.standard.removeObject(forKey: "mockDoctorScenario")
        }
        #endif
    }

    var requiredChecks: [CheckResult] {
        report?.results.filter { $0.category == "required" } ?? []
    }

    var optionalChecks: [CheckResult] {
        report?.results.filter { $0.category == "optional" } ?? []
    }

    /// Whether all checks pass (used for onboarding completion detection).
    var allPassed: Bool {
        report?.allRequiredPassed ?? false
    }

    func runDoctor() {
        guard !isRunning else { return }
        isRunning = true
        actionError = nil

        Task {
            #if DEBUG
            if let mockScenario {
                report = applyCompletedCommands(to: mockScenario.buildReport())
                isRunning = false
                return
            }
            #endif
            do {
                report = try await doctorRunner.runDoctor()
            } catch {
                actionError = error.localizedDescription
            }
            isRunning = false
        }
    }

    #if DEBUG
    func setMockScenario(_ scenario: MockDoctorScenario?) {
        mockScenario = scenario
        completedCommands.removeAll()
        report = scenario?.buildReport()
    }

    func markCommandCompleted(_ command: String) {
        completedCommands.insert(command)
    }

    /// Flip checks to pass if all their commands have been copied.
    private func applyCompletedCommands(to report: DoctorReport) -> DoctorReport {
        guard !completedCommands.isEmpty else { return report }

        let updatedResults = report.results.map { check -> CheckResult in
            let commands = setupCommands(for: check)
            guard !commands.isEmpty else { return check }

            let allDone = commands.allSatisfy { completedCommands.contains($0.command) }
            guard allDone else { return check }

            return CheckResult(
                name: check.name,
                status: "pass",
                message: "Installed",
                category: check.category,
                remediation: nil,
                providers: check.providers?.map { provider in
                    ProviderResult(
                        name: provider.name,
                        installed: true,
                        version: provider.version ?? "latest",
                        authenticated: true,
                        authMessage: "Authenticated",
                        remediation: nil
                    )
                }
            )
        }

        let allRequiredPassed = updatedResults
            .filter { $0.category == "required" }
            .allSatisfy { $0.status == "pass" }

        return DoctorReport(results: updatedResults, allRequiredPassed: allRequiredPassed)
    }
    #endif

    func setupBridge(port: Int? = nil, apiKey: String? = nil) {
        performAction(String(localized: "Setting up Bridge…")) {
            try await self.processManager.setupService(port: port, apiKey: apiKey)
        }
    }

    func uninstallBridge() {
        performAction(String(localized: "Uninstalling Bridge…")) {
            try await self.processManager.uninstallService()
        }
    }

    func installNode() {
        performAction(String(localized: "Installing Node.js…")) {
            try await self.processManager.installNodeViaHomebrew()
        }
    }

    func installClaudeCode() {
        performAction(String(localized: "Installing Claude Code…")) {
            try await self.processManager.installClaudeCode()
        }
    }

    func installCodex() {
        performAction(String(localized: "Installing Codex…")) {
            try await self.processManager.installCodex()
        }
    }

    func updateBridge() {
        performAction(String(localized: "Updating Bridge…")) {
            try await self.processManager.installOrUpdateBridge()
        }
    }

    func loginProvider(_ providerName: String) {
        performAction(String(localized: "Opening browser for login…")) {
            try await self.processManager.loginProvider(providerName)
        }
    }

    // MARK: - Terminal Guide

    /// Build setup commands for all failing checks and open Terminal.app.
    func openSetupTerminal() {
        guard let report else { return }

        var commands: [(comment: String, command: String)] = []

        for check in report.results where check.status == "fail" || check.status == "warn" {
            commands.append(contentsOf: setupCommands(for: check))
        }

        guard !commands.isEmpty else { return }
        processManager.openTerminalGuide(title: "CC Pocket Setup", commands: commands)
    }

    /// Build setup commands for a single check and open Terminal.app.
    func openSetupTerminal(for check: CheckResult) {
        let commands = setupCommands(for: check)
        guard !commands.isEmpty else { return }
        processManager.openTerminalGuide(title: check.localizedName, commands: commands)
    }

    /// Copy all setup commands for failing checks to the clipboard.
    func copySetupCommands() {
        guard let report else { return }

        var lines: [String] = []
        for check in report.results where check.status == "fail" || check.status == "warn" {
            let commands = setupCommands(for: check)
            for entry in commands {
                lines.append("# \(entry.comment)")
                lines.append(entry.command)
                lines.append("")
            }
        }

        guard !lines.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
    }

    /// Copy setup commands for a single check to the clipboard.
    func copySetupCommands(for check: CheckResult) {
        let commands = setupCommands(for: check)
        guard !commands.isEmpty else { return }

        var lines: [String] = []
        for entry in commands {
            lines.append("# \(entry.comment)")
            lines.append(entry.command)
            lines.append("")
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
    }

    func setupCommands(for check: CheckResult) -> [(comment: String, command: String)] {
        switch check.name {
        case "Node.js" where check.status != "pass":
            return nodeCommands()

        case "CLI providers" where check.status != "pass":
            return cliProviderCommands(for: check)

        case "Bridge Server" where check.status != "pass",
             "launchd service" where check.status != "pass":
            return bridgeCommands()

        default:
            return []
        }
    }

    /// Return commands regardless of status (for onboarding step list).
    func allSetupCommands(for check: CheckResult) -> [(comment: String, command: String)] {
        switch check.name {
        case "Node.js":
            return nodeCommands()
        case "CLI providers":
            return cliProviderCommands(for: check)
        case "Bridge Server", "launchd service":
            return bridgeCommands()
        default:
            return []
        }
    }

    private func nodeCommands() -> [(comment: String, command: String)] {
        [
            (String(localized: "Install Homebrew"), "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""),
            (String(localized: "Install Node.js"), "brew install node"),
        ]
    }

    private func bridgeCommands() -> [(comment: String, command: String)] {
        [
            (String(localized: "Set up Bridge (install + start service)"), "npx @ccpocket/bridge@latest setup"),
        ]
    }

    /// Build CLI provider commands. Either provider is sufficient.
    private func cliProviderCommands(for check: CheckResult) -> [(comment: String, command: String)] {
        guard let providers = check.providers else { return [] }

        var commands: [(comment: String, command: String)] = []

        for provider in providers {
            if provider.installed && !provider.authenticated {
                switch provider.name {
                case "Claude Code CLI":
                    commands.append((String(localized: "Login to Claude Code"), "claude login"))
                case "Codex CLI":
                    commands.append((String(localized: "Login to Codex"), "codex login"))
                default:
                    break
                }
            } else if !provider.installed {
                switch provider.name {
                case "Claude Code CLI":
                    commands.append((String(localized: "Install Claude Code (either one is OK)"), "curl -fsSL https://claude.ai/install.sh | bash"))
                case "Codex CLI":
                    commands.append((String(localized: "Install Codex (either one is OK)"), "npm install -g @openai/codex"))
                default:
                    break
                }
            }
        }

        return commands
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
