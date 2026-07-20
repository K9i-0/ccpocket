import XCTest
@testable import CCPocketNative

final class BridgeDecodingTests: XCTestCase {
    private let decoder = JSONDecoder()

    func testSessionListDecoding() throws {
        let json = """
        {
          "type": "session_list",
          "sessions": [
            {
              "id": "s1",
              "provider": "codex",
              "projectPath": "/Users/me/app",
              "status": "waiting_approval",
              "createdAt": "now",
              "lastActivityAt": "now",
              "pendingPermission": {
                "toolUseId": "tool-1",
                "toolName": "Bash",
                "input": {"command": "npm test"}
              }
            }
          ],
          "allowedDirs": ["/Users/me"],
          "codexModels": ["gpt-5.6-sol"],
          "claudeModels": [],
          "bridgeVersion": "1.0.0"
        }
        """
        let inbound = try decoder.decode(InboundBridgeMessage.self, from: Data(json.utf8))
        guard case .sessionList(let list) = inbound.message else {
            return XCTFail("Expected session_list")
        }
        XCTAssertEqual(list.sessions.first?.status, .waitingApproval)
        XCTAssertEqual(list.sessions.first?.pendingPermission?.toolName, "Bash")
        XCTAssertEqual(list.codexModels, ["gpt-5.6-sol"])
    }

    func testHistoryDeltaDecoding() throws {
        let json = """
        {
          "type": "history_delta",
          "sessionId": "s1",
          "fromSeq": 1,
          "toSeq": 2,
          "messages": [
            {"seq": 2, "message": {"type": "stream_delta", "text": "hello"}}
          ],
          "status": "running"
        }
        """
        let inbound = try decoder.decode(InboundBridgeMessage.self, from: Data(json.utf8))
        guard case .historyDelta(let delta) = inbound.message else {
            return XCTFail("Expected history_delta")
        }
        XCTAssertEqual(delta.sessionId, "s1")
        XCTAssertEqual(delta.toSeq, 2)
        XCTAssertEqual(delta.status, .running)
    }
}

