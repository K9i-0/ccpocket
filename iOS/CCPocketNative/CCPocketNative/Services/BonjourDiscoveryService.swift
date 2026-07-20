@preconcurrency import Foundation
import Network
import Observation

struct DiscoveredBridge: Identifiable, Hashable {
    let id: String
    var name: String
    var host: String?
    var port: Int?

    var urlString: String? {
        guard let host, let port else { return nil }
        return "ws://\(host):\(port)"
    }

    var subtitle: String {
        urlString ?? "解析中..."
    }
}

@MainActor
@Observable
final class BonjourDiscoveryService: NSObject {
    private var browser: NWBrowser?
    private let netServiceBrowser = NetServiceBrowser()
    private var services: [NetService] = []

    var bridges: [DiscoveredBridge] = []
    var isBrowsing = false

    override init() {
        super.init()
        netServiceBrowser.delegate = self
    }

    func start() {
        guard !isBrowsing else { return }
        isBrowsing = true

        let descriptor = NWBrowser.Descriptor.bonjour(type: "_ccpocket._tcp", domain: nil)
        let browser = NWBrowser(for: descriptor, using: .tcp)
        browser.browseResultsChangedHandler = { _, _ in }
        browser.start(queue: .global(qos: .utility))
        self.browser = browser

        netServiceBrowser.searchForServices(ofType: "_ccpocket._tcp.", inDomain: "local.")
    }

    func stop() {
        isBrowsing = false
        browser?.cancel()
        browser = nil
        netServiceBrowser.stop()
        services.removeAll()
    }

    private func upsert(name: String, host: String?, port: Int?) {
        let id = "\(name)-\(host ?? "pending")-\(port ?? 0)"
        if let index = bridges.firstIndex(where: { $0.name == name }) {
            bridges[index].host = host
            bridges[index].port = port
        } else {
            bridges.append(DiscoveredBridge(id: id, name: name, host: host, port: port))
        }
        bridges.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

extension BonjourDiscoveryService: @preconcurrency NetServiceBrowserDelegate, @preconcurrency NetServiceDelegate {
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        services.append(service)
        service.delegate = self
        service.resolve(withTimeout: 4)
        upsert(name: service.name, host: nil, port: nil)
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        let host = sender.hostName?.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        upsert(name: sender.name, host: host, port: sender.port)
    }
}
