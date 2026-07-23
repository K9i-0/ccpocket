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

  private var statusMetrics: [StatusMetric] {
    let total = max(0, snapshot.activeSessionCount)
    let rawWorking = snapshot.statusCounts["running", default: 0]
      + snapshot.statusCounts["starting", default: 0]
      + snapshot.statusCounts["compacting", default: 0]
    let working = min(total, max(0, rawWorking))
    let needsYou = min(
      total - working,
      max(0, snapshot.statusCounts["waiting_approval", default: 0])
    )
    let ready = total - working - needsYou
    return [
      StatusMetric(
        key: "working",
        label: "Working",
        color: .ccpocketRunning,
        count: working
      ),
      StatusMetric(
        key: "needs_you",
        label: "Needs You",
        color: .ccpocketApproval,
        count: needsYou
      ),
      StatusMetric(
        key: "ready",
        label: "Ready",
        color: .ccpocketIdle,
        count: ready
      )
    ]
  }

  var body: some View {
    ViewThatFits(in: .vertical) {
      summaryContent(compact: false)
      summaryContent(compact: true)
    }
    .padding(.horizontal, 4)
    .padding(.bottom, 8)
  }

  @ViewBuilder
  private func summaryContent(compact: Bool) -> some View {
    VStack(spacing: compact ? 5 : 7) {
      if !compact {
        ConnectionPill(connected: snapshot.connected)
      }

      HStack(alignment: .center) {
        VStack(alignment: .leading, spacing: 0) {
          HStack(spacing: 5) {
            if compact {
              Circle()
                .fill(snapshot.connected ? Color.ccpocketOnline : Color.ccpocketIdle)
                .frame(width: 6, height: 6)
            }
            Text("Active")
              .font(.headline)
          }
          Text(snapshot.connected
            ? (compact ? "This Bridge" : "Across this Bridge")
            : "Bridge unavailable")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Text(snapshot.activeSessionCount, format: .number)
          .font(.system(size: compact ? 30 : 38, weight: .semibold, design: .rounded))
          .foregroundStyle(Color.ccpocketOrange)
          .monospacedDigit()
      }
      .dashboardCard(contentPadding: compact ? 7 : 10)

      HStack(spacing: 5) {
        ForEach(statusMetrics) { metric in
          VStack(spacing: 3) {
            HStack(spacing: 4) {
              Circle()
                .fill(metric.color)
                .frame(width: 7, height: 7)
              Text(metric.count, format: .number)
                .font(.headline.monospacedDigit())
            }
            Text(metric.label)
              .font(.system(size: 9, weight: .medium))
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .minimumScaleFactor(0.75)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, compact ? 4 : 7)
          .background {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
              .fill(Color.white.opacity(0.08))
          }
        }
      }
    }
  }
}

private struct StatusMetric: Identifiable {
  let key: String
  let label: String
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
        if !session.lastMessage.isEmpty {
          Text(session.lastMessage)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
      }

      Spacer(minLength: 0)
      VStack(spacing: 5) {
        Image(systemName: session.providerSymbol)
          .font(.caption2)
          .foregroundStyle(.secondary)
        Image(systemName: "chevron.right")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.tertiary)
      }
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
  func dashboardCard(
    highlighted: Bool = false,
    contentPadding: CGFloat = 10
  ) -> some View {
    padding(contentPadding)
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
