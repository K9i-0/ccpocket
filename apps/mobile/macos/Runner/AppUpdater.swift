import Cocoa
import FlutterMacOS
import Sparkle

@MainActor
final class AppUpdater: NSObject, SPUUpdaterDelegate {
  static let channelName = "ccpocket/app_updater"
  static let feedURLOverrideDefaultsKey = "ccpocket.sparkle.feed_url_override"

  private let channel: FlutterMethodChannel
  private lazy var updaterController: SPUStandardUpdaterController = {
    let controller = SPUStandardUpdaterController(
      startingUpdater: true,
      updaterDelegate: self,
      userDriverDelegate: nil)
    controller.updater.clearFeedURLFromUserDefaults()
    return controller
  }()

  private var pendingProbeResult: FlutterResult?

  init(binaryMessenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: Self.channelName,
      binaryMessenger: binaryMessenger)
    super.init()
    channel.setMethodCallHandler(handle)
    _ = updaterController
  }

  private var effectiveFeedURLString: String? {
    if let override = UserDefaults.standard.string(
      forKey: Self.feedURLOverrideDefaultsKey),
      !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return override
    }

    if let bundled = Bundle.main.object(
      forInfoDictionaryKey: "SUFeedURL") as? String,
      !bundled.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return bundled
    }

    return nil
  }

  private var currentDisplayVersion: String {
    (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
      as? String) ?? "0.0.0"
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "probeForUpdate":
      probeForUpdate(result: result)
    case "performUpdate":
      performUpdate(result: result)
    case "setFeedURLOverride":
      setFeedURLOverride(arguments: call.arguments, result: result)
    case "clearFeedURLOverride":
      UserDefaults.standard.removeObject(forKey: Self.feedURLOverrideDefaultsKey)
      result(nil)
    case "getFeedURL":
      result(effectiveFeedURLString)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func probeForUpdate(result: @escaping FlutterResult) {
    guard pendingProbeResult == nil else {
      result(FlutterError(
        code: "probe_busy",
        message: "An update probe is already in progress.",
        details: nil))
      return
    }

    guard effectiveFeedURLString != nil else {
      result(FlutterError(
        code: "missing_feed_url",
        message: "Sparkle feed URL is not configured.",
        details: nil))
      return
    }

    guard updaterController.updater.canCheckForUpdates else {
      result(FlutterError(
        code: "cannot_check_for_updates",
        message: "The updater cannot check for updates right now.",
        details: nil))
      return
    }

    pendingProbeResult = result
    updaterController.updater.checkForUpdatesInBackground()
  }

  private func performUpdate(result: @escaping FlutterResult) {
    guard effectiveFeedURLString != nil else {
      result(FlutterError(
        code: "missing_feed_url",
        message: "Sparkle feed URL is not configured.",
        details: nil))
      return
    }

    updaterController.checkForUpdates(nil)
    result(nil)
  }

  private func setFeedURLOverride(arguments: Any?, result: @escaping FlutterResult) {
    guard let payload = arguments as? [String: Any] else {
      result(FlutterError(
        code: "invalid_arguments",
        message: "Expected a map payload.",
        details: nil))
      return
    }

    let rawURL = (payload["feedUrl"] as? String)?.trimmingCharacters(
      in: .whitespacesAndNewlines)

    if let rawURL, !rawURL.isEmpty {
      UserDefaults.standard.set(rawURL, forKey: Self.feedURLOverrideDefaultsKey)
    } else {
      UserDefaults.standard.removeObject(forKey: Self.feedURLOverrideDefaultsKey)
    }
    result(nil)
  }

  private func resolveProbe(
    map: [String: String]? = nil,
    error: FlutterError? = nil
  ) {
    guard let pendingProbeResult else { return }
    self.pendingProbeResult = nil

    if let error {
      pendingProbeResult(error)
    } else {
      pendingProbeResult(map)
    }
  }

  func feedURLString(for updater: SPUUpdater) -> String? {
    effectiveFeedURLString
  }

  func updaterShouldPromptForPermissionToCheck(forUpdates updater: SPUUpdater) -> Bool {
    false
  }

  func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
    resolveProbe(map: [
      "latestVersion": item.displayVersionString,
      "currentVersion": currentDisplayVersion,
      "downloadUrl": item.fileURL?.absoluteString ?? "",
      "releaseUrl": item.infoURL?.absoluteString ??
        item.fullReleaseNotesURL?.absoluteString ?? "",
    ])
  }

  func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
    resolveProbe(map: nil)
  }

  func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
    resolveProbe(error: FlutterError(
      code: "probe_failed",
      message: error.localizedDescription,
      details: nil))
  }
}
