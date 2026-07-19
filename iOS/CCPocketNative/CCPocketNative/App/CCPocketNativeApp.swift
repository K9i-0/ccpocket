import SwiftUI

@main
struct CCPocketNativeApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .task {
                    await appState.autoConnectIfPossible()
                }
                .onOpenURL { url in
                    if let params = ConnectionURLParser.parse(url) {
                        appState.applyDeepLink(params)
                    }
                }
        }
    }
}
