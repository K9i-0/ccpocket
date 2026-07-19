import Foundation
import Network
import Security

enum BridgeClientError: LocalizedError {
    case invalidMessage
    case invalidHandshake
    case unsupportedFrame
    case sendTimeout
    case notConnected
    case networkConnectionClosed

    var errorDescription: String? {
        switch self {
        case .invalidMessage: "Bridge 发送了非文本 WebSocket 消息。"
        case .invalidHandshake: "Bridge WebSocket 握手失败。"
        case .unsupportedFrame: "Bridge 发送了暂不支持的 WebSocket 帧。"
        case .sendTimeout: "发送初始化消息超时。请确认 Bridge 地址、端口、token 和网络连通性。"
        case .notConnected: "WebSocket 尚未连接。"
        case .networkConnectionClosed: "WebSocket 连接已关闭。"
        }
    }
}

final class BridgeWebSocketClient: @unchecked Sendable {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var socketTask: URLSessionWebSocketTask?
    private var rawConnection: NWConnection?
    private var rawHandshakeComplete = false
    private var rawConnectionError: Error?
    private var rawReceiveBuffer = Data()
    private var receiveTask: Task<Void, Never>?
    private let networkQueue = DispatchQueue(label: "ccpocket.native.websocket")

    func connect(
        to url: URL,
        onEvent: @escaping @Sendable (Result<InboundBridgeMessage, Error>) -> Void,
        onDebug: @escaping @Sendable (String) -> Void = { _ in }
    ) {
        disconnect()
        if url.scheme == "ws" {
            onDebug("WebSocket 路径：raw TCP ws://")
            connectUsingRawTCPWebSocket(to: url, onEvent: onEvent, onDebug: onDebug)
            return
        }

        onDebug("WebSocket 路径：URLSession \(url.scheme ?? "unknown")://")
        let task = URLSession.shared.webSocketTask(with: url)
        socketTask = task
        task.resume()
        receiveTask = Task { [weak self] in
            await self?.receiveLoop(onEvent: onEvent, onDebug: onDebug)
        }
    }

    func disconnect() {
        receiveTask?.cancel()
        receiveTask = nil
        socketTask?.cancel(with: .goingAway, reason: nil)
        socketTask = nil
        rawConnection?.cancel()
        rawConnection = nil
        rawHandshakeComplete = false
        rawConnectionError = nil
        rawReceiveBuffer.removeAll()
    }

    func send(_ request: BridgeRequest, timeout: Duration = .seconds(5)) async throws {
        let data = try encoder.encode(request)
        let text = String(decoding: data, as: UTF8.self)
        if let rawConnection {
            try await waitForRawHandshake(timeout: timeout)
            try await sendRawTextMessage(text, connection: rawConnection, timeout: timeout)
            return
        }

        guard let socketTask else { throw BridgeClientError.notConnected }
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await socketTask.send(.string(text))
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw BridgeClientError.sendTimeout
            }
            try await group.next()
            group.cancelAll()
        }
    }

    private func connectUsingRawTCPWebSocket(
        to url: URL,
        onEvent: @escaping @Sendable (Result<InboundBridgeMessage, Error>) -> Void,
        onDebug: @escaping @Sendable (String) -> Void
    ) {
        guard let host = url.host(), let port = NWEndpoint.Port(rawValue: UInt16(url.port ?? 80)) else {
            onDebug("raw TCP：URL 无效，无法解析 host/port")
            onEvent(.failure(BridgeClientError.invalidHandshake))
            return
        }

        onDebug("raw TCP：准备连接 \(host):\(port.rawValue)")
        let connection = NWConnection(host: NWEndpoint.Host(host), port: port, using: .tcp)
        rawConnection = connection
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            onDebug("raw TCP state：\(Self.describe(state))")
            switch state {
            case .ready:
                guard let connection else { return }
                self?.sendRawHandshake(to: url, connection: connection, onEvent: onEvent, onDebug: onDebug)
            case .failed(let error):
                self?.rawConnectionError = error
                onEvent(.failure(error))
            case .cancelled:
                break
            default:
                break
            }
        }
        connection.start(queue: networkQueue)
    }

    private func waitForRawHandshake(timeout: Duration) async throws {
        let start = ContinuousClock.now
        while !rawHandshakeComplete {
            if let rawConnectionError {
                throw rawConnectionError
            }
            if start.duration(to: ContinuousClock.now) >= timeout {
                throw BridgeClientError.sendTimeout
            }
            try await Task.sleep(for: .milliseconds(100))
        }
    }

    private func sendRawHandshake(
        to url: URL,
        connection: NWConnection,
        onEvent: @escaping @Sendable (Result<InboundBridgeMessage, Error>) -> Void,
        onDebug: @escaping @Sendable (String) -> Void
    ) {
        let key = Self.makeWebSocketKey()
        let path = Self.pathAndQuery(for: url)
        let host = Self.hostHeader(for: url)
        onDebug("raw TCP：发送 WebSocket 握手 \(path)")
        let request = [
            "GET \(path) HTTP/1.1",
            "Host: \(host)",
            "Upgrade: websocket",
            "Connection: Upgrade",
            "Sec-WebSocket-Key: \(key)",
            "Sec-WebSocket-Version: 13",
            "User-Agent: CCPocketNative",
            "",
            "",
        ].joined(separator: "\r\n")
        connection.send(
            content: Data(request.utf8),
            completion: .contentProcessed { [weak self, weak connection] error in
                guard let self, let connection else { return }
                if let error {
                    self.rawConnectionError = error
                    onDebug("raw TCP：握手发送失败 \(error.localizedDescription)")
                    onEvent(.failure(error))
                    return
                }
                onDebug("raw TCP：握手已发送")
                self.receiveRawHandshake(from: connection, buffer: Data(), onEvent: onEvent, onDebug: onDebug)
            }
        )
    }

    private func receiveRawHandshake(
        from connection: NWConnection,
        buffer: Data,
        onEvent: @escaping @Sendable (Result<InboundBridgeMessage, Error>) -> Void,
        onDebug: @escaping @Sendable (String) -> Void
    ) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self, weak connection] content, _, _, error in
            guard let self, let connection else { return }
            if let error {
                self.rawConnectionError = error
                onDebug("raw TCP：握手接收失败 \(error.localizedDescription)")
                onEvent(.failure(error))
                return
            }
            guard let content else {
                self.rawConnectionError = BridgeClientError.invalidHandshake
                onDebug("raw TCP：握手接收为空")
                onEvent(.failure(BridgeClientError.invalidHandshake))
                return
            }

            onDebug("raw TCP：收到握手字节 \(content.count)")
            var nextBuffer = buffer
            nextBuffer.append(content)
            guard let headerEnd = nextBuffer.range(of: Data("\r\n\r\n".utf8)) else {
                self.receiveRawHandshake(from: connection, buffer: nextBuffer, onEvent: onEvent, onDebug: onDebug)
                return
            }

            let headerData = nextBuffer.subdata(in: 0..<headerEnd.upperBound)
            guard let header = String(data: headerData, encoding: .utf8),
                  header.hasPrefix("HTTP/1.1 101") || header.hasPrefix("HTTP/1.0 101") else {
                self.rawConnectionError = BridgeClientError.invalidHandshake
                onDebug("raw TCP：握手响应不是 101")
                onEvent(.failure(BridgeClientError.invalidHandshake))
                return
            }

            onDebug("raw TCP：握手成功 101")
            self.rawHandshakeComplete = true
            let remaining = nextBuffer.subdata(in: headerEnd.upperBound..<nextBuffer.count)
            if !remaining.isEmpty {
                onDebug("raw TCP：握手后剩余 frame 字节 \(remaining.count)")
            }
            self.rawReceiveBuffer.append(remaining)
            self.processRawReceiveBuffer(onEvent: onEvent, onDebug: onDebug)
            self.receiveRawFrames(from: connection, onEvent: onEvent, onDebug: onDebug)
        }
    }

    private func sendRawTextMessage(
        _ text: String,
        connection: NWConnection,
        timeout: Duration
    ) async throws {
        let data = Self.makeClientFrame(opcode: 0x1, payload: Data(text.utf8))
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { continuation in
                    connection.send(
                        content: data,
                        completion: .contentProcessed { error in
                            if let error {
                                continuation.resume(throwing: error)
                            } else {
                                continuation.resume()
                            }
                        }
                    )
                }
            }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw BridgeClientError.sendTimeout
            }
            try await group.next()
            group.cancelAll()
        }
    }

    private func receiveRawFrames(
        from connection: NWConnection,
        onEvent: @escaping @Sendable (Result<InboundBridgeMessage, Error>) -> Void,
        onDebug: @escaping @Sendable (String) -> Void
    ) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self, weak connection] content, _, isComplete, error in
            guard let self, let connection else { return }
            if let error {
                self.rawConnectionError = error
                onDebug("raw TCP：frame 接收失败 \(error.localizedDescription)")
                onEvent(.failure(error))
                return
            }
            if isComplete {
                self.rawConnectionError = BridgeClientError.networkConnectionClosed
                onDebug("raw TCP：连接完成/关闭")
                onEvent(.failure(BridgeClientError.networkConnectionClosed))
                return
            }
            if let content {
                onDebug("raw TCP：收到 frame 字节 \(content.count)")
                self.rawReceiveBuffer.append(content)
                self.processRawReceiveBuffer(onEvent: onEvent, onDebug: onDebug)
            }
            self.receiveRawFrames(from: connection, onEvent: onEvent, onDebug: onDebug)
        }
    }

    private func processRawReceiveBuffer(
        onEvent: @escaping @Sendable (Result<InboundBridgeMessage, Error>) -> Void,
        onDebug: @escaping @Sendable (String) -> Void
    ) {
        do {
            while let frame = try Self.nextServerFrame(from: &rawReceiveBuffer) {
                onDebug("raw TCP：解析 frame opcode=\(frame.opcode) payload=\(frame.payload.count)")
                switch frame.opcode {
                case 0x1, 0x2:
                    let decoded = try decoder.decode(InboundBridgeMessage.self, from: frame.payload)
                    onDebug("raw TCP：JSON 解码成功")
                    onEvent(.success(decoded))
                case 0x8:
                    rawConnectionError = BridgeClientError.networkConnectionClosed
                    onDebug("raw TCP：收到 close frame")
                    onEvent(.failure(BridgeClientError.networkConnectionClosed))
                    rawConnection?.cancel()
                    return
                case 0x9:
                    sendRawPong(frame.payload)
                case 0xA:
                    break
                default:
                    throw BridgeClientError.unsupportedFrame
                }
            }
        } catch {
            rawConnectionError = error
            rawConnection?.cancel()
            onDebug("raw TCP：解析失败 \(error.localizedDescription)")
            onEvent(.failure(error))
        }
    }

    private func sendRawPong(_ payload: Data) {
        guard let rawConnection else { return }
        rawConnection.send(content: Self.makeClientFrame(opcode: 0xA, payload: payload), completion: .contentProcessed { _ in })
    }

    private static func makeWebSocketKey() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
    }

    private static func pathAndQuery(for url: URL) -> String {
        var path = url.path.isEmpty ? "/" : url.path
        if let query = url.query, !query.isEmpty {
            path += "?\(query)"
        }
        return path
    }

    private static func hostHeader(for url: URL) -> String {
        guard let host = url.host() else { return "" }
        if let port = url.port {
            return "\(host):\(port)"
        }
        return host
    }

    private static func makeClientFrame(opcode: UInt8, payload: Data) -> Data {
        var frame = Data()
        frame.append(0x80 | opcode)
        let length = payload.count
        if length <= 125 {
            frame.append(0x80 | UInt8(length))
        } else if length <= 65_535 {
            frame.append(0x80 | 126)
            frame.append(UInt8((length >> 8) & 0xff))
            frame.append(UInt8(length & 0xff))
        } else {
            frame.append(0x80 | 127)
            let value = UInt64(length)
            for shift in stride(from: 56, through: 0, by: -8) {
                frame.append(UInt8((value >> UInt64(shift)) & 0xff))
            }
        }

        var mask = [UInt8](repeating: 0, count: 4)
        _ = SecRandomCopyBytes(kSecRandomDefault, mask.count, &mask)
        frame.append(contentsOf: mask)

        let bytes = [UInt8](payload)
        for index in bytes.indices {
            frame.append(bytes[index] ^ mask[index % 4])
        }
        return frame
    }

    private static func nextServerFrame(from buffer: inout Data) throws -> WebSocketFrame? {
        guard buffer.count >= 2 else { return nil }
        let first = buffer.byte(at: 0)
        let second = buffer.byte(at: 1)
        let opcode = first & 0x0f
        let masked = (second & 0x80) != 0
        var length = UInt64(second & 0x7f)
        var offset = 2

        if length == 126 {
            guard buffer.count >= 4 else { return nil }
            length = (UInt64(buffer.byte(at: 2)) << 8) | UInt64(buffer.byte(at: 3))
            offset = 4
        } else if length == 127 {
            guard buffer.count >= 10 else { return nil }
            length = 0
            for index in 2..<10 {
                length = (length << 8) | UInt64(buffer.byte(at: index))
            }
            offset = 10
        }

        let maskOffset = offset
        if masked {
            offset += 4
        }

        guard length <= UInt64(Int.max) else { throw BridgeClientError.unsupportedFrame }
        let totalLength = offset + Int(length)
        guard buffer.count >= totalLength else { return nil }

        var payload = buffer.subdata(in: offset..<totalLength)
        if masked {
            let mask = (0..<4).map { buffer.byte(at: maskOffset + $0) }
            var bytes = [UInt8](payload)
            for index in bytes.indices {
                bytes[index] ^= mask[index % 4]
            }
            payload = Data(bytes)
        }

        buffer.removeSubrange(0..<totalLength)
        return WebSocketFrame(opcode: opcode, payload: payload)
    }

    private struct WebSocketFrame {
        var opcode: UInt8
        var payload: Data
    }

    private func receiveLoop(
        onEvent: @escaping @Sendable (Result<InboundBridgeMessage, Error>) -> Void,
        onDebug: @escaping @Sendable (String) -> Void
    ) async {
        while !Task.isCancelled {
            do {
                guard let socketTask else { return }
                let message = try await socketTask.receive()
                switch message {
                case .string(let text):
                    onDebug("URLSession：收到文本 \(text.count) chars")
                    guard let data = text.data(using: .utf8) else {
                        onEvent(.failure(BridgeClientError.invalidMessage))
                        continue
                    }
                    let decoded = try decoder.decode(InboundBridgeMessage.self, from: data)
                    onEvent(.success(decoded))
                case .data(let data):
                    onDebug("URLSession：收到 data \(data.count) bytes")
                    let decoded = try decoder.decode(InboundBridgeMessage.self, from: data)
                    onEvent(.success(decoded))
                @unknown default:
                    onEvent(.failure(BridgeClientError.invalidMessage))
                }
            } catch {
                if !Task.isCancelled {
                    onDebug("URLSession：接收失败 \(error.localizedDescription)")
                    onEvent(.failure(error))
                }
                return
            }
        }
    }

    private static func describe(_ state: NWConnection.State) -> String {
        switch state {
        case .setup: "setup"
        case .waiting(let error): "waiting \(error.localizedDescription)"
        case .preparing: "preparing"
        case .ready: "ready"
        case .failed(let error): "failed \(error.localizedDescription)"
        case .cancelled: "cancelled"
        @unknown default: "unknown"
        }
    }
}

private extension Data {
    func byte(at offset: Int) -> UInt8 {
        self[index(startIndex, offsetBy: offset)]
    }
}
