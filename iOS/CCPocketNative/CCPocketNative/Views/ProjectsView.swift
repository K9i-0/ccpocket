import SwiftUI

struct ProjectsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        NavigationStack {
            List {
                Section("新建会话") {
                    TextField("项目路径", text: $appState.projectPathDraft, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Picker("提供方", selection: $appState.selectedProvider) {
                        ForEach(Provider.allCases) { provider in
                            Label(provider.title, systemImage: provider.symbolName).tag(provider)
                        }
                    }
                    Picker("权限模式", selection: $appState.selectedPermissionMode) {
                        ForEach(PermissionMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    Button {
                        Task { await appState.startSession() }
                    } label: {
                        Label("启动会话", systemImage: "play.fill")
                    }
                    .disabled(!appState.connectionState.isConnected || appState.projectPathDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Section("项目历史") {
                    if appState.projects.isEmpty {
                        Text("Bridge 返回本机工作区后，这里会显示项目历史。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(appState.projects, id: \.self) { project in
                            Button {
                                appState.projectPathDraft = project
                                Task { await appState.startSession(projectPath: project) }
                            } label: {
                                ProjectRow(path: project)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !appState.allowedDirectories.isEmpty {
                    Section("允许访问的目录") {
                        ForEach(appState.allowedDirectories, id: \.self) { directory in
                            Text(directory)
                                .font(.callout.monospaced())
                                .lineLimit(2)
                        }
                    }
                }
            }
            .navigationTitle("项目")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { try? await appState.refreshBridgeState() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(!appState.connectionState.isConnected)
                }
            }
        }
    }
}

struct ProjectRow: View {
    var path: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder")
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 3) {
                Text(path.split(separator: "/").last.map(String.init) ?? path)
                    .font(.headline)
                Text(path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}
