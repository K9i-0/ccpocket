import Flutter
@testable import Runner
import UIKit
import XCTest

class RunnerTests: XCTestCase {

  func testExample() {
    // If you add code to the Runner application, consider adding tests here.
    // See https://developer.apple.com/documentation/xctest for more information about using XCTest.
  }

  func testWatchDeliveryRequiresPairedInstalledWatch() {
    XCTAssertFalse(
      WatchConnectivityManager.canDeliver(
        isPaired: false,
        isWatchAppInstalled: false
      )
    )
    XCTAssertFalse(
      WatchConnectivityManager.canDeliver(
        isPaired: true,
        isWatchAppInstalled: false
      )
    )
    XCTAssertTrue(
      WatchConnectivityManager.canDeliver(
        isPaired: true,
        isWatchAppInstalled: true
      )
    )
  }
}
