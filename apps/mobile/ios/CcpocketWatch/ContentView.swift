import SwiftUI

struct ContentView: View {
  @EnvironmentObject private var connectivity: WatchConnectivityStore

  var body: some View {
    NavigationStack {
      Group {
        if connectivity.snapshot.sessions.isEmpty {
          EmptySessionsView(
            connected: connectivity.snapshot.connected,
            usage: connectivity.snapshot.usage
          )
        } else {
          SessionListView(
            sessions: connectivity.snapshot.sessions,
            connected: connectivity.snapshot.connected
          )
        }
      }
      .navigationTitle("\(connectivity.snapshot.activeSessionCount) Active")
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

private struct SessionListView: View {
  @EnvironmentObject private var connectivity: WatchConnectivityStore
  let sessions: [WatchSession]
  let connected: Bool

  var body: some View {
    List {
      if !connected {
        Label("Bridge offline", systemImage: "exclamationmark.icloud")
          .font(.caption)
          .foregroundStyle(Color.ccpocketApproval)
      }
      ForEach(sessions) { session in
        NavigationLink {
          SessionDetailView(sessionId: session.id)
        } label: {
          SessionRow(session: session)
        }
      }

      NavigationLink {
        UsageView(usage: connectivity.snapshot.usage)
      } label: {
        Label("Usage", systemImage: "gauge.with.dots.needle.67percent")
          .foregroundStyle(Color.ccpocketTeal)
      }
    }
  }
}

private struct SessionRow: View {
  let session: WatchSession

  var body: some View {
    HStack(spacing: 9) {
      Circle()
        .fill(session.statusColor)
        .frame(width: 9, height: 9)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text(session.title)
          .font(.headline)
          .lineLimit(1)
        HStack(spacing: 4) {
          Image(systemName: session.providerSymbol)
          Text(session.statusLabel)
        }
        .font(.caption2)
        .foregroundStyle(session.statusColor)
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(session.title), \(session.statusLabel)")
  }
}

private struct EmptySessionsView: View {
  let connected: Bool
  let usage: [WatchUsage]

  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: connected ? "checkmark.circle" : "iphone.slash")
        .font(.title2)
        .foregroundStyle(connected ? Color.ccpocketOnline : Color.secondary)
      Text(connected ? "No active sessions" : "iPhone unavailable")
        .font(.headline)
        .multilineTextAlignment(.center)
      Text(connected ? "Start one in ccpocket." : "Open ccpocket on your iPhone.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      NavigationLink {
        UsageView(usage: usage)
      } label: {
        Label("Usage", systemImage: "gauge.with.dots.needle.67percent")
      }
      .buttonStyle(.bordered)
      .tint(.ccpocketTeal)
    }
    .padding()
  }
}

#Preview {
  ContentView()
    .environmentObject(WatchConnectivityStore())
}
