import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            AgentWorkspaceView(provider: .codex)
                .tabItem { Label("Codex", systemImage: "sparkles") }

            AgentWorkspaceView(provider: .claude)
                .tabItem { Label("Claude", systemImage: "terminal") }

            ChatView()
                .tabItem { Label("聊天", systemImage: "bubble.left.and.bubble.right") }

            GitView()
                .tabItem { Label("Git", systemImage: "point.3.connected.trianglepath.dotted") }

            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
        .tint(.accentColor)
    }
}
