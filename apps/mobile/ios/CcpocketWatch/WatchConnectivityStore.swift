import Foundation
import WatchConnectivity

final class WatchConnectivityStore: NSObject, ObservableObject, WCSessionDelegate {
  @Published private(set) var snapshot = WatchSnapshot.empty
  @Published private(set) var isReachable = false
  @Published private(set) var isSending = false
  @Published var actionMessage: String?

  override init() {
    super.init()
    #if DEBUG
    if ProcessInfo.processInfo.arguments.contains("-watch-preview") {
      snapshot = .preview
      return
    }
    #endif
    guard WCSession.isSupported() else { return }
    let session = WCSession.default
    session.delegate = self
    if !session.receivedApplicationContext.isEmpty {
      snapshot = WatchSnapshot(dictionary: session.receivedApplicationContext)
    }
    session.activate()
  }

  func refresh() {
    send(["type": "refresh"], reportsResult: false)
  }

  func clearActionMessage() {
    actionMessage = nil
  }

  func approve(
    session: WatchSession,
    permission: WatchPermission,
    completion: @escaping (Bool) -> Void
  ) {
    send([
      "type": "approve",
      "sessionId": session.id,
      "toolUseId": permission.toolUseId,
    ], completion: completion)
  }

  func reject(
    session: WatchSession,
    permission: WatchPermission,
    completion: @escaping (Bool) -> Void
  ) {
    send([
      "type": "reject",
      "sessionId": session.id,
      "toolUseId": permission.toolUseId,
    ], completion: completion)
  }

  func answer(
    session: WatchSession,
    permission: WatchPermission,
    answers: [String: [String]],
    completion: @escaping (Bool) -> Void
  ) {
    send([
      "type": "answer",
      "sessionId": session.id,
      "toolUseId": permission.toolUseId,
      "answers": answers,
    ], completion: completion)
  }

  func sendInput(
    session: WatchSession,
    text: String,
    completion: @escaping (Bool) -> Void
  ) {
    send([
      "type": "input",
      "sessionId": session.id,
      "text": text,
    ], completion: completion)
  }

  func fetchLatestAgentMessage(
    sessionId: String,
    completion: @escaping (String?, Bool, String?) -> Void
  ) {
    guard WCSession.default.isReachable else {
      completion(nil, false, "Open ccpocket on iPhone to reconnect.")
      return
    }
    WCSession.default.sendMessage(
      [
        "type": "latest_agent_message",
        "sessionId": sessionId,
      ],
      replyHandler: { response in
        DispatchQueue.main.async {
          guard response["accepted"] as? Bool == true,
                let text = response["text"] as? String
          else {
            completion(
              nil,
              false,
              response["message"] as? String ?? "Agent message unavailable"
            )
            return
          }
          completion(text, response["truncated"] as? Bool ?? false, nil)
        }
      },
      errorHandler: { error in
        DispatchQueue.main.async {
          completion(nil, false, error.localizedDescription)
        }
      }
    )
  }

  private func send(
    _ message: [String: Any],
    reportsResult: Bool = true,
    completion: @escaping (Bool) -> Void = { _ in }
  ) {
    guard WCSession.default.isReachable else {
      actionMessage = "Open ccpocket on iPhone to reconnect."
      completion(false)
      return
    }
    isSending = true
    actionMessage = nil
    WCSession.default.sendMessage(
      message,
      replyHandler: { [weak self] response in
        DispatchQueue.main.async {
          self?.isSending = false
          let accepted = response["accepted"] as? Bool ?? false
          if reportsResult {
            self?.actionMessage = accepted
              ? "Sent"
              : response["message"] as? String ?? "Action failed"
          }
          completion(accepted)
        }
      },
      errorHandler: { [weak self] error in
        DispatchQueue.main.async {
          self?.isSending = false
          if reportsResult {
            self?.actionMessage = error.localizedDescription
          }
          completion(false)
        }
      }
    )
  }

  private func receive(_ dictionary: [String: Any]) {
    DispatchQueue.main.async { [weak self] in
      self?.snapshot = WatchSnapshot(dictionary: dictionary)
    }
  }

  func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    DispatchQueue.main.async { [weak self] in
      self?.isReachable = session.isReachable
      if let error {
        self?.actionMessage = error.localizedDescription
      }
      if activationState == .activated {
        self?.refresh()
      }
    }
  }

  func sessionReachabilityDidChange(_ session: WCSession) {
    DispatchQueue.main.async { [weak self] in
      self?.isReachable = session.isReachable
    }
  }

  func session(
    _ session: WCSession,
    didReceiveApplicationContext applicationContext: [String: Any]
  ) {
    receive(applicationContext)
  }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    if let snapshot = message["snapshot"] as? [String: Any] {
      receive(snapshot)
    }
  }
}
