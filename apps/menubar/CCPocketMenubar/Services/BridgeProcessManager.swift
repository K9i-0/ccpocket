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

    /// Check if the launchd service is registered.
    func isServiceRegistered() async -> Bool {
        do {
            let output = try await shell("launchctl list | grep \(serviceLabel)")
            return !output.isEmpty
        } catch {
            return false
        }
    }

    /// Start the Bridge via launchctl.
    func startService() async throws {
        try await shell("launchctl start \(serviceLabel)")
    }

    /// Stop the Bridge via launchctl.
    func stopService() async throws {
        try await shell("launchctl stop \(serviceLabel)")
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

    /// Install Node.js via Homebrew.
    func installNodeViaHomebrew() async throws {
        try await shell("brew install node", timeout: 300)
    }

    /// Install Claude Code CLI.
    func installClaudeCode() async throws {
        try await shell("npm install -g @anthropic-ai/claude-code", timeout: 120)
    }
}

enum ProcessError: LocalizedError {
    case nonZeroExit(status: Int32, output: String)

    var errorDescription: String? {
        switch self {
        case .nonZeroExit(let status, let output):
            return "Process exited with status \(status): \(output)"
        }
    }
}
