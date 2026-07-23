import Flutter
import Foundation
import WatchConnectivity

/// Native half of the Flutter ↔ iPhone ↔ Apple Watch relay.
final class WatchConnectivityManager: NSObject, WCSessionDelegate {
  static let shared = WatchConnectivityManager()

  private var flutterChannel: FlutterMethodChannel?
  private var latestSnapshot: [String: Any]?
  private var pendingActions: [[String: Any]] = []

  private override init() {
    super.init()
  }

  func activate() {
    guard WCSession.isSupported() else { return }
    let session = WCSession.default
    session.delegate = self
    session.activate()
  }

  func attach(channel: FlutterMethodChannel) {
    flutterChannel = channel
    flushPendingActions()
  }

  func updateSnapshot(_ snapshot: [String: Any]) throws {
    guard WCSession.isSupported() else { return }
    latestSnapshot = snapshot
    let session = WCSession.default
    guard session.activationState == .activated else { return }
    try deliver(snapshot, using: session)
  }

  private func deliver(
    _ snapshot: [String: Any],
    using session: WCSession
  ) throws {
    try session.updateApplicationContext(snapshot)
    if session.isReachable {
      session.sendMessage(
        ["snapshot": snapshot],
        replyHandler: nil,
        errorHandler: nil
      )
    }
  }

  private func redeliverLatestSnapshot(using session: WCSession) {
    DispatchQueue.main.async { [weak self] in
      guard let self, let snapshot = self.latestSnapshot else { return }
      do {
        try self.deliver(snapshot, using: session)
      } catch {
        NSLog(
          "[watch] Deferred snapshot update failed: %@",
          error.localizedDescription
        )
      }
    }
  }

  private func flushPendingActions() {
    guard flutterChannel != nil, !pendingActions.isEmpty else { return }
    let actions = pendingActions
    pendingActions.removeAll()
    for action in actions {
      forward(action: action, replyHandler: nil)
    }
  }

  private func forward(
    action: [String: Any],
    replyHandler: (([String: Any]) -> Void)?
  ) {
    DispatchQueue.main.async { [weak self] in
      guard let self, let channel = self.flutterChannel else {
        if action["type"] as? String == "refresh" {
          self?.pendingActions.append(action)
        }
        replyHandler?([
          "accepted": false,
          "message": "Open ccpocket on iPhone to reconnect."
        ])
        return
      }

      let method = action["type"] as? String == "refresh"
        ? "requestRefresh"
        : "performAction"
      channel.invokeMethod(method, arguments: action) { response in
        if let response = response as? [String: Any] {
          replyHandler?(response)
        } else if let error = response as? FlutterError {
          replyHandler?([
            "accepted": false,
            "message": error.message ?? "Action failed"
          ])
        } else {
          replyHandler?(["accepted": true])
        }
      }
    }
  }

  func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    guard activationState == .activated, error == nil else { return }
    redeliverLatestSnapshot(using: session)
  }

  func sessionWatchStateDidChange(_ session: WCSession) {
    guard session.activationState == .activated else { return }
    redeliverLatestSnapshot(using: session)
  }

  func sessionReachabilityDidChange(_ session: WCSession) {
    guard session.isReachable else { return }
    redeliverLatestSnapshot(using: session)
  }

  func sessionDidBecomeInactive(_ session: WCSession) {}

  func sessionDidDeactivate(_ session: WCSession) {
    session.activate()
  }

  func session(
    _ session: WCSession,
    didReceiveMessage message: [String: Any],
    replyHandler: @escaping ([String: Any]) -> Void
  ) {
    forward(action: message, replyHandler: replyHandler)
  }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    forward(action: message, replyHandler: nil)
  }
}
