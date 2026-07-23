import SwiftUI
import WidgetKit

struct ComplicationSummaryContent: View {
  let summary: ComplicationSummary
  let renderingMode: WidgetRenderingMode

  private let workingColor = Color(
    red: 0.302,
    green: 0.639,
    blue: 1.0
  )
  private let approvalColor = Color(
    red: 0.992,
    green: 0.729,
    blue: 0.455
  )
  private let readyColor = Color(
    red: 0.431,
    green: 0.431,
    blue: 0.431
  )

  var body: some View {
    ZStack {
      if summary.connected {
        statusRing
        summaryLabel
      } else {
        disconnectedLabel
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabel)
  }

  private var statusRing: some View {
    ZStack {
      Circle()
        .stroke(Color.secondary.opacity(0.22), lineWidth: 4)

      ForEach(Array(ringSegments.enumerated()), id: \.offset) { _, segment in
        Circle()
          .trim(from: segment.start, to: segment.end)
          .stroke(
            segment.color,
            style: StrokeStyle(lineWidth: 4, lineCap: .round)
          )
          .rotationEffect(.degrees(-90))
      }
    }
    .padding(2)
  }

  private var summaryLabel: some View {
    VStack(spacing: -1) {
      Text(summary.active, format: .number)
        .font(.system(size: 24, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .minimumScaleFactor(0.65)

      if summary.needsYou > 0 {
        HStack(spacing: 1) {
          Image(systemName: "exclamationmark")
          Text(summary.needsYou, format: .number)
            .monospacedDigit()
        }
        .font(.system(size: 9, weight: .bold, design: .rounded))
        .foregroundStyle(displayColor(approvalColor, fallbackOpacity: 1))
      } else {
        HStack(spacing: 1) {
          Image(systemName: "bolt.fill")
          Text(summary.working, format: .number)
            .monospacedDigit()
        }
        .font(.system(size: 8, weight: .semibold, design: .rounded))
        .foregroundStyle(.secondary)
      }
    }
  }

  private var disconnectedLabel: some View {
    VStack(spacing: 1) {
      Image(systemName: "iphone.slash")
        .font(.system(size: 18, weight: .semibold))
      Text("—")
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
  }

  private var ringSegments: [StatusRingSegment] {
    let total = summary.active
    guard total > 0 else { return [] }

    let values = [
      (summary.working, displayColor(workingColor, fallbackOpacity: 1)),
      (summary.needsYou, displayColor(approvalColor, fallbackOpacity: 0.72)),
      (summary.ready, displayColor(readyColor, fallbackOpacity: 0.38)),
    ]
    let visibleCount = values.filter { $0.0 > 0 }.count
    let gap = visibleCount > 1 ? 0.018 : 0
    var cursor = 0.0

    return values.compactMap { count, color in
      guard count > 0 else { return nil }
      let fraction = Double(count) / Double(total)
      let start = cursor
      let end = min(1, cursor + fraction)
      cursor = end
      let segmentGap = min(gap, fraction * 0.25)
      return StatusRingSegment(
        start: start + segmentGap,
        end: end - segmentGap,
        color: color
      )
    }
  }

  private func displayColor(
    _ fullColor: Color,
    fallbackOpacity: Double
  ) -> Color {
    renderingMode == .fullColor
      ? fullColor
      : Color.white.opacity(fallbackOpacity)
  }

  private var accessibilityLabel: String {
    guard summary.connected else {
      return "ccpocket, Bridge disconnected"
    }
    return """
    ccpocket, \(summary.active) active sessions, \
    \(summary.working) working, \
    \(summary.needsYou) need you, \
    \(summary.ready) ready
    """
  }
}

private struct StatusRingSegment {
  let start: Double
  let end: Double
  let color: Color
}

#if DEBUG
struct ComplicationPreviewScreen: View {
  var body: some View {
    VStack(spacing: 12) {
      Text("Session Summary")
        .font(.caption)
        .foregroundStyle(.secondary)

      ZStack {
        Circle()
          .fill(Color.white.opacity(0.08))
        ComplicationSummaryContent(
          summary: .preview,
          renderingMode: .fullColor
        )
        .padding(3)
      }
      .frame(width: 72, height: 72)

      Text("3 Active · 1 Needs You")
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
  }
}
#endif
