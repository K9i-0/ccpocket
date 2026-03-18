import Foundation

struct BridgeHealth: Codable {
    let status: String
    let uptime: Int
    let sessions: Int
    let clients: Int
}
