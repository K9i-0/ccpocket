import Foundation
import Network

final class LocalNetworkPermissionProber: @unchecked Sendable {
    private let queue = DispatchQueue(label: "ccpocket.native.local-network-probe")
    private var browser: NWBrowser?

    func triggerPromptIfNeeded(onDebug: @escaping @Sendable (String) -> Void = { _ in }) {
        let descriptor = NWBrowser.Descriptor.bonjour(type: "_ccpocket._tcp", domain: nil)
        let browser = NWBrowser(for: descriptor, using: .tcp)
        self.browser = browser
        browser.stateUpdateHandler = { state in
            onDebug("本地网络预检 state：\(Self.describe(state))")
        }
        browser.browseResultsChangedHandler = { results, _ in
            onDebug("本地网络预检发现服务数：\(results.count)")
        }
        browser.start(queue: queue)

        queue.asyncAfter(deadline: .now() + 3) { [weak self, weak browser] in
            guard let self, let browser else { return }
            browser.cancel()
            if self.browser === browser {
                self.browser = nil
            }
            onDebug("本地网络预检已结束")
        }
    }

    private static func describe(_ state: NWBrowser.State) -> String {
        switch state {
        case .setup: "setup"
        case .waiting(let error): "waiting \(error.localizedDescription)"
        case .ready: "ready"
        case .failed(let error): "failed \(error.localizedDescription)"
        case .cancelled: "cancelled"
        @unknown default: "unknown"
        }
    }
}
