import SwiftUI

@main
struct CcpocketWatchApp: App {
  @StateObject private var connectivity = WatchConnectivityStore()

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(connectivity)
        .tint(.ccpocketOrange)
    }
  }
}
