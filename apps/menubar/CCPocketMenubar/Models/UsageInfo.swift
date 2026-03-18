import Foundation

struct UsageWindow: Codable, Identifiable {
    let utilization: Double
    let resetsAt: String

    var id: String { resetsAt }

    /// Parse ISO 8601 resetsAt into a Date
    var resetsAtDate: Date? {
        ISO8601DateFormatter().date(from: resetsAt)
    }

    /// Relative time string for reset (e.g. "2h 15m")
    var resetsInText: String {
        guard let date = resetsAtDate else { return "—" }
        let remaining = date.timeIntervalSinceNow
        if remaining <= 0 { return "now" }

        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

struct UsageInfo: Codable, Identifiable {
    let provider: String
    let fiveHour: UsageWindow?
    let sevenDay: UsageWindow?
    let error: String?

    var id: String { provider }

    var displayName: String {
        switch provider {
        case "claude": return "Claude Code"
        case "codex": return "Codex"
        default: return provider
        }
    }

    var iconName: String {
        switch provider {
        case "claude": return "brain.head.profile"
        case "codex": return "chevron.left.forwardslash.chevron.right"
        default: return "questionmark.circle"
        }
    }
}

struct UsageResponse: Codable {
    let providers: [UsageInfo]
}
