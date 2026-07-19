import Foundation
import Observation

@MainActor
@Observable
final class AppState {
    var connectionState: ConnectionState = .disconnected
    var connectionURLText: String = UserDefaults.standard.string(forKey: "bridge.url") ?? ""
    var apiToken: String = UserDefaults.standard.string(forKey: "bridge.token") ?? ""
    var sessions: [SessionInfo] = []
    var recentSessions: [RecentSession] = []
    var projects: [String] = []
    var allowedDirectories: [String] = []
    var codexModels: [String] = []
    var claudeModels: [String] = []
    var selectedCodexModel: String = UserDefaults.standard.string(forKey: "model.codex") ?? "" {
        didSet { UserDefaults.standard.set(selectedCodexModel, forKey: "model.codex") }
    }
    var selectedClaudeModel: String = UserDefaults.standard.string(forKey: "model.claude") ?? "" {
        didSet { UserDefaults.standard.set(selectedClaudeModel, forKey: "model.claude") }
    }
    var bridgeVersion: String?
    var activeSessionID: String?
    var chatItems: [ChatItem] = []
    var pendingPermissions: [String: PermissionRequestMessage] = [:]
    var goals: [String: CodexGoal] = [:]
    var queuedInputs: [String: [QueuedInputItem]] = [:]
    var selectedProvider: Provider = .codex
    var selectedPermissionMode: PermissionMode = .default
    var projectPathDraft: String = ""
    var promptDraft: String = ""
    var logs: [BridgeLogEntry] = []
    var lastHistorySeqBySession: [String: Int] = [:]

    @ObservationIgnored private let bridgeClient = BridgeWebSocketClient()
    @ObservationIgnored private let localNetworkPermissionProber = LocalNetworkPermissionProber()
    @ObservationIgnored private var reconnectTask: Task<Void, Never>?
    @ObservationIgnored private var shouldReconnect = false
    @ObservationIgnored private var connectionGeneration = 0
    @ObservationIgnored private var shouldLoadHistoryAfterSessionCreated = false
    @ObservationIgnored private var pendingUserClientMessageIDs: Set<String> = []
    @ObservationIgnored private var pendingProjectStartKeys: Set<String> = []
    @ObservationIgnored private var didAttemptAutoConnect = false

    var activeSession: SessionInfo? {
        guard let activeSessionID else { return nil }
        return sessions.first { $0.id == activeSessionID }
    }

    var connectionParams: ConnectionParams? {
        guard case .connection(let params) = ConnectionURLParser.parse(connectionURLText) else {
            if connectionURLText.isEmpty { return nil }
            return ConnectionParams(serverURL: connectionURLText, token: apiToken.isEmpty ? nil : apiToken)
        }
        return ConnectionParams(serverURL: params.serverURL, token: params.token ?? (apiToken.isEmpty ? nil : apiToken))
    }

    func autoConnectIfPossible() async {
        guard !didAttemptAutoConnect else { return }
        didAttemptAutoConnect = true
        guard !connectionURLText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !connectionState.isConnected else { return }
        await connect()
    }

    func runningSession(projectPath: String, provider: Provider) -> SessionInfo? {
        let key = normalizedProjectPath(projectPath)
        return sessions.first {
            normalizedProjectPath($0.projectPath) == key && providerMatches($0.provider, provider)
        }
    }

    func runningSession(for recent: RecentSession) -> SessionInfo? {
        sessions.first {
            $0.id == recent.sessionId || $0.claudeSessionId == recent.sessionId
        }
    }

    func isProjectStarting(projectPath: String, provider: Provider) -> Bool {
        pendingProjectStartKeys.contains(projectKey(projectPath: projectPath, provider: provider))
    }

    func selectedModel(for provider: Provider) -> String? {
        let value = provider == .codex ? selectedCodexModel : selectedClaudeModel
        let model = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return model.isEmpty ? nil : model
    }

    func modelOptions(for provider: Provider) -> [String] {
        provider == .codex ? codexModels : claudeModels
    }

    func applyDeepLink(_ params: DeepLinkParams) {
        switch params {
        case .connection(let connection):
            connectionURLText = connection.serverURL
            apiToken = connection.token ?? apiToken
            Task { await connect() }
        case .session(let sessionId):
            activeSessionID = sessionId
            Task { try? await send(.getHistory(sessionId: sessionId)) }
        }
    }

    func connect() async {
        await connect(isReconnectAttempt: false)
    }

    private func connect(isReconnectAttempt: Bool) async {
        guard let params = connectionParams, let url = params.websocketURL else {
            connectionState = .failed("请输入 ws:// 或 wss:// Bridge 地址。")
            return
        }

        shouldReconnect = true
        if !isReconnectAttempt {
            reconnectTask?.cancel()
            reconnectTask = nil
        }
        connectionGeneration += 1
        let generation = connectionGeneration
        connectionState = .connecting
        persistConnection(params)

        if !isReconnectAttempt && url.scheme == "ws" {
            appendLog("正在请求本地网络访问权限")
            localNetworkPermissionProber.triggerPromptIfNeeded { [weak self] message in
                Task { @MainActor in
                    guard generation == self?.connectionGeneration else { return }
                    self?.appendLog(message)
                }
            }
        }

        bridgeClient.connect(
            to: url,
            onEvent: { [weak self] result in
                Task { @MainActor in
                    self?.handleClientEvent(result, generation: generation)
                }
            },
            onDebug: { [weak self] message in
                Task { @MainActor in
                    guard generation == self?.connectionGeneration else { return }
                    self?.appendLog(message)
                }
            }
        )

        do {
            try await send(.clientCapabilities())
            guard generation == connectionGeneration else { return }
            appendLog("已向 Bridge 发送客户端能力：\(url.absoluteString)")
            try await Task.sleep(for: .seconds(5))
            guard generation == connectionGeneration else { return }
            if !connectionState.isConnected {
                let message = "已发送连接请求，但没有收到 Bridge 响应。当前目标：\(url.absoluteString)。请在 iPhone Safari 打开 \(httpProbeURL(from: url)) 验证是否能看到 Not Found。"
                connectionState = .failed(message)
                appendError(message)
                scheduleReconnect()
            }
        } catch {
            guard generation == connectionGeneration else { return }
            connectionState = .failed(friendlyErrorDescription(error))
            appendError(friendlyErrorDescription(error))
            scheduleReconnect()
        }
    }

    func disconnect() {
        shouldReconnect = false
        reconnectTask?.cancel()
        reconnectTask = nil
        connectionGeneration += 1
        bridgeClient.disconnect()
        connectionState = .disconnected
        appendLog("已断开连接")
    }

    func refreshBridgeState() async throws {
        try await send(.listSessions())
        try await send(.listRecentSessions())
        try await send(.listProjectHistory())
    }

    func send(_ request: BridgeRequest) async throws {
        try await bridgeClient.send(request)
    }

    func startSession(projectPath: String? = nil) async {
        let path = (projectPath ?? projectPathDraft).trimmingCharacters(in: .whitespacesAndNewlines)
        await startSession(projectPath: path, provider: selectedProvider)
    }

    func startSession(projectPath: String, provider: Provider) async {
        let path = projectPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return }
        let key = projectKey(projectPath: path, provider: provider)
        guard !pendingProjectStartKeys.contains(key) else {
            appendLog("该项目正在启动，已忽略重复启动请求：\(path)")
            return
        }
        do {
            pendingProjectStartKeys.insert(key)
            selectedProvider = provider
            activeSessionID = nil
            shouldLoadHistoryAfterSessionCreated = false
            try await send(.start(
                projectPath: path,
                provider: provider,
                permissionMode: selectedPermissionMode,
                model: selectedModel(for: provider)
            ))
            projectPathDraft = path
            appendLog("已请求启动 \(path)")
        } catch {
            pendingProjectStartKeys.remove(key)
            appendError(error.localizedDescription)
        }
    }

    func resume(_ recent: RecentSession) async {
        let provider = recent.provider ?? selectedProvider
        let projectPath = recent.resumeCwd ?? recent.projectPath
        if let existing = runningSession(for: recent) {
            await selectSession(existing)
            appendLog("该历史对话已在运行，已直接切换：\(existing.id)")
            return
        }
        let key = "resume:\(provider.rawValue):\(recent.sessionId)"
        guard !pendingProjectStartKeys.contains(key) else {
            appendLog("该项目正在恢复，已忽略重复恢复请求：\(projectPath)")
            return
        }
        do {
            pendingProjectStartKeys.insert(key)
            selectedProvider = provider
            projectPathDraft = projectPath
            activeSessionID = nil
            shouldLoadHistoryAfterSessionCreated = true
            try await send(.resume(
                sessionId: recent.sessionId,
                projectPath: projectPathDraft,
                provider: provider,
                permissionMode: selectedPermissionMode,
                model: selectedModel(for: provider)
            ))
            appendLog("已请求恢复 \(recent.sessionId)，等待 Bridge 返回运行会话 id")
        } catch {
            pendingProjectStartKeys.remove(key)
            shouldLoadHistoryAfterSessionCreated = false
            appendError(error.localizedDescription)
        }
    }

    func selectSession(_ session: SessionInfo) async {
        activeSessionID = session.id
        projectPathDraft = session.projectPath
        if let provider = session.provider {
            selectedProvider = provider
        }
        chatItems.removeAll()
        do {
            if let seq = lastHistorySeqBySession[session.id], seq > 0 {
                try await send(.getHistoryDelta(sessionId: session.id, sinceSeq: seq))
            } else {
                try await send(.getHistory(sessionId: session.id))
            }
        } catch {
            appendError(error.localizedDescription)
        }
    }

    func sendPrompt() async {
        let text = promptDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard let activeSessionID else {
            promptDraft = text
            appendError("当前没有可用的运行会话。请先启动项目，或等待恢复完成后再发送。")
            return
        }
        promptDraft = ""
        let baseSeq = lastHistorySeqBySession[activeSessionID]
        let clientMessageId = UUID().uuidString
        pendingUserClientMessageIDs.insert(clientMessageId)
        do {
            try await send(.input(text, sessionId: activeSessionID, baseSeq: baseSeq, clientMessageId: clientMessageId))
            appendUserInput(text: text, clientMessageId: clientMessageId)
        } catch {
            pendingUserClientMessageIDs.remove(clientMessageId)
            promptDraft = text
            appendError(error.localizedDescription)
        }
    }

    func approve(_ request: PermissionRequestMessage, always: Bool = false) async {
        do {
            try await send(always ? .approveAlways(request.toolUseId, sessionId: activeSessionID) : .approve(request.toolUseId, sessionId: activeSessionID))
            pendingPermissions.removeValue(forKey: request.toolUseId)
        } catch {
            appendError(error.localizedDescription)
        }
    }

    func reject(_ request: PermissionRequestMessage) async {
        do {
            try await send(.reject(request.toolUseId, message: "已从 CC Pocket Native 拒绝", sessionId: activeSessionID))
            pendingPermissions.removeValue(forKey: request.toolUseId)
        } catch {
            appendError(error.localizedDescription)
        }
    }

    func stopActiveSession() async {
        guard let activeSessionID else { return }
        await stopSession(activeSessionID)
    }

    func stopSession(_ sessionId: String) async {
        do {
            try await send(.stop(sessionId: sessionId))
            if activeSessionID == sessionId {
                activeSessionID = nil
            }
        } catch {
            appendError(error.localizedDescription)
        }
    }

    private func handleClientEvent(_ result: Result<InboundBridgeMessage, Error>, generation: Int) {
        guard generation == connectionGeneration else { return }
        switch result {
        case .success(let inbound):
            if !connectionState.isConnected {
                connectionState = .connected
                appendLog("已连接到 Bridge")
                Task {
                    try? await refreshBridgeState()
                }
            }
            apply(inbound.message, sessionId: inbound.sessionId, historySeq: inbound.historySeq)
        case .failure(let error):
            guard shouldReconnect else { return }
            let message = friendlyErrorDescription(error)
            connectionState = .failed(message)
            appendError(message)
            scheduleReconnect()
        }
    }

    private func apply(_ message: ServerMessage, sessionId: String?, historySeq: Int?) {
        if let sessionId, let historySeq {
            lastHistorySeqBySession[sessionId] = max(lastHistorySeqBySession[sessionId] ?? 0, historySeq)
        }

        switch message {
        case .system(let system):
            if let id = system.sessionId ?? sessionId {
                activeSessionID = id
            }
            if let projectPath = system.projectPath {
                projectPathDraft = projectPath
            }
            if let provider = system.provider {
                selectedProvider = provider
            }
            if system.subtype == "session_created" {
                appendLog("Bridge 已创建运行会话：\(system.sessionId ?? sessionId ?? "unknown")")
                if let projectPath = system.projectPath {
                    pendingProjectStartKeys.remove(projectKey(projectPath: projectPath, provider: system.provider ?? selectedProvider))
                }
                pendingProjectStartKeys = pendingProjectStartKeys.filter { !$0.hasPrefix("resume:") }
                if let id = system.sessionId ?? sessionId, shouldLoadHistoryAfterSessionCreated {
                    shouldLoadHistoryAfterSessionCreated = false
                    Task { try? await send(.getHistory(sessionId: id)) }
                }
                if chatItems.last?.title?.hasPrefix("正在") == true {
                    chatItems.removeLast()
                }
            } else if system.subtype == "init" {
                appendLog("会话初始化完成")
            } else {
                appendLog("系统：\(system.subtype)")
            }
        case .assistant(let assistant):
            appendAssistant(assistant.message)
        case .toolResult(let tool):
            chatItems.append(ChatItem(role: .tool, title: tool.toolName ?? "工具结果", text: tool.content))
        case .result(let result):
            appendResult(result)
        case .error(let error):
            pendingProjectStartKeys.removeAll()
            appendError(error.message)
        case .status(let status):
            patchStatus(status.status, sessionId: sessionId ?? activeSessionID)
        case .history(let history):
            chatItems.removeAll()
            history.messages.forEach { apply($0, sessionId: sessionId, historySeq: nil) }
        case .historyDelta(let delta):
            lastHistorySeqBySession[delta.sessionId ?? sessionId ?? ""] = delta.toSeq
            delta.messages.sorted { $0.seq < $1.seq }.forEach { apply($0.message, sessionId: delta.sessionId ?? sessionId, historySeq: $0.seq) }
            if let status = delta.status { patchStatus(status, sessionId: delta.sessionId ?? sessionId) }
        case .historySnapshot(let snapshot):
            if snapshot.reason == "reset" || snapshot.reason == "compacted" {
                chatItems.removeAll()
            }
            lastHistorySeqBySession[snapshot.sessionId ?? sessionId ?? ""] = snapshot.toSeq
            snapshot.messages.sorted { $0.seq < $1.seq }.forEach { apply($0.message, sessionId: snapshot.sessionId ?? sessionId, historySeq: $0.seq) }
            if let status = snapshot.status { patchStatus(status, sessionId: snapshot.sessionId ?? sessionId) }
        case .conversationQueue(let queue):
            queuedInputs[queue.sessionId ?? sessionId ?? ""] = queue.items
        case .goalState(let state):
            if let id = state.sessionId ?? sessionId, let goal = state.goal {
                goals[id] = goal
            }
        case .permissionRequest(let request):
            pendingPermissions[request.toolUseId] = request
            patchStatus(.waitingApproval, sessionId: sessionId ?? activeSessionID)
        case .permissionResolved(let resolved):
            pendingPermissions.removeValue(forKey: resolved.toolUseId)
        case .streamDelta(let delta):
            appendDelta(delta.text, role: .assistant)
        case .thinkingDelta(let delta):
            appendDelta(delta.text, role: .thinking)
        case .sessionList(let list):
            sessions = list.sessions
            allowedDirectories = list.allowedDirs
            codexModels = list.codexModels
            claudeModels = list.claudeModels
            bridgeVersion = list.bridgeVersion
            for session in list.sessions {
                if let permission = session.pendingPermission {
                    pendingPermissions[permission.toolUseId] = permission
                }
            }
        case .recentSessions(let recent):
            recentSessions = recent.sessions
        case .projectHistory(let history):
            projects = history.projects
        case .toolUseSummary(let summary):
            chatItems.append(ChatItem(role: .tool, title: "工具摘要", text: summary.summary))
        case .userInput(let input):
            appendUserInput(text: input.text, clientMessageId: input.clientMessageId)
        case .inputAck:
            break
        case .inputRejected(let rejected):
            appendError(rejected.reason ?? "输入被拒绝")
        case .unknown(let type, _):
            appendLog("未处理的服务端消息：\(type)")
        }
    }

    private func appendAssistant(_ message: AssistantMessage) {
        for content in message.content {
            switch content {
            case .text(let text):
                guard !text.isEmpty else { continue }
                appendAssistantText(text, messageId: message.id)
            case .thinking(let text):
                appendThinkingText(text)
            case .toolUse(_, let name, let input):
                let body = input
                    .sorted { $0.key < $1.key }
                    .map { "\($0.key): \($0.value.displayString)" }
                    .joined(separator: "\n")
                chatItems.append(ChatItem(role: .tool, title: name, text: body.isEmpty ? "工具调用" : body))
            case .unknown(let type):
                chatItems.append(ChatItem(role: .tool, title: "未知内容", text: type))
            }
        }
        markLastStreamingComplete()
    }

    private func appendUserInput(text: String, clientMessageId: String?) {
        if let clientMessageId, let index = chatItems.firstIndex(where: { $0.id == clientMessageId }) {
            chatItems[index].text = text
            pendingUserClientMessageIDs.remove(clientMessageId)
            return
        }
        if isRecentDuplicate(role: .user, text: text) {
            if let clientMessageId {
                pendingUserClientMessageIDs.remove(clientMessageId)
            }
            return
        }
        chatItems.append(ChatItem(id: clientMessageId ?? UUID().uuidString, role: .user, text: text))
    }

    private func appendAssistantText(_ text: String, messageId: String?) {
        if let messageId, let index = chatItems.firstIndex(where: { $0.id == messageId }) {
            chatItems[index].text = text
            chatItems[index].isStreaming = false
            return
        }
        if let index = chatItems.indices.last,
           chatItems[index].role == .assistant,
           chatItems[index].isStreaming {
            if text == chatItems[index].text || text.hasPrefix(chatItems[index].text) {
                chatItems[index].text = text
                chatItems[index].isStreaming = false
                return
            }
        }
        markLastStreamingComplete()
        if isRecentDuplicate(role: .assistant, text: text) {
            return
        }
        chatItems.append(ChatItem(id: messageId ?? UUID().uuidString, role: .assistant, text: text))
    }

    private func appendThinkingText(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if let index = chatItems.indices.last,
           chatItems[index].role == .thinking,
           chatItems[index].isStreaming {
            if text == chatItems[index].text || text.hasPrefix(chatItems[index].text) {
                chatItems[index].text = text
                chatItems[index].isStreaming = false
                return
            }
        }
        markLastStreamingComplete()
        if isRecentDuplicate(role: .thinking, text: text) {
            return
        }
        chatItems.append(ChatItem(role: .thinking, title: "思考中", text: text))
    }

    private func appendResult(_ result: ResultMessage) {
        if let error = result.error, !error.isEmpty {
            appendError(error)
            return
        }
        markLastStreamingComplete()
        guard let text = result.result ?? result.stopReason, !text.isEmpty else {
            return
        }
        if isRecentDuplicate(role: .assistant, text: text) || isRecentDuplicate(role: .system, text: text) {
            return
        }
        chatItems.append(ChatItem(role: .system, title: "结果", text: text))
    }

    private func appendDelta(_ text: String, role: ChatRole) {
        guard !text.isEmpty else { return }
        if let index = chatItems.indices.last, chatItems[index].isStreaming, chatItems[index].role == role {
            chatItems[index].text += text
        } else {
            markLastStreamingComplete()
            chatItems.append(ChatItem(role: role, title: role == .thinking ? "思考中" : nil, text: text, isStreaming: true))
        }
    }

    private func markLastStreamingComplete() {
        if let index = chatItems.indices.last, chatItems[index].isStreaming {
            chatItems[index].isStreaming = false
        }
    }

    private func isRecentDuplicate(role: ChatRole, text: String) -> Bool {
        let normalized = normalizedForDedup(text)
        guard !normalized.isEmpty else { return false }
        return chatItems.suffix(12).contains { item in
            item.role == role && normalizedForDedup(item.text) == normalized
        }
    }

    private func normalizedForDedup(_ text: String) -> String {
        text
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func projectKey(projectPath: String, provider: Provider) -> String {
        "\(provider.rawValue):\(normalizedProjectPath(projectPath))"
    }

    private func normalizedProjectPath(_ path: String) -> String {
        path.normalizedProjectPathKey
    }

    private func providerMatches(_ sessionProvider: Provider?, _ provider: Provider) -> Bool {
        sessionProvider == provider || sessionProvider == nil
    }

    private func patchStatus(_ status: SessionStatus, sessionId: String?) {
        guard let sessionId, let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        let old = sessions[index]
        sessions[index] = SessionInfo(
            id: old.id,
            provider: old.provider,
            projectPath: old.projectPath,
            claudeSessionId: old.claudeSessionId,
            name: old.name,
            status: status,
            createdAt: old.createdAt,
            lastActivityAt: old.lastActivityAt,
            gitBranch: old.gitBranch,
            lastMessage: old.lastMessage,
            worktreePath: old.worktreePath,
            worktreeBranch: old.worktreeBranch,
            permissionMode: old.permissionMode,
            pendingPermission: old.pendingPermission,
            queuedInput: old.queuedInput
        )
    }

    private func persistConnection(_ params: ConnectionParams) {
        UserDefaults.standard.set(params.serverURL, forKey: "bridge.url")
        UserDefaults.standard.set(params.token ?? "", forKey: "bridge.token")
        connectionURLText = params.serverURL
        apiToken = params.token ?? ""
    }

    private func scheduleReconnect() {
        guard shouldReconnect, reconnectTask == nil else { return }
        reconnectTask = Task { [weak self] in
            defer {
                Task { @MainActor in
                    self?.reconnectTask = nil
                }
            }
            for attempt in 1...5 {
                guard !Task.isCancelled else { return }
                await MainActor.run { self?.connectionState = .reconnecting(attempt) }
                try? await Task.sleep(for: .seconds(min(30, attempt * 2)))
                guard !Task.isCancelled else { return }
                await self?.connect(isReconnectAttempt: true)
                if self?.connectionState.isConnected == true { return }
            }
            await MainActor.run {
                if self?.connectionState.isConnected != true {
                    let target = self?.connectionParams?.serverURL ?? "当前 Bridge 地址"
                    self?.connectionState = .failed("多次重连失败。当前目标：\(target)。请确认 iPhone 已允许本 App 访问本地网络，并且 Safari 能打开对应的 http:// 地址。")
                }
            }
        }
    }

    private func appendError(_ message: String) {
        if chatItems.last?.role == .error && chatItems.last?.text == message {
            return
        }
        chatItems.append(ChatItem(role: .error, title: "错误", text: message))
        appendLog("错误：\(message)")
    }

    private func friendlyErrorDescription(_ error: Error) -> String {
        let message = error.localizedDescription
        if message.contains("App Transport Security") || message.contains("secure connection") {
            return "iOS 安全策略拦截了非 HTTPS/WSS 连接。当前版本已允许局域网 ws:// Bridge，请重新安装后再试。"
        }
        if message.contains("Could not connect") || message.contains("cannot connect") {
            let target = connectionParams?.serverURL ?? "当前 Bridge 地址"
            return "无法连接到 Bridge：\(target)。请确认电脑端 Bridge 正在运行、iPhone 和电脑在同一网络，且 iPhone 已允许本 App 访问本地网络。"
        }
        if message.contains("network connection was lost") {
            return "网络连接已断开，正在尝试重连。"
        }
        return message
    }

    private func httpProbeURL(from websocketURL: URL) -> String {
        var components = URLComponents(url: websocketURL, resolvingAgainstBaseURL: false)
        components?.scheme = websocketURL.scheme == "wss" ? "https" : "http"
        components?.query = nil
        return components?.url?.absoluteString ?? websocketURL.absoluteString
    }

    private func appendLog(_ message: String) {
        logs.insert(BridgeLogEntry(message: message), at: 0)
        if logs.count > 100 {
            logs.removeLast(logs.count - 100)
        }
    }
}
