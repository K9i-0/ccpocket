import AppKit
import Foundation

@MainActor
final class QRCodeViewModel: ObservableObject {
    @Published var addresses: [NetworkAddress] = []
    @Published var selectedAddress: NetworkAddress?
    @Published var qrImage: NSImage?
    @Published var deepLink: String = ""

    private let networkDiscovery = NetworkDiscovery()
    private let qrGenerator = QRCodeGenerator()

    var port: Int {
        let stored = UserDefaults.standard.integer(forKey: "bridgePort")
        return stored > 0 ? stored : 8765
    }

    var apiKey: String? {
        UserDefaults.standard.string(forKey: "bridgeApiKey")
    }

    func refresh() {
        addresses = networkDiscovery.getReachableAddresses()

        // Auto-select: prefer LAN, fallback to first
        if selectedAddress == nil || !addresses.contains(where: { $0.ip == selectedAddress?.ip }) {
            selectedAddress = addresses.first(where: { $0.label == "LAN" }) ?? addresses.first
        }

        generateQR()
    }

    func selectAddress(_ address: NetworkAddress) {
        selectedAddress = address
        generateQR()
    }

    func copyDeepLink() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(deepLink, forType: .string)
    }

    private func generateQR() {
        guard let addr = selectedAddress else {
            qrImage = nil
            deepLink = ""
            return
        }

        deepLink = networkDiscovery.buildConnectionURL(
            ip: addr.ip,
            port: port,
            apiKey: apiKey
        )
        qrImage = qrGenerator.generate(from: deepLink, size: 200)
    }
}
