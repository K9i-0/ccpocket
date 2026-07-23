import SwiftUI

struct WatchSnapshot {
  let connected: Bool
  let bridgeHost: String
  let bridgePort: Int?
  let activeSessionCount: Int
  let statusCounts: [String: Int]
  let sessions: [WatchSession]
  let usage: [WatchUsage]
  let generatedAt: Date?

  static let empty = WatchSnapshot(
    connected: false,
    bridgeHost: "",
    bridgePort: nil,
    activeSessionCount: 0,
    statusCounts: [:],
    sessions: [],
    usage: [],
    generatedAt: nil
  )

  #if DEBUG
  static let preview = WatchSnapshot(dictionary: [
    "connected": true,
    "bridgeHost": "localhost",
    "bridgePort": 8765,
    "generatedAt": "2026-07-22T03:00:00Z",
    "statusCounts": [
      "waiting_approval": 1,
      "running": 1,
    ],
    "sessions": [
      [
        "id": "preview-approval",
        "title": "ccpocket",
        "project": "ccpocket",
        "branch": "feat/apple-watch-mvp",
        "provider": "codex",
        "status": "waiting_approval",
        "statusLabel": "Needs You",
        "lastMessage": "Ready to run the full Flutter test suite.",
        "permission": [
          "toolUseId": "preview-tool",
          "kind": "approval",
          "title": "Run tests",
          "summary": "flutter test",
          "canApprove": true,
          "canReject": true,
          "allowsCustomInput": false,
          "questions": [],
        ] as [String: Any],
      ] as [String: Any],
      [
        "id": "preview-running",
        "title": "Bridge cleanup",
        "project": "bridge",
        "branch": "main",
        "provider": "claude",
        "status": "running",
        "statusLabel": "Working",
        "lastMessage": "Reviewing the WebSocket session lifecycle.",
        "queuedInput": [
          "text": "Run the Watch layout checks after this review.",
          "imageCount": 1,
        ] as [String: Any],
      ] as [String: Any],
    ],
    "usage": [
      [
        "provider": "codex",
        "fiveHour": ["remaining": 0.72],
        "sevenDay": ["remaining": 0.46],
      ] as [String: Any],
      [
        "provider": "claude",
        "fiveHour": ["remaining": 0.58],
        "sevenDay": ["remaining": 0.81],
      ] as [String: Any],
    ],
  ])
  #endif

  init(dictionary: [String: Any]) {
    connected = dictionary["connected"] as? Bool ?? false
    bridgeHost = dictionary["bridgeHost"] as? String ?? ""
    bridgePort = dictionary["bridgePort"] as? Int
    activeSessionCount = max(
      0,
      dictionary["activeSessionCount"] as? Int
        ?? Self.dictionaries(dictionary["sessions"]).count
    )
    sessions = Self.dictionaries(dictionary["sessions"]).compactMap(WatchSession.init)
    if let counts = dictionary["statusCounts"] as? [String: Any] {
      statusCounts = counts.reduce(into: [:]) { result, entry in
        if let count = entry.value as? Int {
          result[entry.key] = max(0, count)
        }
      }
    } else {
      statusCounts = Dictionary(grouping: sessions, by: \WatchSession.status)
        .mapValues(\.count)
    }
    usage = Self.dictionaries(dictionary["usage"]).compactMap(WatchUsage.init)
    if let value = dictionary["generatedAt"] as? String {
      generatedAt = ISO8601DateFormatter().date(from: value)
    } else {
      generatedAt = nil
    }
  }

  private init(
    connected: Bool,
    bridgeHost: String,
    bridgePort: Int?,
    activeSessionCount: Int,
    statusCounts: [String: Int],
    sessions: [WatchSession],
    usage: [WatchUsage],
    generatedAt: Date?
  ) {
    self.connected = connected
    self.bridgeHost = bridgeHost
    self.bridgePort = bridgePort
    self.activeSessionCount = activeSessionCount
    self.statusCounts = statusCounts
    self.sessions = sessions
    self.usage = usage
    self.generatedAt = generatedAt
  }

  static func dictionaries(_ value: Any?) -> [[String: Any]] {
    (value as? [Any] ?? []).compactMap { $0 as? [String: Any] }
  }
}

struct WatchSession: Identifiable {
  let id: String
  let title: String
  let hasCustomName: Bool
  let project: String
  let branch: String
  let provider: String
  let status: String
  let statusLabel: String
  let lastMessage: String
  let queuedInput: WatchQueuedInput?
  let permission: WatchPermission?

  init?(_ dictionary: [String: Any]) {
    guard let id = dictionary["id"] as? String else { return nil }
    self.id = id
    let decodedTitle = dictionary["title"] as? String ?? ""
    title = decodedTitle.isEmpty ? "Session" : decodedTitle
    project = dictionary["project"] as? String ?? ""
    hasCustomName = (dictionary["hasCustomName"] as? Bool) ?? (title != project)
    branch = dictionary["branch"] as? String ?? ""
    provider = dictionary["provider"] as? String ?? "claude"
    status = dictionary["status"] as? String ?? "idle"
    statusLabel = switch status {
    case "waiting_approval": "Needs You"
    case "running", "starting", "compacting": "Working"
    default: "Ready"
    }
    lastMessage = dictionary["lastMessage"] as? String ?? ""
    queuedInput = (dictionary["queuedInput"] as? [String: Any]).map(WatchQueuedInput.init)
    permission = (dictionary["permission"] as? [String: Any]).flatMap(WatchPermission.init)
  }

  var statusColor: Color {
    switch status {
    case "waiting_approval": .ccpocketApproval
    case "running", "starting": .ccpocketRunning
    case "compacting": .ccpocketCompacting
    default: .ccpocketIdle
    }
  }

  var providerSymbol: String {
    provider == "codex" ? "chevron.left.forwardslash.chevron.right" : "sparkles"
  }
}

struct WatchQueuedInput {
  let text: String
  let imageCount: Int

  init(_ dictionary: [String: Any]) {
    text = dictionary["text"] as? String ?? ""
    imageCount = max(0, dictionary["imageCount"] as? Int ?? 0)
  }
}

struct WatchPermission {
  let toolUseId: String
  let kind: String
  let title: String
  let summary: String
  let canApprove: Bool
  let canReject: Bool
  let allowsCustomInput: Bool
  let requiresPhone: Bool
  let questions: [WatchQuestion]

  init?(_ dictionary: [String: Any]) {
    guard let toolUseId = dictionary["toolUseId"] as? String else { return nil }
    self.toolUseId = toolUseId
    kind = dictionary["kind"] as? String ?? "approval"
    title = dictionary["title"] as? String ?? "Approval"
    summary = dictionary["summary"] as? String ?? ""
    canApprove = dictionary["canApprove"] as? Bool ?? true
    canReject = dictionary["canReject"] as? Bool ?? true
    allowsCustomInput = dictionary["allowsCustomInput"] as? Bool ?? false
    requiresPhone = dictionary["requiresPhone"] as? Bool ?? false
    questions = WatchSnapshot.dictionaries(dictionary["questions"])
      .compactMap(WatchQuestion.init)
  }
}

struct WatchQuestion: Identifiable {
  let key: String
  let header: String
  let text: String
  let multiSelect: Bool
  let required: Bool
  let options: [WatchOption]

  var id: String { key }

  init?(_ dictionary: [String: Any]) {
    guard let key = dictionary["key"] as? String,
          let text = dictionary["text"] as? String else { return nil }
    self.key = key
    self.text = text
    header = dictionary["header"] as? String ?? ""
    multiSelect = dictionary["multiSelect"] as? Bool ?? false
    required = dictionary["required"] as? Bool ?? true
    options = WatchSnapshot.dictionaries(dictionary["options"])
      .compactMap(WatchOption.init)
  }
}

struct WatchOption: Identifiable {
  let value: String
  let label: String
  let description: String

  var id: String { value }

  init?(_ dictionary: [String: Any]) {
    guard let label = dictionary["label"] as? String else { return nil }
    self.label = label
    value = dictionary["value"] as? String ?? label
    description = dictionary["description"] as? String ?? ""
  }
}

struct WatchUsage: Identifiable {
  let provider: String
  let error: String?
  let fiveHour: WatchUsageWindow?
  let sevenDay: WatchUsageWindow?

  var id: String { provider }
  var displayName: String { provider == "codex" ? "Codex" : "Claude" }

  init?(_ dictionary: [String: Any]) {
    guard let provider = dictionary["provider"] as? String else { return nil }
    self.provider = provider
    error = dictionary["error"] as? String
    fiveHour = (dictionary["fiveHour"] as? [String: Any]).flatMap(WatchUsageWindow.init)
    sevenDay = (dictionary["sevenDay"] as? [String: Any]).flatMap(WatchUsageWindow.init)
  }
}

struct WatchUsageWindow {
  let remaining: Double
  let resetsAt: Date?

  init?(_ dictionary: [String: Any]) {
    guard let remaining = dictionary["remaining"] as? Double else { return nil }
    self.remaining = min(max(remaining, 0), 1)
    if let value = dictionary["resetsAt"] as? String {
      resetsAt = ISO8601DateFormatter().date(from: value)
    } else {
      resetsAt = nil
    }
  }
}

extension Color {
  static let ccpocketOrange = Color(red: 0.976, green: 0.451, blue: 0.086)
  static let ccpocketApproval = Color(red: 0.992, green: 0.729, blue: 0.455)
  static let ccpocketRunning = Color(red: 0.302, green: 0.639, blue: 1.0)
  static let ccpocketCompacting = Color(red: 0.655, green: 0.545, blue: 0.98)
  static let ccpocketOnline = Color(red: 0.290, green: 0.871, blue: 0.502)
  static let ccpocketTeal = Color(red: 0.176, green: 0.831, blue: 0.749)
  static let ccpocketIdle = Color(red: 0.431, green: 0.431, blue: 0.431)
}
