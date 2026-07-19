import SwiftUI
import UIKit

struct AgentWorkspaceView: View {
    @Environment(AppState.self) private var appState
    let provider: Provider

    @State private var searchText = ""
    @State private var manualProjectPath = ""
    @State private var expandedProjects: Set<String> = []

    private var runningSessions: [SessionInfo] {
        appState.sessions
            .filter { $0.provider == provider || $0.provider == nil }
            .filter(matchesSearch)
            .sorted { $0.lastActivityAt > $1.lastActivityAt }
    }

    private var recentSessions: [RecentSession] {
        appState.recentSessions
            .filter { $0.provider == provider || $0.provider == nil }
            .filter(matchesSearch)
            .sorted { $0.modified > $1.modified }
    }

    private var projectFolders: [ProjectFolder] {
        var orderedKeys: [String] = []
        var pathsByKey: [String: String] = [:]

        func addPath(_ path: String) {
            let key = path.normalizedProjectPathKey
            guard !key.isEmpty else { return }
            if pathsByKey[key] == nil {
                orderedKeys.append(key)
                pathsByKey[key] = path
            }
        }

        appState.projects.forEach(addPath)
        runningSessions.forEach { addPath($0.projectPath) }
        recentSessions.forEach { addPath($0.resumeCwd ?? $0.projectPath) }

        let folders = orderedKeys.compactMap { key -> ProjectFolder? in
            guard let path = pathsByKey[key] else { return nil }
            return ProjectFolder(
                id: key,
                path: path,
                runningSessions: runningSessions.filter { $0.projectPath.normalizedProjectPathKey == key },
                recentSessions: recentSessions.filter { ($0.resumeCwd ?? $0.projectPath).normalizedProjectPathKey == key }
            )
        }
        return folders
            .filter {
                !$0.runningSessions.isEmpty
                    || !$0.recentSessions.isEmpty
                    || searchText.isEmpty
                    || $0.path.localizedCaseInsensitiveContains(searchText)
                    || $0.name.localizedCaseInsensitiveContains(searchText)
            }
    }

    private var manualPath: String {
        manualProjectPath.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var manualProjectIsStarting: Bool {
        !manualPath.isEmpty && appState.isProjectStarting(projectPath: manualPath, provider: provider)
    }

    private var manualProjectTitle: String {
        if manualProjectIsStarting { return "正在启动" }
        return "点击创建对话"
    }

    private var manualProjectSubtitle: String {
        let model = appState.selectedModel(for: provider) ?? "默认模型"
        return "\(provider.title) · \(model)"
    }

    var body: some View {
        @Bindable var appState = appState

        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label(provider == .codex ? "Codex 工作区" : "Claude Code 工作区", systemImage: provider.symbolName)
                            .font(.headline)

                        TextField("输入项目文件夹路径", text: $manualProjectPath, axis: .vertical)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.callout.monospaced())

                        Picker("权限", selection: $appState.selectedPermissionMode) {
                            ForEach(PermissionMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }

                        Button {
                            let path = manualPath
                            Task {
                                await appState.startSession(projectPath: path, provider: provider)
                            }
                        } label: {
                            ProjectLaunchRow(
                                title: manualProjectTitle,
                                subtitle: manualProjectSubtitle,
                                icon: "plus.bubble",
                                tint: .secondary,
                                isStarting: manualProjectIsStarting
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(!appState.connectionState.isConnected || manualPath.isEmpty || manualProjectIsStarting)
                    }
                    .padding(.vertical, 6)
                } header: {
                    Text("新建")
                } footer: {
                    Text("每次创建都会打开一个新的对话；运行中的对话可在项目文件夹内进入或停止。")
                }

                Section("项目文件夹") {
                    if projectFolders.isEmpty {
                        ContentUnavailableView(
                            "暂无项目",
                            systemImage: "folder",
                            description: Text("连接 Bridge 后，这里会按项目文件夹整理 \(provider.title) 对话。")
                        )
                    } else {
                        ForEach(projectFolders) { folder in
                            VStack(alignment: .leading, spacing: 8) {
                                Button {
                                    if expandedProjects.contains(folder.id) {
                                        expandedProjects.remove(folder.id)
                                    } else {
                                        expandedProjects.insert(folder.id)
                                    }
                                } label: {
                                    ProjectFolderLabel(
                                        folder: folder,
                                        provider: provider,
                                        isExpanded: expandedProjects.contains(folder.id)
                                    )
                                }
                                .buttonStyle(.plain)

                                if expandedProjects.contains(folder.id) {
                                    ProjectFolderContent(folder: folder, provider: provider)
                                        .padding(.leading, 40)
                                        .transaction { transaction in
                                            transaction.animation = nil
                                        }
                                }
                            }
                            .transaction { transaction in
                                transaction.animation = nil
                            }
                        }
                    }
                }

                if !appState.allowedDirectories.isEmpty {
                    Section("允许访问") {
                        ForEach(appState.allowedDirectories, id: \.self) { directory in
                            Label(directory, systemImage: "lock.open")
                                .font(.caption.monospaced())
                                .lineLimit(2)
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(TapGesture().onEnded {
                dismissWorkspaceKeyboard()
            })
            .searchable(text: $searchText, prompt: "搜索项目或对话")
            .navigationTitle(provider == .codex ? "Codex" : "Claude Code")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ConnectionBadge(state: appState.connectionState)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        Task { try? await appState.refreshBridgeState() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(!appState.connectionState.isConnected)
                }
            }
            .onAppear {
                if manualProjectPath.isEmpty {
                    manualProjectPath = appState.projectPathDraft
                }
            }
        }
    }

    private func matchesSearch(_ session: SessionInfo) -> Bool {
        guard !searchText.isEmpty else { return true }
        return session.displayName.localizedCaseInsensitiveContains(searchText)
            || session.projectPath.localizedCaseInsensitiveContains(searchText)
            || (session.lastMessage ?? "").localizedCaseInsensitiveContains(searchText)
    }

    private func matchesSearch(_ session: RecentSession) -> Bool {
        guard !searchText.isEmpty else { return true }
        return session.title.localizedCaseInsensitiveContains(searchText)
            || session.projectPath.localizedCaseInsensitiveContains(searchText)
            || session.preview.localizedCaseInsensitiveContains(searchText)
    }
}

private struct ProjectFolder: Identifiable, Hashable {
    let id: String
    let path: String
    let runningSessions: [SessionInfo]
    let recentSessions: [RecentSession]

    var name: String { path.projectDisplayName }
    var hasActiveContent: Bool { !runningSessions.isEmpty || !recentSessions.isEmpty }
    var hasRunningSession: Bool { !runningSessions.isEmpty }
    var historyCount: Int { recentSessions.count }
}

private struct ProjectFolderLabel: View {
    let folder: ProjectFolder
    let provider: Provider
    let isExpanded: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "folder")
                    .font(.title3)
                    .foregroundStyle(Color.secondary)
            }
            .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(folder.name)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    if folder.historyCount > 0 {
                        Text("\(folder.historyCount)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
                    }
                }
                Text(folder.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }
}

private struct ProjectFolderContent: View {
    @Environment(AppState.self) private var appState
    let folder: ProjectFolder
    let provider: Provider

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                Task {
                    await appState.startSession(projectPath: folder.path, provider: provider)
                }
            } label: {
                ProjectLaunchRow(
                    title: folderStartTitle,
                    subtitle: folderStartSubtitle,
                    icon: "plus.bubble",
                    tint: .secondary,
                    isStarting: appState.isProjectStarting(projectPath: folder.path, provider: provider)
                )
            }
            .buttonStyle(.plain)
            .disabled(
                !appState.connectionState.isConnected
                    || appState.isProjectStarting(projectPath: folder.path, provider: provider)
            )

            ForEach(folder.runningSessions) { session in
                RunningSessionControl(session: session, isActive: appState.activeSessionID == session.id)
            }

            ForEach(visibleRecentSessions) { session in
                Button {
                    Task { await appState.resume(session) }
                } label: {
                    RecentSessionRow(session: session)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }

    private var folderStartTitle: String {
        if appState.isProjectStarting(projectPath: folder.path, provider: provider) { return "正在创建对话" }
        return "点击创建新对话"
    }

    private var folderStartSubtitle: String {
        let model = appState.selectedModel(for: provider) ?? "默认模型"
        return "\(provider.title) · \(model)"
    }

    private var visibleRecentSessions: [RecentSession] {
        folder.recentSessions.filter { recent in
            !folder.runningSessions.contains { running in
                isSameConversation(running: running, recent: recent)
            }
        }
    }

    private func isSameConversation(running: SessionInfo, recent: RecentSession) -> Bool {
        if running.id == recent.sessionId || running.claudeSessionId == recent.sessionId {
            return true
        }
        guard providerMatches(running.provider, recent.provider) else {
            return false
        }
        let sameTitle = normalized(running.displayName) == normalized(recent.title)
        let runningPreview = normalized(running.lastMessage ?? "")
        let recentPreview = normalized(recent.preview)
        return sameTitle && !runningPreview.isEmpty && (
            runningPreview == recentPreview
                || runningPreview.hasPrefix(recentPreview)
                || recentPreview.hasPrefix(runningPreview)
        )
    }

    private func providerMatches(_ lhs: Provider?, _ rhs: Provider?) -> Bool {
        lhs == rhs || lhs == nil || rhs == nil
    }

    private func normalized(_ value: String) -> String {
        value
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

private struct ProjectLaunchRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let isStarting: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.14))
                    .frame(width: 30, height: 30)
                if isStarting {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: icon)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(tint)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

private struct RunningSessionControl: View {
    @Environment(AppState.self) private var appState
    let session: SessionInfo
    let isActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            Button {
                Task { await appState.selectSession(session) }
            } label: {
                HStack(spacing: 10) {
                    ZStack(alignment: .bottomTrailing) {
                        Image(systemName: session.provider?.symbolName ?? "terminal")
                            .font(.title3)
                            .foregroundStyle(isActive ? Color.green : Color.secondary)
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(Color(uiColor: .systemBackground), lineWidth: 1.5))
                            .offset(x: 2, y: 2)
                    }
                    .frame(width: 28)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(session.displayName)
                                .font(.headline)
                                .lineLimit(1)
                            StatusPill(icon: "checkmark.circle.fill", title: session.status.title, tint: .green)
                        }
                        if let lastMessage = session.lastMessage, !lastMessage.isEmpty {
                            Text(lastMessage)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)

            Button(role: .destructive) {
                Task { await appState.stopSession(session.id) }
            } label: {
                Image(systemName: "stop.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("停止项目")
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

struct ConnectionBadge: View {
    var state: ConnectionState

    var body: some View {
        let color: Color = state.isConnected ? .green : .orange
        StatusPill(icon: state.isConnected ? "checkmark.circle.fill" : "wifi.slash", title: state.title, tint: color)
    }
}

struct SessionRow: View {
    var session: SessionInfo
    var isActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: session.provider?.symbolName ?? "terminal")
                .font(.title3)
                .foregroundStyle(isActive ? Color.green : Color.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(session.displayName)
                        .font(.headline)
                        .lineLimit(1)
                    StatusPill(icon: statusIcon, title: session.status.title, tint: statusColor)
                }
                Text(session.projectPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let lastMessage = session.lastMessage, !lastMessage.isEmpty {
                    Text(lastMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private var statusColor: Color {
        switch session.status {
        case .running: .blue
        case .waitingApproval: .orange
        case .idle: .green
        case .starting, .compacting: .purple
        case .unknown: .secondary
        }
    }

    private var statusIcon: String {
        switch session.status {
        case .running: "play.circle.fill"
        case .waitingApproval: "exclamationmark.circle.fill"
        case .idle: "checkmark.circle.fill"
        case .starting: "timer"
        case .compacting: "arrow.triangle.2.circlepath"
        case .unknown: "questionmark.circle"
        }
    }
}

struct RecentSessionRow: View {
    var session: RecentSession

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bubble.left")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(session.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(session.preview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Text(session.modified)
                    if !session.gitBranch.isEmpty {
                        Label(session.gitBranch, systemImage: "arrow.branch")
                    }
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            }

            Spacer(minLength: 8)

            Image(systemName: "play.circle")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

@MainActor
private func dismissWorkspaceKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
