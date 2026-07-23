import SwiftUI
import WidgetKit

private struct SummaryEntry: TimelineEntry {
  let date: Date
  let summary: ComplicationSummary
}

private struct SummaryProvider: TimelineProvider {
  func placeholder(in context: Context) -> SummaryEntry {
    SummaryEntry(date: Date(), summary: .preview)
  }

  func getSnapshot(
    in context: Context,
    completion: @escaping (SummaryEntry) -> Void
  ) {
    let now = Date()
    let summary = context.isPreview
      ? ComplicationSummary.preview
      : ComplicationSnapshotStore.load().displayed(at: now)
    completion(SummaryEntry(date: now, summary: summary))
  }

  func getTimeline(
    in context: Context,
    completion: @escaping (Timeline<SummaryEntry>) -> Void
  ) {
    let now = Date()
    let storedSummary = ComplicationSnapshotStore.load()
    var entries = [
      SummaryEntry(date: now, summary: storedSummary.displayed(at: now))
    ]
    if let expirationDate = storedSummary.expirationDate,
       expirationDate > now
    {
      entries.append(SummaryEntry(date: expirationDate, summary: .empty))
    }
    completion(Timeline(entries: entries, policy: .never))
  }
}

private struct SummaryComplicationView: View {
  @Environment(\.widgetRenderingMode) private var renderingMode

  let entry: SummaryEntry

  var body: some View {
    ZStack {
      AccessoryWidgetBackground()
      ComplicationSummaryContent(
        summary: entry.summary,
        renderingMode: renderingMode
      )
    }
    .widgetLabel {
      if !entry.summary.connected {
        Text("Bridge Offline")
      } else if entry.summary.needsYou > 0 {
        Text("\(entry.summary.needsYou) Needs You")
      } else {
        Text("\(entry.summary.active) Active")
      }
    }
  }
}

private struct CcpocketSummaryComplication: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(
      kind: ComplicationSnapshotStore.widgetKind,
      provider: SummaryProvider()
    ) { entry in
      SummaryComplicationView(entry: entry)
    }
    .configurationDisplayName("Session Summary")
    .description("Shows active sessions and whether any need your attention.")
    .supportedFamilies([.accessoryCircular, .accessoryCorner])
  }
}

@main
struct CcpocketWatchWidgetBundle: WidgetBundle {
  var body: some Widget {
    CcpocketSummaryComplication()
  }
}

#Preview(as: .accessoryCircular) {
  CcpocketSummaryComplication()
} timeline: {
  SummaryEntry(date: .now, summary: .preview)
  SummaryEntry(date: .now, summary: .empty)
}

#Preview("Corner", as: .accessoryCorner) {
  CcpocketSummaryComplication()
} timeline: {
  SummaryEntry(date: .now, summary: .preview)
  SummaryEntry(date: .now, summary: .empty)
}
