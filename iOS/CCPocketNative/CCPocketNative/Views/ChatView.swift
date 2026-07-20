import SwiftUI
import UIKit

struct ChatView: View {
    @Environment(AppState.self) private var appState
    @Namespace private var glassNamespace

    var body: some View {
        @Bindable var appState = appState

        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(appState.chatItems) { item in
                                ChatBubble(item: item)
                                    .id(item.id)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 86)
                        .padding(.bottom, appState.pendingPermissions.isEmpty ? 110 : 250)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .simultaneousGesture(TapGesture().onEnded {
                        dismissKeyboard()
                    })
                    .onChange(of: appState.chatItems.count) { _, _ in
                        if let last = appState.chatItems.last {
                            withAnimation(.smooth(duration: 0.25)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                VStack(spacing: 10) {
                    if let request = appState.pendingPermissions.values.first {
                        PermissionRequestPanel(request: request)
                    }
                    PromptInputBar(text: $appState.promptDraft)
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
            }
            .navigationTitle(appState.activeSession?.displayName ?? "聊天")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    SessionStatusGlass(session: appState.activeSession, state: appState.connectionState)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await appState.stopActiveSession() }
                    } label: {
                        Image(systemName: "stop.fill")
                    }
                    .disabled(appState.activeSessionID == nil)
                }
            }
            .overlay(alignment: .top) {
                ChatContextBar()
                    .padding(.horizontal)
                    .padding(.top, 6)
            }
            .overlay {
                if appState.chatItems.isEmpty {
                    EmptyContentState(
                        systemImage: "bubble.left.and.text.bubble.right",
                        title: "暂无活动对话",
                        subtitle: "选择一个会话或启动项目，然后发送提示词。"
                    )
                }
            }
        }
    }
}

struct ChatContextBar: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        Menu {
            Section("对话设置") {
                Picker("Agent", selection: $appState.selectedProvider) {
                    ForEach(Provider.allCases) { provider in
                        Label(provider.title, systemImage: provider.symbolName).tag(provider)
                    }
                }

                PermissionModeMenu(selection: $appState.selectedPermissionMode)

                if contextProvider == .codex {
                    Picker("模型", selection: $appState.selectedCodexModel) {
                        Text("默认模型").tag("")
                        ForEach(appState.codexModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                } else {
                    Picker("模型", selection: $appState.selectedClaudeModel) {
                        Text("默认模型").tag("")
                        ForEach(appState.claudeModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                }
            }

            if let projectPath = currentProjectPath {
                Section("新建同项目对话") {
                    Button {
                        Task { await appState.startSession(projectPath: projectPath, provider: contextProvider) }
                    } label: {
                        Label("新建 \(contextProvider.title) 对话", systemImage: "plus.bubble")
                    }
                }
            }

            if !currentProjectRunningSessions.isEmpty {
                Section("当前项目运行中") {
                    ForEach(currentProjectRunningSessions) { session in
                        Button {
                            Task { await appState.selectSession(session) }
                        } label: {
                            Label(session.displayName, systemImage: session.provider?.symbolName ?? "terminal")
                        }
                    }
                }
            }

            if !currentProjectRecentSessions.isEmpty {
                Section("当前项目历史对话") {
                    ForEach(currentProjectRecentSessions) { session in
                        Button {
                            Task { await appState.resume(session) }
                        } label: {
                            Label(session.title, systemImage: session.provider?.symbolName ?? "bubble.left")
                        }
                    }
                }
            }

            if !otherRunningSessions.isEmpty {
                Section("其他运行中") {
                    ForEach(otherRunningSessions) { session in
                        Button {
                            Task { await appState.selectSession(session) }
                        } label: {
                            Label("\(session.projectName) / \(session.displayName)", systemImage: session.provider?.symbolName ?? "terminal")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: appState.activeSession?.provider?.symbolName ?? "rectangle.stack")
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(currentProjectName)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(contextSubtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.down.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .liquidGlass(Capsule(), interactive: true)
    }

    private var currentProjectPath: String? {
        if let path = appState.activeSession?.projectPath, !path.isEmpty { return path }
        if !appState.projectPathDraft.isEmpty { return appState.projectPathDraft }
        return nil
    }

    private var currentProjectName: String {
        currentProjectPath?.projectDisplayName ?? "未选择项目"
    }

    private var contextSubtitle: String {
        if let active = appState.activeSession {
            let provider = active.provider?.title ?? "Agent"
            return "\(provider) · \(active.id)"
        }
        let model = appState.selectedModel(for: contextProvider) ?? "默认模型"
        return "\(appState.connectionState.title) · \(contextProvider.title) · \(model)"
    }

    private var contextProvider: Provider {
        appState.activeSession?.provider ?? appState.selectedProvider
    }

    private var currentProjectRunningSessions: [SessionInfo] {
        guard let currentProjectPath else { return [] }
        return appState.sessions
            .filter { $0.projectPath == currentProjectPath }
            .sorted { $0.lastActivityAt > $1.lastActivityAt }
    }

    private var currentProjectRecentSessions: [RecentSession] {
        guard let currentProjectPath else { return [] }
        return appState.recentSessions
            .filter { ($0.resumeCwd ?? $0.projectPath) == currentProjectPath }
            .sorted { $0.modified > $1.modified }
    }

    private var otherRunningSessions: [SessionInfo] {
        guard let currentProjectPath else { return appState.sessions }
        return appState.sessions
            .filter { $0.projectPath != currentProjectPath }
            .sorted { $0.lastActivityAt > $1.lastActivityAt }
    }
}

struct PermissionModeMenu: View {
    @Binding var selection: PermissionMode

    var body: some View {
        Menu {
            ForEach(PermissionMode.allCases) { mode in
                Button {
                    selection = mode
                } label: {
                    if mode == selection {
                        Label(mode.title, systemImage: "checkmark")
                    } else {
                        Text(mode.title)
                    }
                }
            }
        } label: {
            Label("权限：\(selection.title)", systemImage: "lock.shield")
        }
    }
}

struct SessionStatusGlass: View {
    var session: SessionInfo?
    var state: ConnectionState

    var body: some View {
        let title = session?.status.title ?? state.title
        Label(title, systemImage: session?.status == .waitingApproval ? "exclamationmark.circle.fill" : "waveform")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .liquidGlass(Capsule(), interactive: true)
    }
}

struct ChatBubble: View {
    var item: ChatItem
    @State private var isToolExpanded = false

    var body: some View {
        HStack(alignment: .bottom) {
            if item.role == .user { Spacer(minLength: 48) }

            VStack(alignment: .leading, spacing: 6) {
                if item.role == .tool {
                    Button {
                        isToolExpanded.toggle()
                    } label: {
                        HStack(spacing: 8) {
                            Label(item.title ?? "工具调用", systemImage: icon)
                                .font(.caption.weight(.semibold))
                            Spacer(minLength: 12)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .rotationEffect(.degrees(isToolExpanded ? 90 : 0))
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    if isToolExpanded {
                        Text(item.text)
                            .font(.callout.monospaced())
                            .textSelection(.enabled)
                            .foregroundStyle(foreground)
                    } else {
                        Text(toolSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                } else if let title = item.title {
                    Label(title, systemImage: icon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                if item.role != .tool {
                    Text(item.text)
                        .font(.body)
                        .textSelection(.enabled)
                        .foregroundStyle(foreground)
                }
                if item.isStreaming {
                    ProgressView()
                        .controlSize(.mini)
                }
            }
            .padding(12)
            .background(background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .frame(maxWidth: 620, alignment: item.role == .user ? .trailing : .leading)

            if item.role != .user { Spacer(minLength: 48) }
        }
        .accessibilityElement(children: .combine)
    }

    private var toolSummary: String {
        let normalized = item.text
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? "已折叠工具详情" : normalized
    }

    private var icon: String {
        switch item.role {
        case .user: "person"
        case .assistant: "sparkles"
        case .thinking: "brain.head.profile"
        case .tool: "hammer"
        case .system: "info.circle"
        case .error: "exclamationmark.triangle"
        }
    }

    private var foreground: Color {
        item.role == .error ? .red : .primary
    }

    private var background: some ShapeStyle {
        switch item.role {
        case .user: return Color.accentColor.opacity(0.16)
        case .assistant: return Color(uiColor: .secondarySystemBackground)
        case .thinking: return Color.indigo.opacity(0.10)
        case .tool: return Color.teal.opacity(0.10)
        case .system: return Color(uiColor: .tertiarySystemBackground)
        case .error: return Color.red.opacity(0.10)
        }
    }
}

struct PermissionRequestPanel: View {
    @Environment(AppState.self) private var appState
    var request: PermissionRequestMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(request.toolName, systemImage: "hand.raised.fill")
                    .font(.headline)
                Spacer()
                Text("审批")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }

            Text(request.summary)
                .font(.callout.monospaced())
                .lineLimit(8)
                .textSelection(.enabled)

            HStack {
                Button(role: .destructive) {
                    Task { await appState.reject(request) }
                } label: {
                    Label("拒绝", systemImage: "xmark")
                }

                Spacer()

                Button {
                    Task { await appState.approve(request, always: true) }
                } label: {
                    Label("始终允许", systemImage: "checkmark.seal")
                }

                Button {
                    Task { await appState.approve(request) }
                } label: {
                    Label("批准", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .liquidGlass(RoundedRectangle(cornerRadius: 24, style: .continuous), interactive: true)
    }
}

struct PromptInputBar: View {
    @Environment(AppState.self) private var appState
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("给 agent 发送消息", text: $text, axis: .vertical)
                .lineLimit(1...6)
                .textInputAutocapitalization(.sentences)
                .focused($isFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            Button {
                isFocused = false
                Task { await appState.sendPrompt() }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.headline)
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.borderedProminent)
            .clipShape(Circle())
            .disabled(
                text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || !appState.connectionState.isConnected
                    || appState.activeSessionID == nil
            )
            .accessibilityLabel("发送提示词")
        }
        .padding(10)
        .liquidGlass(RoundedRectangle(cornerRadius: 28, style: .continuous), interactive: true)
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}

@MainActor
private func dismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
