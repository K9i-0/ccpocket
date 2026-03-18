import Foundation

/// Runs Bridge doctor checks, trying HTTP first then falling back to CLI.
final class DoctorRunner: Sendable {
    private let bridgeClient: BridgeClient
    private let processManager: BridgeProcessManager

    init(bridgeClient: BridgeClient = BridgeClient(),
         processManager: BridgeProcessManager = BridgeProcessManager()) {
        self.bridgeClient = bridgeClient
        self.processManager = processManager
    }

    /// Run doctor checks. Tries Bridge HTTP endpoint first, falls back to CLI.
    func runDoctor() async throws -> DoctorReport {
        // Try HTTP endpoint first (if Bridge is running)
        if let report = try? await bridgeClient.doctor() {
            return report
        }

        // Fall back to CLI
        return try await runDoctorCLI()
    }

    /// Run `ccpocket-bridge doctor --json` via CLI.
    private func runDoctorCLI() async throws -> DoctorReport {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-li", "-c", "npx @ccpocket/bridge@latest doctor --json"]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
                return
            }

            // Timeout (60s for doctor checks)
            let timer = DispatchSource.makeTimerSource()
            timer.schedule(deadline: .now() + 60)
            timer.setEventHandler { process.terminate() }
            timer.resume()

            process.waitUntilExit()
            timer.cancel()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()

            do {
                let report = try JSONDecoder().decode(DoctorReport.self, from: data)
                continuation.resume(returning: report)
            } catch {
                let output = String(data: data, encoding: .utf8) ?? "(no output)"
                continuation.resume(throwing: DoctorError.parseFailed(output: output))
            }
        }
    }
}

enum DoctorError: LocalizedError {
    case parseFailed(output: String)

    var errorDescription: String? {
        switch self {
        case .parseFailed(let output):
            return "Failed to parse doctor output: \(output.prefix(200))"
        }
    }
}
