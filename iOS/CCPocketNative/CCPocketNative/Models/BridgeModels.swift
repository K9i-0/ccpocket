import Foundation

enum Provider: String, CaseIterable, Identifiable, Codable {
    case codex
    case claude

    var id: String { rawValue }
    var title: String {
        switch self {
        case .codex: "Codex"
        case .claude: "Claude"
        }
    }
    var symbolName: String { self == .codex ? "sparkles" : "terminal" }
}

enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting(Int)
    case failed(String)

    var title: String {
        switch self {
        case .disconnected: "未连接"
        case .connecting: "连接中"
        case .connected: "已连接"
        case .reconnecting(let attempt): "重连中 \(attempt)"
        case .failed: "连接失败"
        }
    }

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

enum SessionStatus: String, Codable {
    case starting
    case idle
    case running
    case waitingApproval = "waiting_approval"
    case compacting
    case unknown

    init(rawValue: String) {
        switch rawValue {
        case "starting": self = .starting
        case "idle": self = .idle
        case "running": self = .running
        case "waiting_approval": self = .waitingApproval
        case "compacting": self = .compacting
        default: self = .unknown
        }
    }

    var title: String {
        switch self {
        case .starting: "启动中"
        case .idle: "空闲"
        case .running: "运行中"
        case .waitingApproval: "待审批"
        case .compacting: "压缩中"
        case .unknown: "未知"
        }
    }
}

enum PermissionMode: String, CaseIterable, Identifiable, Codable {
    case `default`
    case acceptEdits
    case plan
    case auto
    case bypassPermissions

    var id: String { rawValue }
    var title: String {
        switch self {
        case .default: "默认"
        case .acceptEdits: "自动接受编辑"
        case .plan: "计划模式"
        case .auto: "自动"
        case .bypassPermissions: "跳过审批"
        }
    }
}

struct ConnectionParams: Equatable {
    var serverURL: String
    var token: String?

    var websocketURL: URL? {
        guard var components = URLComponents(string: serverURL) else { return nil }
        if let token, !token.isEmpty {
            var items = components.queryItems ?? []
            items.removeAll { $0.name == "token" }
            items.append(URLQueryItem(name: "token", value: token))
            components.queryItems = items
        }
        return components.url
    }
}

struct BridgeRequest: Encodable {
    var type: String
    var appVersion: String?
    var protocolVersion: Int?
    var supportedServerMessages: [String]?
    var projectPath: String?
    var provider: String?
    var sessionId: String?
    var continueMode: Bool?
    var permissionMode: String?
    var executionMode: String?
    var approvalPolicy: String?
    var approvalsReviewer: String?
    var codexPermissionsMode: String?
    var planMode: Bool?
    var sandboxMode: String?
    var model: String?
    var effort: String?
    var text: String?
    var clientMessageId: String?
    var baseSeq: Int?
    var id: String?
    var clearContext: Bool?
    var message: String?
    var toolUseId: String?
    var result: String?
    var limit: Int?
    var offset: Int?
    var requestScope: String?
    var namedOnly: Bool?
    var searchQuery: String?
    var sinceSeq: Int?

    enum CodingKeys: String, CodingKey {
        case type
        case appVersion
        case protocolVersion
        case supportedServerMessages
        case projectPath
        case provider
        case sessionId
        case continueMode = "continue"
        case permissionMode
        case executionMode
        case approvalPolicy
        case approvalsReviewer
        case codexPermissionsMode
        case planMode
        case sandboxMode
        case model
        case effort
        case text
        case clientMessageId
        case baseSeq
        case id
        case clearContext
        case message
        case toolUseId
        case result
        case limit
        case offset
        case requestScope
        case namedOnly
        case searchQuery
        case sinceSeq
    }

    static func clientCapabilities() -> BridgeRequest {
        BridgeRequest(
            type: "client_capabilities",
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            protocolVersion: 1,
            supportedServerMessages: [
                "conversation_queue",
                "goal_state",
                "history_delta",
                "history_snapshot",
                "git_status_result",
                "prompt_history_status"
            ]
        )
    }

    static func listSessions() -> BridgeRequest {
        BridgeRequest(type: "list_sessions")
    }

    static func listRecentSessions(limit: Int = 40, offset: Int = 0, projectPath: String? = nil) -> BridgeRequest {
        BridgeRequest(
            type: "list_recent_sessions",
            projectPath: projectPath,
            limit: limit,
            offset: offset,
            requestScope: projectPath == nil ? "list" : "project"
        )
    }

    static func listProjectHistory() -> BridgeRequest {
        BridgeRequest(type: "list_project_history")
    }

    static func start(projectPath: String, provider: Provider, permissionMode: PermissionMode, model: String? = nil) -> BridgeRequest {
        BridgeRequest(
            type: "start",
            projectPath: projectPath,
            provider: provider.rawValue,
            permissionMode: permissionMode.rawValue,
            executionMode: permissionMode == .acceptEdits ? "acceptEdits" : "default",
            planMode: permissionMode == .plan,
            model: model
        )
    }

    static func resume(sessionId: String, projectPath: String, provider: Provider?, permissionMode: PermissionMode, model: String? = nil) -> BridgeRequest {
        BridgeRequest(
            type: "resume_session",
            projectPath: projectPath,
            provider: provider?.rawValue,
            sessionId: sessionId,
            permissionMode: permissionMode.rawValue,
            executionMode: permissionMode == .acceptEdits ? "acceptEdits" : "default",
            planMode: permissionMode == .plan,
            model: model
        )
    }

    static func input(_ text: String, sessionId: String?, baseSeq: Int?, clientMessageId: String = UUID().uuidString) -> BridgeRequest {
        BridgeRequest(
            type: "input",
            sessionId: sessionId,
            text: text,
            clientMessageId: clientMessageId,
            baseSeq: baseSeq
        )
    }

    static func getHistory(sessionId: String) -> BridgeRequest {
        BridgeRequest(type: "get_history", sessionId: sessionId)
    }

    static func getHistoryDelta(sessionId: String, sinceSeq: Int) -> BridgeRequest {
        BridgeRequest(type: "get_history_delta", sessionId: sessionId, sinceSeq: sinceSeq)
    }

    static func approve(_ toolUseId: String, sessionId: String?) -> BridgeRequest {
        BridgeRequest(type: "approve", sessionId: sessionId, id: toolUseId)
    }

    static func approveAlways(_ toolUseId: String, sessionId: String?) -> BridgeRequest {
        BridgeRequest(type: "approve_always", sessionId: sessionId, id: toolUseId)
    }

    static func reject(_ toolUseId: String, message: String? = nil, sessionId: String?) -> BridgeRequest {
        BridgeRequest(type: "reject", sessionId: sessionId, id: toolUseId, message: message)
    }

    static func stop(sessionId: String) -> BridgeRequest {
        BridgeRequest(type: "stop_session", sessionId: sessionId)
    }
}

struct InboundBridgeMessage: Decodable, Sendable {
    let sessionId: String?
    let historySeq: Int?
    let message: ServerMessage

    private enum CodingKeys: String, CodingKey {
        case sessionId
        case historySeq
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try container.decodeIfPresent(String.self, forKey: .sessionId)
        historySeq = try container.decodeIfPresent(Int.self, forKey: .historySeq)
        message = try ServerMessage(from: decoder)
    }
}

enum ServerMessage: Decodable, Sendable {
    case system(SystemServerMessage)
    case assistant(AssistantServerMessage)
    case toolResult(ToolResultMessage)
    case result(ResultMessage)
    case error(ErrorMessage)
    case status(StatusMessage)
    case history(HistoryMessage)
    case historyDelta(HistoryDeltaMessage)
    case historySnapshot(HistorySnapshotMessage)
    case conversationQueue(ConversationQueueMessage)
    case goalState(GoalStateMessage)
    case permissionRequest(PermissionRequestMessage)
    case permissionResolved(PermissionResolvedMessage)
    case streamDelta(TextDeltaMessage)
    case thinkingDelta(TextDeltaMessage)
    case sessionList(SessionListMessage)
    case recentSessions(RecentSessionsMessage)
    case projectHistory(ProjectHistoryMessage)
    case toolUseSummary(ToolUseSummaryMessage)
    case userInput(UserInputMessage)
    case inputAck(InputAckMessage)
    case inputRejected(InputRejectedMessage)
    case unknown(type: String, raw: [String: JSONValue])

    private enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "system": self = .system(try SystemServerMessage(from: decoder))
        case "assistant": self = .assistant(try AssistantServerMessage(from: decoder))
        case "tool_result": self = .toolResult(try ToolResultMessage(from: decoder))
        case "result": self = .result(try ResultMessage(from: decoder))
        case "error": self = .error(try ErrorMessage(from: decoder))
        case "status": self = .status(try StatusMessage(from: decoder))
        case "history": self = .history(try HistoryMessage(from: decoder))
        case "history_delta": self = .historyDelta(try HistoryDeltaMessage(from: decoder))
        case "history_snapshot": self = .historySnapshot(try HistorySnapshotMessage(from: decoder))
        case "conversation_queue": self = .conversationQueue(try ConversationQueueMessage(from: decoder))
        case "goal_state": self = .goalState(try GoalStateMessage(from: decoder))
        case "permission_request": self = .permissionRequest(try PermissionRequestMessage(from: decoder))
        case "permission_resolved": self = .permissionResolved(try PermissionResolvedMessage(from: decoder))
        case "stream_delta": self = .streamDelta(try TextDeltaMessage(from: decoder))
        case "thinking_delta": self = .thinkingDelta(try TextDeltaMessage(from: decoder))
        case "session_list": self = .sessionList(try SessionListMessage(from: decoder))
        case "recent_sessions": self = .recentSessions(try RecentSessionsMessage(from: decoder))
        case "project_history": self = .projectHistory(try ProjectHistoryMessage(from: decoder))
        case "tool_use_summary": self = .toolUseSummary(try ToolUseSummaryMessage(from: decoder))
        case "user_input": self = .userInput(try UserInputMessage(from: decoder))
        case "input_ack": self = .inputAck(try InputAckMessage(from: decoder))
        case "input_rejected": self = .inputRejected(try InputRejectedMessage(from: decoder))
        default:
            let raw = try [String: JSONValue](from: decoder)
            self = .unknown(type: type, raw: raw)
        }
    }
}

struct SystemServerMessage: Decodable, Identifiable, Sendable {
    let subtype: String
    let sessionId: String?
    let claudeSessionId: String?
    let provider: Provider?
    let projectPath: String?
    let permissionMode: String?
    let executionMode: String?
    let planMode: Bool?
    let model: String?
    let worktreePath: String?
    let worktreeBranch: String?

    var id: String { "system-\(subtype)-\(sessionId ?? UUID().uuidString)" }
}

struct AssistantServerMessage: Decodable, Sendable {
    let message: AssistantMessage
    let messageUuid: String?
}

struct AssistantMessage: Decodable, Sendable {
    let id: String
    let role: String
    let content: [AssistantContent]
    let model: String?
}

enum AssistantContent: Decodable, Hashable, Sendable {
    case text(String)
    case thinking(String)
    case toolUse(id: String, name: String, input: [String: JSONValue])
    case unknown(String)

    private enum CodingKeys: String, CodingKey {
        case type
        case text
        case thinking
        case id
        case name
        case input
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decodeIfPresent(String.self, forKey: .type) ?? "unknown"
        switch type {
        case "text":
            self = .text(try container.decodeIfPresent(String.self, forKey: .text) ?? "")
        case "thinking":
            self = .thinking(try container.decodeIfPresent(String.self, forKey: .thinking) ?? "")
        case "tool_use":
            self = .toolUse(
                id: try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString,
                name: try container.decodeIfPresent(String.self, forKey: .name) ?? "工具",
                input: try container.decodeIfPresent([String: JSONValue].self, forKey: .input) ?? [:]
            )
        default:
            self = .unknown(type)
        }
    }
}

struct ToolResultMessage: Decodable, Sendable {
    let toolUseId: String
    let content: String
    let toolName: String?

    private enum CodingKeys: String, CodingKey {
        case toolUseId
        case content
        case toolName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        toolUseId = try container.decode(String.self, forKey: .toolUseId)
        toolName = try container.decodeIfPresent(String.self, forKey: .toolName)
        if let text = try? container.decode(String.self, forKey: .content) {
            content = text
        } else if let blocks = try? container.decode([JSONValue].self, forKey: .content) {
            content = blocks.map(\.displayString).joined(separator: "\n")
        } else {
            content = ""
        }
    }
}

struct ResultMessage: Decodable, Sendable {
    let subtype: String
    let result: String?
    let error: String?
    let duration: Double?
    let sessionId: String?
    let stopReason: String?
}

struct ErrorMessage: Decodable, Sendable {
    let message: String
    let errorCode: String?
}

struct StatusMessage: Decodable, Sendable {
    let status: SessionStatus

    private enum CodingKeys: String, CodingKey {
        case status
    }
}

struct HistoryMessage: Decodable, Sendable {
    let messages: [ServerMessage]
}

struct HistoryEntry: Decodable, Sendable {
    let seq: Int
    let message: ServerMessage
}

struct HistoryDeltaMessage: Decodable, Sendable {
    let sessionId: String?
    let fromSeq: Int
    let toSeq: Int
    let messages: [HistoryEntry]
    let status: SessionStatus?
}

struct HistorySnapshotMessage: Decodable, Sendable {
    let sessionId: String?
    let fromSeq: Int
    let toSeq: Int
    let messages: [HistoryEntry]
    let status: SessionStatus?
    let reason: String
}

struct ConversationQueueMessage: Decodable, Sendable {
    let sessionId: String?
    let limit: Int
    let items: [QueuedInputItem]
}

struct QueuedInputItem: Decodable, Identifiable, Hashable, Sendable {
    let itemId: String
    let text: String
    let createdAt: String

    var id: String { itemId }
}

struct GoalStateMessage: Decodable, Sendable {
    let sessionId: String?
    let goal: CodexGoal?
}

struct CodexGoal: Decodable, Hashable, Sendable {
    let threadId: String
    let objective: String
    let status: String
    let tokenBudget: Int?
    let tokensUsed: Int
    let timeUsedSeconds: Int
}

struct PermissionRequestMessage: Decodable, Identifiable, Hashable, Sendable {
    let toolUseId: String
    let toolName: String
    let input: [String: JSONValue]

    var id: String { toolUseId }

    var summary: String {
        if input.isEmpty { return "无参数" }
        return input
            .sorted { $0.key < $1.key }
            .map { "\($0.key): \($0.value.displayString)" }
            .joined(separator: "\n")
    }
}

struct PermissionResolvedMessage: Decodable, Sendable {
    let toolUseId: String
}

struct TextDeltaMessage: Decodable, Sendable {
    let text: String
}

struct SessionListMessage: Decodable, Sendable {
    let sessions: [SessionInfo]
    let allowedDirs: [String]
    let codexModels: [String]
    let claudeModels: [String]
    let bridgeVersion: String?
}

struct RecentSessionsMessage: Decodable, Sendable {
    let sessions: [RecentSession]
    let hasMore: Bool
}

struct ProjectHistoryMessage: Decodable, Sendable {
    let projects: [String]
}

struct ToolUseSummaryMessage: Decodable, Sendable {
    let summary: String
    let precedingToolUseIds: [String]
}

struct UserInputMessage: Decodable, Sendable {
    let text: String
    let clientMessageId: String?
    let timestamp: String?
}

struct InputAckMessage: Decodable, Sendable {
    let sessionId: String?
    let clientMessageId: String?
    let acceptedSeq: Int?
    let queued: Bool
}

struct InputRejectedMessage: Decodable, Sendable {
    let sessionId: String?
    let clientMessageId: String?
    let reason: String?
}

struct SessionInfo: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let provider: Provider?
    let projectPath: String
    let claudeSessionId: String?
    let name: String?
    let status: SessionStatus
    let createdAt: String
    let lastActivityAt: String
    let gitBranch: String?
    let lastMessage: String?
    let worktreePath: String?
    let worktreeBranch: String?
    let permissionMode: String?
    let pendingPermission: PermissionRequestMessage?
    let queuedInput: QueuedInputItem?

    var displayName: String {
        if let name, !name.isEmpty { return name }
        return projectName
    }

    var projectName: String {
        projectPath.projectDisplayName
    }
}

struct RecentSession: Decodable, Identifiable, Hashable, Sendable {
    let sessionId: String
    let provider: Provider?
    let name: String?
    let summary: String?
    let firstPrompt: String
    let lastPrompt: String?
    let modified: String
    let gitBranch: String
    let projectPath: String
    let resumeCwd: String?

    var id: String { sessionId }

    var title: String {
        if let name, !name.isEmpty { return name }
        return projectName
    }

    var projectName: String {
        projectPath.projectDisplayName
    }

    var preview: String {
        if let summary, !summary.isEmpty { return summary }
        if let lastPrompt, !lastPrompt.isEmpty { return lastPrompt }
        return firstPrompt
    }
}

enum ChatRole: String, Codable {
    case user
    case assistant
    case thinking
    case tool
    case system
    case error
}

struct ChatItem: Identifiable, Hashable {
    let id: String
    var role: ChatRole
    var title: String?
    var text: String
    var isStreaming: Bool

    init(id: String = UUID().uuidString, role: ChatRole, title: String? = nil, text: String, isStreaming: Bool = false) {
        self.id = id
        self.role = role
        self.title = title
        self.text = text
        self.isStreaming = isStreaming
    }
}

struct BridgeLogEntry: Identifiable, Hashable {
    let id = UUID()
    let timestamp = Date()
    let message: String
}

extension String {
    var normalizedProjectPathKey: String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        var result = ""
        var previousWasSeparator = false
        for character in trimmed {
            if character == "/" || character == "\\" {
                if !previousWasSeparator {
                    result.append("/")
                    previousWasSeparator = true
                }
            } else {
                result.append(character)
                previousWasSeparator = false
            }
        }

        while result.count > 1 && result.hasSuffix("/") {
            result.removeLast()
        }
        return result.lowercased()
    }

    var projectDisplayName: String {
        let normalized = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return "未命名项目" }
        return normalized
            .split(whereSeparator: { $0 == "/" || $0 == "\\" })
            .last
            .map(String.init) ?? normalized
    }
}
