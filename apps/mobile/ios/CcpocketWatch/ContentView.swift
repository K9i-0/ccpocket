import SwiftUI

struct ContentView: View {
  @EnvironmentObject private var connectivity: WatchConnectivityStore
  @State private var page: DashboardPage

  init() {
    #if DEBUG
    let arguments = ProcessInfo.processInfo.arguments
    let initialPage: DashboardPage = if arguments.contains("-watch-summary") {
      .summary
    } else if arguments.contains("-watch-status") {
      .status
    } else {
      .sessions
    }
    #else
    let initialPage = DashboardPage.sessions
    #endif
    _page = State(initialValue: initialPage)
  }

  var body: some View {
    NavigationStack {
      TabView(selection: $page) {
        SummaryPage(snapshot: connectivity.snapshot)
          .tag(DashboardPage.summary)

        SessionsPage(snapshot: connectivity.snapshot)
          .tag(DashboardPage.sessions)

        StatusPage(snapshot: connectivity.snapshot)
          .tag(DashboardPage.status)
      }
      .tabViewStyle(.page(indexDisplayMode: .automatic))
      .navigationTitle(page.title)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button(action: connectivity.refresh) {
            Image(systemName: "arrow.clockwise")
          }
          .buttonStyle(.plain)
          .foregroundStyle(Color.ccpocketOrange)
          .accessibilityLabel("Refresh")
        }
      }
    }
  }
}

private enum DashboardPage: Int, Hashable {
  case summary
  case sessions
  case status

  var title: String {
    switch self {
    case .summary: "Summary"
    case .sessions: "Sessions"
    case .status: "Status"
    }
  }
}

private struct SummaryPage: View {
  let snapshot: WatchSnapshot

  private var runningCount: Int { snapshot.statusCounts["running", default: 0] }

  private var otherStatuses: [StatusMetric] {
    let known = [
      StatusMetric(
        key: "waiting_approval",
        label: "Needs you",
        symbol: "hand.raised.fill",
        color: .ccpocketApproval,
        count: snapshot.statusCounts["waiting_approval", default: 0]
      ),
      StatusMetric(
        key: "starting",
        label: "Starting",
        symbol: "hourglass",
        color: .ccpocketRunning,
        count: snapshot.statusCounts["starting", default: 0]
      ),
      StatusMetric(
        key: "compacting",
        label: "Compacting",
        symbol: "arrow.triangle.2.circlepath",
        color: .ccpocketCompacting,
        count: snapshot.statusCounts["compacting", default: 0]
      ),
      StatusMetric(
        key: "idle",
        label: "Idle",
        symbol: "pause.fill",
        color: .ccpocketIdle,
        count: snapshot.statusCounts["idle", default: 0]
      ),
      StatusMetric(
        key: "stopped",
        label: "Stopped",
        symbol: "stop.fill",
        color: .secondary,
        count: snapshot.statusCounts["stopped", default: 0]
      ),
      StatusMetric(
        key: "other",
        label: "Other",
        symbol: "circle.fill",
        color: .secondary,
        count: snapshot.statusCounts["other", default: 0]
      ),
    ]
    let knownKeys = Set(known.map(\.key) + ["running"])
    let unknown = snapshot.statusCounts
      .filter { !knownKeys.contains($0.key) && $0.value > 0 }
      .sorted { $0.key < $1.key }
      .map { key, count in
        StatusMetric(
          key: key,
          label: key.replacingOccurrences(of: "_", with: " ").capitalized,
          symbol: "circle.fill",
          color: .secondary,
          count: count
        )
      }
    return known.filter { $0.count > 0 } + unknown
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 8) {
        ConnectionPill(connected: snapshot.connected)

        VStack(alignment: .leading, spacing: 2) {
          HStack(alignment: .firstTextBaseline) {
            Text(runningCount, format: .number)
              .font(.system(size: 42, weight: .semibold, design: .rounded))
              .foregroundStyle(Color.ccpocketRunning)
            Spacer()
            Image(systemName: "bolt.fill")
              .foregroundStyle(Color.ccpocketRunning)
          }
          Text("Running sessions")
            .font(.headline)
          Text("\(snapshot.activeSessionCount) active in total")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .dashboardCard()

        if otherStatuses.isEmpty {
          if snapshot.activeSessionCount == 0 {
            Label("No active sessions", systemImage: "checkmark.circle")
              .font(.caption)
              .foregroundStyle(.secondary)
              .frame(maxWidth: .infinity, alignment: .leading)
              .dashboardCard()
          }
        } else {
          VStack(spacing: 8) {
            ForEach(otherStatuses) { metric in
              HStack(spacing: 7) {
                Image(systemName: metric.symbol)
                  .font(.caption)
                  .foregroundStyle(metric.color)
                  .frame(width: 16)
                Text(metric.label)
                  .font(.caption)
                Spacer()
                Text(metric.count, format: .number)
                  .font(.headline.monospacedDigit())
              }
            }
          }
          .dashboardCard()
        }
      }
      .padding(.horizontal, 4)
      .padding(.bottom, 8)
    }
  }
}

private struct StatusMetric: Identifiable {
  let key: String
  let label: String
  let symbol: String
  let color: Color
  let count: Int

  var id: String { key }
}

private struct SessionsPage: View {
  let snapshot: WatchSnapshot

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 8) {
        if !snapshot.connected {
          Label("Bridge offline", systemImage: "exclamationmark.icloud")
            .font(.caption)
            .foregroundStyle(Color.ccpocketApproval)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dashboardCard()
        }

        if snapshot.sessions.isEmpty {
          VStack(spacing: 7) {
            Image(systemName: snapshot.connected ? "checkmark.circle" : "iphone.slash")
              .font(.title2)
              .foregroundStyle(snapshot.connected ? Color.ccpocketOnline : .secondary)
            Text(snapshot.connected ? "No active sessions" : "iPhone unavailable")
              .font(.headline)
              .multilineTextAlignment(.center)
            Text(snapshot.connected ? "Start one in ccpocket." : "Open ccpocket on iPhone.")
              .font(.caption2)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
          }
          .frame(maxWidth: .infinity)
          .dashboardCard()
        } else {
          ForEach(snapshot.sessions) { session in
            NavigationLink {
              SessionDetailView(sessionId: session.id)
            } label: {
              SessionCard(session: session)
            }
            .buttonStyle(.plain)
          }
        }
      }
      .padding(.horizontal, 4)
      .padding(.bottom, 8)
    }
  }
}

private struct SessionCard: View {
  let session: WatchSession

  var body: some View {
    HStack(spacing: 9) {
      Circle()
        .fill(session.statusColor)
        .frame(width: 9, height: 9)
        .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 3) {
        Text(session.title)
          .font(.headline)
          .lineLimit(1)
        HStack(spacing: 4) {
          Image(systemName: session.providerSymbol)
          Text(session.statusLabel)
        }
        .font(.caption2)
        .foregroundStyle(session.statusColor)
        if !session.lastMessage.isEmpty {
          Text(session.lastMessage)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
      }

      Spacer(minLength: 0)
      Image(systemName: "chevron.right")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.tertiary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .dashboardCard(highlighted: session.permission != nil)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(session.title), \(session.statusLabel)")
    .accessibilityHint("Opens session actions")
  }
}

private struct StatusPage: View {
  let snapshot: WatchSnapshot

  private var endpoint: String {
    guard !snapshot.bridgeHost.isEmpty else { return "Bridge unavailable" }
    let host = snapshot.bridgeHost.contains(":")
      ? "[\(snapshot.bridgeHost)]"
      : snapshot.bridgeHost
    if let port = snapshot.bridgePort {
      return "\(host):\(port)"
    }
    return host
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 8) {
        VStack(alignment: .leading, spacing: 7) {
          HStack(spacing: 6) {
            Circle()
              .fill(snapshot.connected ? Color.ccpocketOnline : Color.ccpocketIdle)
              .frame(width: 8, height: 8)
            Text(snapshot.connected ? "Bridge connected" : "Bridge offline")
              .font(.headline)
          }
          Text(endpoint)
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
          HStack {
            Text("Port")
              .foregroundStyle(.secondary)
            Spacer()
            Text(snapshot.bridgePort.map(String.init) ?? "—")
              .font(.body.monospacedDigit())
          }
          .font(.caption)
        }
        .dashboardCard()

        if snapshot.usage.isEmpty {
          Label("Usage unavailable", systemImage: "gauge.with.dots.needle.67percent")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dashboardCard()
        } else {
          ForEach(snapshot.usage) { provider in
            CompactUsageCard(provider: provider)
          }
        }
      }
      .padding(.horizontal, 4)
      .padding(.bottom, 8)
    }
  }
}

private struct CompactUsageCard: View {
  let provider: WatchUsage

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Image(systemName: provider.provider == "codex"
          ? "chevron.left.forwardslash.chevron.right"
          : "sparkles")
          .foregroundStyle(Color.ccpocketTeal)
        Text(provider.displayName)
          .font(.headline)
      }

      if let error = provider.error,
         provider.fiveHour == nil,
         provider.sevenDay == nil {
        Text(error)
          .font(.caption2)
          .foregroundStyle(.secondary)
      } else {
        if let window = provider.fiveHour {
          CompactUsageRow(label: "5 hours", window: window)
        }
        if let window = provider.sevenDay {
          CompactUsageRow(label: "7 days", window: window)
        }
      }
    }
    .dashboardCard()
  }
}

private struct CompactUsageRow: View {
  let label: String
  let window: WatchUsageWindow

  var body: some View {
    VStack(spacing: 3) {
      HStack {
        Text(label)
        Spacer()
        Text(window.remaining, format: .percent.precision(.fractionLength(0)))
          .monospacedDigit()
      }
      .font(.caption2)
      ProgressView(value: window.remaining)
        .tint(.ccpocketTeal)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      "\(label), \(window.remaining.formatted(.percent.precision(.fractionLength(0)))) remaining"
    )
  }
}

private struct ConnectionPill: View {
  let connected: Bool

  var body: some View {
    HStack(spacing: 5) {
      Circle()
        .fill(connected ? Color.ccpocketOnline : Color.ccpocketIdle)
        .frame(width: 7, height: 7)
      Text(connected ? "Bridge connected" : "Bridge offline")
        .font(.caption2)
      Spacer()
    }
    .foregroundStyle(connected ? Color.primary : Color.secondary)
  }
}

private extension View {
  func dashboardCard(highlighted: Bool = false) -> some View {
    padding(10)
      .background {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(highlighted ? Color.ccpocketOrange.opacity(0.16) : Color.white.opacity(0.08))
      }
      .overlay {
        if highlighted {
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(Color.ccpocketOrange.opacity(0.35), lineWidth: 1)
        }
      }
  }
}

#Preview {
  ContentView()
    .environmentObject(WatchConnectivityStore())
}
