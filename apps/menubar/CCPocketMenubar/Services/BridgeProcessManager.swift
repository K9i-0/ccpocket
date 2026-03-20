import AppKit
import Foundation

/// Manages the Bridge Server process via launchctl.
final class BridgeProcessManager: Sendable {
    private let serviceLabel = "com.ccpocket.bridge"

    /// Run a shell command via interactive login shell to inherit user's PATH.
    @discardableResult
    private func shell(_ command: String, timeout: TimeInterval = 30) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-li", "-c", command]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
                return
            }

            // Timeout handling
            let timer = DispatchSource.makeTimerSource()
            timer.schedule(deadline: .now() + timeout)
            timer.setEventHandler {
                process.terminate()
            }
            timer.resume()

            process.waitUntilExit()
            timer.cancel()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            if process.terminationStatus == 0 {
                continuation.resume(returning: output)
            } else {
                continuation.resume(throwing: ProcessError.nonZeroExit(
                    status: process.terminationStatus,
                    output: output
                ))
            }
        }
    }

    // MARK: - Service Management

    /// Check if the launchd service is registered.
    func isServiceRegistered() async -> Bool {
        do {
            let output = try await shell("launchctl list | grep \(serviceLabel)")
            return !output.isEmpty
        } catch {
            return false
        }
    }

    private var plistPath: String {
        NSHomeDirectory() + "/Library/LaunchAgents/\(serviceLabel).plist"
    }

    /// Start the Bridge by loading the launchd service.
    func startService() async throws {
        try await shell("launchctl load \(plistPath)")
    }

    /// Stop the Bridge by unloading the launchd service.
    /// Using unload (not stop) so KeepAlive doesn't restart the process.
    func stopService() async throws {
        try await shell("launchctl unload \(plistPath)")
    }

    /// Setup (register) the launchd service.
    func setupService(port: Int? = nil, apiKey: String? = nil) async throws {
        var cmd = "npx @ccpocket/bridge@latest setup"
        if let port { cmd += " --port \(port)" }
        if let apiKey, !apiKey.isEmpty { cmd += " --api-key \(apiKey)" }
        try await shell(cmd, timeout: 120)
    }

    /// Uninstall the launchd service.
    func uninstallService() async throws {
        try await shell("npx @ccpocket/bridge@latest setup --uninstall")
    }

    /// Install or update the Bridge npm package globally.
    func installOrUpdateBridge() async throws {
        try await shell("npm install -g @ccpocket/bridge@latest", timeout: 120)
    }

    // MARK: - Dependency Installation

    /// Check if Homebrew is installed.
    func isHomebrewInstalled() async -> Bool {
        do {
            try await shell("which brew")
            return true
        } catch {
            return false
        }
    }

    /// Install Homebrew (official install script).
    func installHomebrew() async throws {
        try await shell(
            "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"",
            timeout: 600
        )
    }

    /// Install Node.js via Homebrew. Installs Homebrew first if needed.
    func installNodeViaHomebrew() async throws {
        let hasBrew = await isHomebrewInstalled()
        if !hasBrew {
            try await installHomebrew()
        }
        try await shell("brew install node", timeout: 300)
    }

    /// Install Claude Code CLI.
    func installClaudeCode() async throws {
        try await shell("npm install -g @anthropic-ai/claude-code", timeout: 120)
    }

    /// Install Codex CLI.
    func installCodex() async throws {
        try await shell("npm install -g @openai/codex", timeout: 120)
    }

    // MARK: - Authentication

    /// Open browser-based OAuth login for a CLI provider.
    /// This spawns `claude auth login` (or equivalent) which opens the user's
    /// default browser for authentication. The process completes when the
    /// browser callback is received.
    func loginProvider(_ providerName: String) async throws {
        switch providerName {
        case "Claude Code CLI":
            // claude auth login opens the browser and waits for OAuth callback
            try await shell("claude auth login", timeout: 120)
        case "Codex CLI":
            try await shell("codex --login", timeout: 120)
        default:
            throw ProcessError.nonZeroExit(status: 1, output: "Unknown provider: \(providerName)")
        }
    }

    // MARK: - Terminal Guide

    /// Open Terminal.app and copy setup commands to the clipboard.
    /// Commands are copied (not executed) so the user can paste and review them.
    func openTerminalGuide(title: String, commands: [(comment: String, command: String)]) {
        // Build clipboard text
        var lines: [String] = ["# \(title)", ""]
        for (i, entry) in commands.enumerated() {
            lines.append("# Step \(i + 1): \(entry.comment)")
            lines.append(entry.command)
            lines.append("")
        }

        // Copy to clipboard
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)

        // Open Terminal.app
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"))
    }

    // MARK: - Version Check

    /// Get the latest available version of Bridge from npm.
    func latestBridgeVersion() async -> String? {
        guard let output = try? await shell("npm view @ccpocket/bridge version", timeout: 10) else {
            return nil
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Error Types

enum ProcessError: LocalizedError {
    case nonZeroExit(status: Int32, output: String)

    var errorDescription: String? {
        switch self {
        case .nonZeroExit(_, let output):
            // Provide user-friendly messages for common failures
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.contains("command not found: brew") {
                return String(localized: "Homebrew is not installed. Please install it first.")
            }
            if trimmed.contains("command not found: node") || trimmed.contains("command not found: npm") {
                return String(localized: "Node.js is not installed. Please install it first.")
            }
            if trimmed.contains("command not found: claude") {
                return String(localized: "Claude Code CLI is not installed.")
            }
            if trimmed.contains("EACCES") || trimmed.contains("permission denied") {
                return String(localized: "Permission denied. You may need to fix npm permissions.")
            }
            if trimmed.contains("ETIMEDOUT") || trimmed.contains("network") {
                return String(localized: "Network error. Please check your internet connection.")
            }

            // Truncate long outputs for readability
            if trimmed.count > 200 {
                return String(trimmed.suffix(200))
            }
            return trimmed.isEmpty ? String(localized: "Command failed") : trimmed
        }
    }
}
