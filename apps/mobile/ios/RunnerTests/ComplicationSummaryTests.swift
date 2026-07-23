import XCTest

final class ComplicationSummaryTests: XCTestCase {
  func testAggregatesActiveSessionStatuses() {
    let summary = ComplicationSummary(dictionary: [
      "connected": true,
      "activeSessionCount": 5,
      "statusCounts": [
        "running": 1,
        "starting": 1,
        "compacting": 1,
        "waiting_approval": 1,
        "idle": 1,
      ],
      "generatedAt": "2026-07-23T03:00:00Z",
    ])

    XCTAssertTrue(summary.connected)
    XCTAssertEqual(summary.active, 5)
    XCTAssertEqual(summary.working, 3)
    XCTAssertEqual(summary.needsYou, 1)
    XCTAssertEqual(summary.ready, 1)
    XCTAssertNotNil(summary.generatedAt)
  }

  func testClampsInconsistentCountsToActiveTotal() {
    let summary = ComplicationSummary(dictionary: [
      "activeSessionCount": 2,
      "statusCounts": [
        "running": 5,
        "waiting_approval": 4,
      ],
    ])

    XCTAssertEqual(summary.active, 2)
    XCTAssertEqual(summary.working, 2)
    XCTAssertEqual(summary.needsYou, 0)
    XCTAssertEqual(summary.ready, 0)
  }

  func testFallsBackToSessionCount() {
    let summary = ComplicationSummary(dictionary: [
      "sessions": [
        ["id": "one"],
        ["id": "two"],
        ["id": "three"],
      ],
      "statusCounts": [
        "waiting_approval": 1,
      ],
    ])

    XCTAssertEqual(summary.active, 3)
    XCTAssertEqual(summary.working, 0)
    XCTAssertEqual(summary.needsYou, 1)
    XCTAssertEqual(summary.ready, 2)
  }

  func testExpiresStaleConnectedSnapshot() throws {
    let summary = ComplicationSummary(dictionary: [
      "connected": true,
      "activeSessionCount": 1,
      "statusCounts": ["running": 1],
      "generatedAt": "2026-07-23T03:00:00Z",
    ])
    let generatedAt = try XCTUnwrap(summary.generatedAt)

    XCTAssertTrue(
      summary
        .displayed(at: generatedAt.addingTimeInterval(59 * 60))
        .connected
    )
    XCTAssertFalse(
      summary
        .displayed(at: generatedAt.addingTimeInterval(61 * 60))
        .connected
    )
  }

  func testExtendsTimelineWithoutReloadingEverySnapshot() throws {
    let first = ComplicationSummary(dictionary: [
      "connected": true,
      "activeSessionCount": 1,
      "statusCounts": ["running": 1],
      "generatedAt": "2026-07-23T03:00:00Z",
    ])
    let refreshed = ComplicationSummary(dictionary: [
      "connected": true,
      "activeSessionCount": 1,
      "statusCounts": ["running": 1],
      "generatedAt": "2026-07-23T03:30:00Z",
    ])
    let initialReload = try XCTUnwrap(first.generatedAt)

    XCTAssertFalse(
      ComplicationSnapshotStore.shouldReloadTimeline(
        previous: first,
        current: refreshed,
        lastReloadAt: initialReload,
        now: initialReload.addingTimeInterval(30 * 60)
      )
    )
    XCTAssertTrue(
      ComplicationSnapshotStore.shouldReloadTimeline(
        previous: refreshed,
        current: refreshed,
        lastReloadAt: initialReload,
        now: initialReload.addingTimeInterval(46 * 60)
      )
    )
  }
}
