import Foundation

/// HTTP client for communicating with the Bridge Server.
final class BridgeClient: Sendable {
    private let session: URLSession
    private let port: Int

    private var baseURL: URL {
        URL(string: "http://localhost:\(port)")!
    }

    init(port: Int = UserDefaults.standard.integer(forKey: "bridgePort").nonZero ?? 8765) {
        self.port = port
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        self.session = URLSession(configuration: config)
    }

    func health() async throws -> BridgeHealth {
        try await get("/health")
    }

    func version() async throws -> BridgeVersion {
        try await get("/version")
    }

    func usage() async throws -> UsageResponse {
        try await get("/usage")
    }

    func doctor() async throws -> DoctorReport {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60  // Doctor checks can take a while
        let longSession = URLSession(configuration: config)
        let url = baseURL.appendingPathComponent("/doctor")
        let (data, response) = try await longSession.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw BridgeClientError.httpError
        }
        return try JSONDecoder().decode(DoctorReport.self, from: data)
    }

    /// Check if Bridge is reachable.
    func isRunning() async -> Bool {
        do {
            _ = try await health()
            return true
        } catch {
            return false
        }
    }

    // MARK: - Private

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        let (data, response) = try await session.data(from: url)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw BridgeClientError.httpError
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}

enum BridgeClientError: LocalizedError {
    case httpError

    var errorDescription: String? {
        switch self {
        case .httpError:
            return "Bridge server returned an error"
        }
    }
}

private extension Int {
    var nonZero: Int? {
        self == 0 ? nil : self
    }
}
