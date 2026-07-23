import SwiftUI

@main
struct CcpocketWatchApp: App {
  @StateObject private var connectivity = WatchConnectivityStore()

  var body: some Scene {
    WindowGroup {
      rootView
    }
  }

  @ViewBuilder
  private var rootView: some View {
    #if DEBUG
    if ProcessInfo.processInfo.arguments.contains("-watch-complication-preview") {
      ComplicationPreviewScreen()
    } else {
      ContentView()
        .environmentObject(connectivity)
        .tint(.ccpocketOrange)
    }
    #else
    ContentView()
      .environmentObject(connectivity)
      .tint(.ccpocketOrange)
    #endif
  }
}
