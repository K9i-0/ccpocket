import Foundation

enum DeepLinkParams: Equatable {
    case connection(ConnectionParams)
    case session(String)
}

enum ConnectionURLParser {
    static func parse(_ rawURL: String) -> DeepLinkParams? {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasPrefix("ccpocket://") {
            guard let components = URLComponents(string: trimmed) else { return nil }
            if components.host == "session" {
                let sessionId = components.path.split(separator: "/").first.map(String.init)
                return sessionId.map(DeepLinkParams.session)
            }

            if components.host == "connect" {
                let url = components.queryItems?.first(where: { $0.name == "url" })?.value
                let token = components.queryItems?.first(where: { $0.name == "token" })?.value
                guard let url, isValidWebSocketURL(url) else { return nil }
                return .connection(ConnectionParams(serverURL: url, token: token?.isEmpty == false ? token : nil))
            }
            return nil
        }

        if trimmed.hasPrefix("ws://") || trimmed.hasPrefix("wss://") {
            return isValidWebSocketURL(trimmed) ? .connection(ConnectionParams(serverURL: trimmed)) : nil
        }

        if isHostPort(trimmed) || isBracketedIPv6Port(trimmed) {
            return .connection(ConnectionParams(serverURL: "ws://\(trimmed)"))
        }

        return nil
    }

    static func parse(_ url: URL) -> DeepLinkParams? {
        parse(url.absoluteString)
    }

    private static func isValidWebSocketURL(_ value: String) -> Bool {
        guard let components = URLComponents(string: value),
              components.scheme == "ws" || components.scheme == "wss",
              components.host?.isEmpty == false else {
            return false
        }
        if let port = components.port {
            return (1...65535).contains(port)
        }
        return true
    }

    private static func isHostPort(_ value: String) -> Bool {
        value.range(of: #"^[\w.\-]+:\d+$"#, options: .regularExpression) != nil
    }

    private static func isBracketedIPv6Port(_ value: String) -> Bool {
        value.range(of: #"^\[[^\]]*:[^\]]*\]:\d+$"#, options: .regularExpression) != nil
    }
}

