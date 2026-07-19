import XCTest
@testable import CCPocketNative

final class ConnectionURLParserTests: XCTestCase {
    func testBridgeDeepLink() {
        let parsed = ConnectionURLParser.parse("ccpocket://connect?url=ws://192.168.1.4:8765&token=abc")
        XCTAssertEqual(parsed, .connection(ConnectionParams(serverURL: "ws://192.168.1.4:8765", token: "abc")))
    }

    func testBareHostPort() {
        let parsed = ConnectionURLParser.parse("192.168.1.4:8765")
        XCTAssertEqual(parsed, .connection(ConnectionParams(serverURL: "ws://192.168.1.4:8765", token: nil)))
    }

    func testSessionDeepLink() {
        let parsed = ConnectionURLParser.parse("ccpocket://session/session-123")
        XCTAssertEqual(parsed, .session("session-123"))
    }
}

