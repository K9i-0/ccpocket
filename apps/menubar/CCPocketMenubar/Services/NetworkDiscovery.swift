import Foundation
import Darwin

/// Discovers local network addresses, mirroring startup-info.ts logic.
final class NetworkDiscovery {
    /// Get all reachable IPv4 addresses with LAN/Tailscale labels.
    func getReachableAddresses() -> [NetworkAddress] {
        var addresses: [NetworkAddress] = []
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddrPtr) == 0, let firstAddr = ifaddrPtr else {
            return addresses
        }

        defer { freeifaddrs(ifaddrPtr) }

        var current: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let addr = current {
            let sa = addr.pointee.ifa_addr.pointee
            // IPv4 only
            if sa.sa_family == UInt8(AF_INET) {
                let name = String(cString: addr.pointee.ifa_name)
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(
                    addr.pointee.ifa_addr,
                    socklen_t(sa.sa_len),
                    &hostname,
                    socklen_t(hostname.count),
                    nil, 0,
                    NI_NUMERICHOST
                ) == 0 {
                    let ip = String(cString: hostname)

                    // Skip loopback
                    if ip.hasPrefix("127.") {
                        current = addr.pointee.ifa_next
                        continue
                    }

                    // Classify: Tailscale uses 100.x.x.x range or utun interfaces
                    let label: String
                    if ip.hasPrefix("100.") ||
                       name.hasPrefix("utun") ||
                       name.lowercased().contains("tailscale") {
                        label = "Tailscale"
                    } else {
                        label = "LAN"
                    }

                    addresses.append(NetworkAddress(ip: ip, label: label))
                }
            }
            current = addr.pointee.ifa_next
        }

        return addresses
    }

    /// Build a ccpocket deep link URL for QR code.
    func buildConnectionURL(ip: String, port: Int, apiKey: String? = nil) -> String {
        var components = URLComponents()
        components.scheme = "ccpocket"
        components.host = "connect"
        components.queryItems = [
            URLQueryItem(name: "url", value: "ws://\(ip):\(port)")
        ]
        if let apiKey, !apiKey.isEmpty {
            components.queryItems?.append(URLQueryItem(name: "token", value: apiKey))
        }
        return components.string ?? "ccpocket://connect?url=ws://\(ip):\(port)"
    }
}
