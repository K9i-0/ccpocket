import Foundation

struct ComplicationSummary: Codable, Equatable {
  static let freshnessInterval: TimeInterval = 60 * 60

  let connected: Bool
  let active: Int
  let working: Int
  let needsYou: Int
  let ready: Int
  let generatedAt: Date?

  static let empty = ComplicationSummary(
    connected: false,
    active: 0,
    working: 0,
    needsYou: 0,
    ready: 0,
    generatedAt: nil
  )

  static let preview = ComplicationSummary(
    connected: true,
    active: 3,
    working: 2,
    needsYou: 1,
    ready: 0,
    generatedAt: Date()
  )

  init(dictionary: [String: Any]) {
    connected = dictionary["connected"] as? Bool ?? false

    let sessions = dictionary["sessions"] as? [Any] ?? []
    let decodedActive = dictionary["activeSessionCount"] as? Int ?? sessions.count
    active = max(0, decodedActive)

    let counts = dictionary["statusCounts"] as? [String: Any] ?? [:]
    let rawWorking = Self.count("running", in: counts)
      + Self.count("starting", in: counts)
      + Self.count("compacting", in: counts)
    working = min(active, max(0, rawWorking))

    let remainingAfterWorking = max(0, active - working)
    needsYou = min(
      remainingAfterWorking,
      max(0, Self.count("waiting_approval", in: counts))
    )
    ready = max(0, active - working - needsYou)

    if let value = dictionary["generatedAt"] as? String {
      generatedAt = ISO8601DateFormatter().date(from: value)
    } else {
      generatedAt = nil
    }
  }

  private init(
    connected: Bool,
    active: Int,
    working: Int,
    needsYou: Int,
    ready: Int,
    generatedAt: Date?
  ) {
    self.connected = connected
    self.active = active
    self.working = working
    self.needsYou = needsYou
    self.ready = ready
    self.generatedAt = generatedAt
  }

  private static func count(_ key: String, in counts: [String: Any]) -> Int {
    if let value = counts[key] as? Int {
      return value
    }
    if let value = counts[key] as? NSNumber {
      return value.intValue
    }
    return 0
  }

  func displayed(at date: Date) -> ComplicationSummary {
    guard connected, let expirationDate, date < expirationDate else {
      return .empty
    }
    return self
  }

  var expirationDate: Date? {
    generatedAt?.addingTimeInterval(Self.freshnessInterval)
  }
}

enum ComplicationSnapshotStore {
  static let appGroupIdentifier = "group.com.k9i.ccpocket"
  static let widgetKind = "ccpocket.session-summary"

  private static let snapshotKey = "watch.complication.summary"
  private static let lastTimelineReloadKey =
    "watch.complication.last-timeline-reload"
  private static let timelineRefreshInterval =
    ComplicationSummary.freshnessInterval * 0.75

  @discardableResult
  static func save(dictionary: [String: Any]) -> Bool {
    save(ComplicationSummary(dictionary: dictionary))
  }

  #if DEBUG
  @discardableResult
  static func savePreview() -> Bool {
    save(.preview)
  }
  #endif

  static func load() -> ComplicationSummary {
    guard
      let defaults = UserDefaults(suiteName: appGroupIdentifier),
      let data = defaults.data(forKey: snapshotKey),
      let summary = try? JSONDecoder().decode(ComplicationSummary.self, from: data)
    else {
      return .empty
    }
    return summary
  }

  @discardableResult
  private static func save(_ summary: ComplicationSummary) -> Bool {
    guard
      let defaults = UserDefaults(suiteName: appGroupIdentifier),
      let data = try? JSONEncoder().encode(summary)
    else {
      return false
    }

    let now = Date()
    let shouldReload = shouldReloadTimeline(
      previous: load(),
      current: summary,
      lastReloadAt: defaults.object(forKey: lastTimelineReloadKey) as? Date,
      now: now
    )
    defaults.set(data, forKey: snapshotKey)
    if shouldReload {
      defaults.set(now, forKey: lastTimelineReloadKey)
    }
    return shouldReload
  }

  static func shouldReloadTimeline(
    previous: ComplicationSummary,
    current: ComplicationSummary,
    lastReloadAt: Date?,
    now: Date
  ) -> Bool {
    let previousDisplayed = previous.displayed(at: now)
    let currentDisplayed = current.displayed(at: now)
    let displayedValuesChanged =
      previousDisplayed.connected != currentDisplayed.connected
      || previousDisplayed.active != currentDisplayed.active
      || previousDisplayed.working != currentDisplayed.working
      || previousDisplayed.needsYou != currentDisplayed.needsYou
      || previousDisplayed.ready != currentDisplayed.ready
    let timelineNeedsExtension: Bool
    if !currentDisplayed.connected {
      timelineNeedsExtension = false
    } else if let lastReloadAt {
      timelineNeedsExtension =
        now.timeIntervalSince(lastReloadAt) >= timelineRefreshInterval
    } else {
      timelineNeedsExtension = true
    }
    return displayedValuesChanged || timelineNeedsExtension
  }
}
