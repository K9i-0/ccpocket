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

  private var currentBuildNumber: String {
    (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion")
      as? String) ?? "0"
  }

  private var diagnostics: [String: String] {
    [
      "feedURL": effectiveFeedURLString ?? "",
      "bundlePath": Bundle.main.bundleURL.path,
      "currentVersion": currentDisplayVersion,
      "currentBuild": currentBuildNumber,
      "canCheckForUpdates": String(updaterController.updater.canCheckForUpdates),
    ]
  }

  private func log(_ message: String) {
    NSLog("[CCPocket][Sparkle] \(message)")
  }

  private func itemSummary(_ item: SUAppcastItem) -> String {
    [
      "displayVersion=\(item.displayVersionString)",
      "version=\(item.versionString)",
      "fileURL=\(item.fileURL?.absoluteString ?? "<nil>")",
      "infoURL=\(item.infoURL?.absoluteString ?? "<nil>")",
      "installationType=\(item.installationType)",
    ].joined(separator: " ")
  }

  private func errorSummary(_ error: Error) -> String {
    let nsError = error as NSError
    var parts = [
      "errorDomain=\(nsError.domain)",
      "errorCode=\(nsError.code)",
      "message=\(error.localizedDescription)",
    ]

    if let reason = nsError.localizedFailureReason {
      parts.append("reason=\(reason)")
    }
    if let suggestion = nsError.localizedRecoverySuggestion {
      parts.append("recoverySuggestion=\(suggestion)")
    }

    return parts.joined(separator: " ")
  }

  private func errorDetails(_ extra: [String: String] = [:]) -> [String: String] {
    diagnostics.merging(extra) { _, new in new }
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
    log(
      "probe requested version=\(currentDisplayVersion) build=\(currentBuildNumber) " +
        "feedURL=\(effectiveFeedURLString ?? "<nil>") " +
        "canCheckForUpdates=\(updaterController.updater.canCheckForUpdates) " +
        "bundlePath=\(Bundle.main.bundleURL.path)")

    guard pendingProbeResult == nil else {
      log("probe rejected: another probe is already pending")
      result(FlutterError(
        code: "probe_busy",
        message: "An update probe is already in progress.",
        details: errorDetails()))
      return
    }

    guard effectiveFeedURLString != nil else {
      log("probe rejected: missing feed URL")
      result(FlutterError(
        code: "missing_feed_url",
        message: "Sparkle feed URL is not configured.",
        details: errorDetails()))
      return
    }

    guard updaterController.updater.canCheckForUpdates else {
      log("probe rejected: Sparkle cannot check for updates right now")
      result(FlutterError(
        code: "cannot_check_for_updates",
        message: "The updater cannot check for updates right now.",
        details: errorDetails()))
      return
    }

    pendingProbeResult = result
    log("probe started with checkForUpdatesInBackground")
    updaterController.updater.checkForUpdatesInBackground()
  }

  private func performUpdate(result: @escaping FlutterResult) {
    log(
      "manual update requested feedURL=\(effectiveFeedURLString ?? "<nil>") " +
        "canCheckForUpdates=\(updaterController.updater.canCheckForUpdates) " +
        "bundlePath=\(Bundle.main.bundleURL.path)")

    guard effectiveFeedURLString != nil else {
      log("manual update rejected: missing feed URL")
      result(FlutterError(
        code: "missing_feed_url",
        message: "Sparkle feed URL is not configured.",
        details: errorDetails()))
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
      log("feed URL override set: \(rawURL)")
    } else {
      UserDefaults.standard.removeObject(forKey: Self.feedURLOverrideDefaultsKey)
      log("feed URL override cleared")
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
    let feedURL = effectiveFeedURLString
    log("Sparkle requested feed URL: \(feedURL ?? "<nil>")")
    return feedURL
  }

  func updaterShouldPromptForPermissionToCheck(forUpdates updater: SPUUpdater) -> Bool {
    false
  }

  func updater(_ updater: SPUUpdater, didFinishLoading appcast: SUAppcast) {
    log("appcast loaded")
  }

  func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
    log("probe found update \(itemSummary(item))")
    resolveProbe(map: [
      "status": "foundUpdate",
      "latestVersion": item.displayVersionString,
      "currentVersion": currentDisplayVersion,
      "downloadUrl": item.fileURL?.absoluteString ?? "",
      "releaseUrl": item.infoURL?.absoluteString ??
        item.fullReleaseNotesURL?.absoluteString ?? "",
    ])
  }

  func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
    let nsError = error as NSError
    log("probe did not find update \(errorSummary(error))")
    resolveProbe(map: [
      "status": "noUpdate",
      "currentVersion": currentDisplayVersion,
      "errorDomain": nsError.domain,
      "errorCode": String(nsError.code),
      "errorMessage": error.localizedDescription,
    ])
  }

  func updater(
    _ updater: SPUUpdater,
    willDownloadUpdate item: SUAppcastItem,
    with request: NSMutableURLRequest
  ) {
    log(
      "will download update \(itemSummary(item)) requestURL=" +
        "\(request.url?.absoluteString ?? "<nil>")")
  }

  func updater(_ updater: SPUUpdater, didDownloadUpdate item: SUAppcastItem) {
    log("did download update \(itemSummary(item))")
  }

  func updater(
    _ updater: SPUUpdater,
    failedToDownloadUpdate item: SUAppcastItem,
    error: Error
  ) {
    log("failed to download update \(itemSummary(item)) \(errorSummary(error))")
  }

  func userDidCancelDownload(_ updater: SPUUpdater) {
    log("user cancelled update download")
  }

  func updater(_ updater: SPUUpdater, willExtractUpdate item: SUAppcastItem) {
    log("will extract update \(itemSummary(item))")
  }

  func updater(_ updater: SPUUpdater, didExtractUpdate item: SUAppcastItem) {
    log("did extract update \(itemSummary(item))")
  }

  func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
    log("will install update \(itemSummary(item))")
  }

  func updaterShouldRelaunchApplication(_ updater: SPUUpdater) -> Bool {
    log("should relaunch application: true")
    return true
  }

  func updaterWillRelaunchApplication(_ updater: SPUUpdater) {
    log("will relaunch application")
  }

  func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
    let nsError = error as NSError
    log("update cycle aborted \(errorSummary(error))")
    resolveProbe(error: FlutterError(
      code: "probe_failed",
      message: error.localizedDescription,
      details: errorDetails([
        "errorDomain": nsError.domain,
        "errorCode": String(nsError.code),
      ])))
  }

  func updater(
    _ updater: SPUUpdater,
    didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
    error: Error?
  ) {
    if let error {
      log(
        "update cycle finished updateCheck=\(String(describing: updateCheck)) " +
          "\(errorSummary(error))")
    } else {
      log(
        "update cycle finished updateCheck=\(String(describing: updateCheck)) " +
          "error=<nil>")
    }
  }
}
