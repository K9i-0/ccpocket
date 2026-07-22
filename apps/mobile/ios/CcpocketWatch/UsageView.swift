import SwiftUI

struct UsageView: View {
  let usage: [WatchUsage]

  var body: some View {
    Group {
      if usage.isEmpty {
        VStack(spacing: 8) {
          Image(systemName: "gauge.with.dots.needle.67percent")
            .font(.title2)
            .foregroundStyle(Color.ccpocketTeal)
          Text("Usage unavailable")
            .font(.headline)
          Text("Refresh after connecting to Bridge.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
      } else {
        List(usage) { provider in
          Section(provider.displayName) {
            if let error = provider.error,
               provider.fiveHour == nil,
               provider.sevenDay == nil {
              Text(error)
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
              if let window = provider.fiveHour {
                UsageGauge(label: "5 hours", window: window)
              }
              if let window = provider.sevenDay {
                UsageGauge(label: "7 days", window: window)
              }
            }
          }
        }
      }
    }
    .navigationTitle("Usage")
  }
}

private struct UsageGauge: View {
  let label: String
  let window: WatchUsageWindow

  var body: some View {
    HStack(spacing: 10) {
      Gauge(value: window.remaining) {
        Text(label)
      } currentValueLabel: {
        Text(window.remaining, format: .percent.precision(.fractionLength(0)))
          .font(.caption2)
      }
      .gaugeStyle(.accessoryCircularCapacity)
      .tint(.ccpocketTeal)

      VStack(alignment: .leading, spacing: 2) {
        Text(label)
          .font(.headline)
        Text("remaining")
          .font(.caption2)
          .foregroundStyle(.secondary)
        if let resetsAt = window.resetsAt {
          Text(resetsAt, style: .relative)
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
    }
    .accessibilityElement(children: .combine)
  }
}
