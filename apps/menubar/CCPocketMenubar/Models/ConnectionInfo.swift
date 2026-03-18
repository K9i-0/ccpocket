import Foundation

struct NetworkAddress: Identifiable, Hashable {
    let ip: String
    let label: String  // "LAN" or "Tailscale"

    var id: String { ip }
}
