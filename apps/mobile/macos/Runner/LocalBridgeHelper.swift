import Cocoa
import FlutterMacOS

/// Asks the bundled, non-sandboxed "CC Pocket Bridge" helper to register or
/// unregister the Bridge LaunchAgent. This app is sandboxed and cannot do that
/// itself. See docs/design/local-bridge-management.md.
final class LocalBridgeHelper {
  private let channel: FlutterMethodChannel
  private let queue = DispatchQueue(label: "ccpocket.local-bridge-helper")

  init(binaryMessenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "ccpocket/local_bridge_helper", binaryMessenger: binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      switch call.method {
      case "isAvailable":
        result(self.helperURL != nil)
      case "run":
        let action = (call.arguments as? [String: Any])?["action"] as? String ?? ""
        self.run(action: action, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// The helper needs macOS 13 (`SMAppService`) and is absent from builds
  /// that skipped the helper build phase.
  private var helperURL: URL? {
    guard #available(macOS 13.0, *) else { return nil }
    let url = Bundle.main.bundleURL
      .appendingPathComponent("Contents/Helpers/CC Pocket Bridge.app")
    return FileManager.default.fileExists(atPath: url.path) ? url : nil
  }

  private var realHome: String {
    String(cString: getpwuid(getuid())!.pointee.pw_dir)
  }

  private func run(action: String, result: @escaping FlutterResult) {
    guard let helperURL else {
      result(["ok": false, "error": "unavailable", "status": "unavailable"])
      return
    }
    let id = UUID().uuidString
    do {
      let dir = try FileManager.default.url(
        for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
      ).appendingPathComponent("local-bridge-helper", isDirectory: true)
      try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
      let request: [String: Any] = [
        "id": id, "action": action,
        "createdAt": Date().timeIntervalSince1970 * 1000,
      ]
      try JSONSerialization.data(withJSONObject: request)
        .write(to: dir.appendingPathComponent("request.json"), options: .atomic)
    } catch {
      result(["ok": false, "error": "\(error)", "status": "unknown"])
      return
    }

    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = false
    configuration.addsToRecentItems = false
    configuration.createsNewApplicationInstance = true
    let resultPath = realHome + "/.ccpocket/launcher-helper.json"
    NSWorkspace.shared.openApplication(at: helperURL, configuration: configuration) {
      [queue] _, error in
      if let error {
        DispatchQueue.main.async {
          result(["ok": false, "error": "\(error)", "status": "unknown"])
        }
        return
      }
      queue.async {
        // The helper answers within a moment; allow for a slow first launch.
        let deadline = Date().addingTimeInterval(15)
        var answer: [String: Any]?
        while Date() < deadline, answer == nil {
          if let data = FileManager.default.contents(atPath: resultPath),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            json["id"] as? String == id
          {
            answer = json
          } else {
            Thread.sleep(forTimeInterval: 0.2)
          }
        }
        DispatchQueue.main.async {
          result(answer ?? ["ok": false, "error": "timeout", "status": "unknown"])
        }
      }
    }
  }
}
