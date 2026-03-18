import Foundation

struct BridgeVersion: Codable {
    let version: String
    let nodeVersion: String
    let platform: String
    let arch: String
    let startedAt: String
    let uptime: Int
    let gitCommit: String?
    let gitBranch: String?
}
