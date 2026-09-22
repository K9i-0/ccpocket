import Flutter
import UIKit
import XCTest
@testable import Runner

@available(iOS 16.0, *)
final class RunnerTests: XCTestCase {
  private func makeView(_ messenger: PasteTestMessenger) -> FlutterPlatformView {
    ImagePasteViewFactory(messenger: messenger).create(
      withFrame: CGRect(x: 0, y: 0, width: 320, height: 52),
      viewIdentifier: 42, arguments: nil
    )
  }

  func testImageProviderPreservesGIFBeforePNGFallback() {
    let received = expectation(description: "image delivered")
    let messenger = PasteTestMessenger()
    let platformView = makeView(messenger)
    let gif = Data("GIF89a".utf8)
    let provider = NSItemProvider()
    provider.registerDataRepresentation(forTypeIdentifier: "public.png", visibility: .all) {
      completion in completion(Data([1, 2, 3]), nil); return nil
    }
    provider.registerDataRepresentation(forTypeIdentifier: "com.compuserve.gif", visibility: .all) {
      completion in completion(gif, nil); return nil
    }
    messenger.onMessage = { channel, call in
      XCTAssertEqual(channel, "ccpocket/image_paste_button/42")
      XCTAssertEqual(call.method, "image")
      let args = call.arguments as? [String: Any]
      XCTAssertEqual(args?["mimeType"] as? String, "image/gif")
      XCTAssertEqual((args?["bytes"] as? FlutterStandardTypedData)?.data, gif)
      received.fulfill()
    }
    // Providers are the system's delivery boundary; do not read the clipboard.
    platformView.view().paste(itemProviders: [provider])
    wait(for: [received], timeout: 3)
    XCTAssertFalse(platformView.view().isUserInteractionEnabled)
  }

  func testProviderFailureAllowsRetry() {
    let failed = expectation(description: "read error")
    let retried = expectation(description: "retry delivered")
    let messenger = PasteTestMessenger()
    let platformView = makeView(messenger)
    let broken = NSItemProvider()
    broken.registerDataRepresentation(forTypeIdentifier: "public.png", visibility: .all) {
      completion in
      completion(nil, NSError(domain: "PasteTest", code: 1))
      return nil
    }
    messenger.onMessage = { _, call in
      XCTAssertEqual(call.method, "error")
      failed.fulfill()
    }
    platformView.view().paste(itemProviders: [broken])
    wait(for: [failed], timeout: 3)
    XCTAssertTrue(platformView.view().isUserInteractionEnabled)

    messenger.onMessage = { _, call in
      XCTAssertEqual(call.method, "image")
      retried.fulfill()
    }
    platformView.view().paste(itemProviders: [
      NSItemProvider(item: Data([1, 2, 3]) as NSData, typeIdentifier: "public.png")
    ])
    wait(for: [retried], timeout: 3)
  }

  func testTextOnlyProviderDoesNotDeliverImage() {
    let messenger = PasteTestMessenger()
    let platformView = makeView(messenger)
    var methods = [String]()
    messenger.onMessage = { _, call in methods.append(call.method) }
    platformView.view().paste(itemProviders: [NSItemProvider(object: "Text" as NSString)])
    XCTAssertEqual(methods, ["error"])
    XCTAssertTrue(platformView.view().isUserInteractionEnabled)
  }
}

private final class PasteTestMessenger: NSObject, FlutterBinaryMessenger {
  var onMessage: ((String, FlutterMethodCall) -> Void)?

  func send(onChannel channel: String, message: Data?) {
    guard let message else { return }
    onMessage?(channel, FlutterStandardMethodCodec.sharedInstance().decodeMethodCall(message))
  }

  func send(onChannel channel: String, message: Data?, binaryReply callback: FlutterBinaryReply?) {
    send(onChannel: channel, message: message)
    callback?(nil)
  }

  func setMessageHandlerOnChannel(
    _ channel: String, binaryMessageHandler handler: FlutterBinaryMessageHandler?
  ) -> FlutterBinaryMessengerConnection { 0 }

  func cleanUpConnection(_ connection: FlutterBinaryMessengerConnection) {}
}
