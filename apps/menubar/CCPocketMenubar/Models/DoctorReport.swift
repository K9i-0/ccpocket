import Foundation

struct ProviderResult: Codable, Identifiable {
    let name: String
    let installed: Bool
    let version: String?
    let authenticated: Bool
    let authMessage: String?
    let remediation: String?

    var id: String { name }
}

struct CheckResult: Codable, Identifiable {
    let name: String
    let status: String  // "pass", "fail", "warn", "skip"
    let message: String
    let category: String  // "required", "optional"
    let remediation: String?
    let providers: [ProviderResult]?

    var id: String { name }

    var statusIcon: String {
        switch status {
        case "pass": return "checkmark.circle.fill"
        case "fail": return "xmark.circle.fill"
        case "warn": return "exclamationmark.triangle.fill"
        case "skip": return "minus.circle"
        default: return "questionmark.circle"
        }
    }

    var statusColor: String {
        switch status {
        case "pass": return "green"
        case "fail": return "red"
        case "warn": return "orange"
        default: return "gray"
        }
    }
}

struct DoctorReport: Codable {
    let results: [CheckResult]
    let allRequiredPassed: Bool
}
