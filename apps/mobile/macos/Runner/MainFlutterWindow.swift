import Cocoa
import FlutterMacOS
import UniformTypeIdentifiers

class MainFlutterWindow: NSWindow {
  private static let frameAutosaveName = NSWindow.FrameAutosaveName("MainFlutterWindow")
  private static let defaultWindowSize = NSSize(width: 1200, height: 800)
  private static let minimumWindowSize = NSSize(width: 480, height: 520)

  private var windowChromeChannel: FlutterMethodChannel?
  private var nativePasteBridgeChannel: FlutterMethodChannel?
  private var clipboardChannel: FlutterMethodChannel?
  private var imageDropChannel: FlutterEventChannel?
  private var imageDropHandler: ImageDropStreamHandler?
  private var nativePasteBridgeEnabled = false
  private var appUpdater: AppUpdater?
  private var localBridgeHelper: LocalBridgeHelper?
  private var appMenuBridge: AppMenuBridge?

  override func awakeFromNib() {
    titleVisibility = .hidden
    titlebarAppearsTransparent = true
    styleMask.insert(.fullSizeContentView)
    isMovableByWindowBackground = false
    minSize = Self.minimumWindowSize

    let flutterViewController = FlutterViewController()
    let messenger = flutterViewController.engine.binaryMessenger

    let chromeChannel = FlutterMethodChannel(
      name: "ccpocket/window_chrome",
      binaryMessenger: messenger)
    chromeChannel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "beginWindowDrag" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let self else {
        result(nil)
        return
      }
      guard let event = NSApp.currentEvent else {
        result(nil)
        return
      }
      self.performDrag(with: event)
      result(nil)
    }
    windowChromeChannel = chromeChannel

    let pasteBridgeChannel = FlutterMethodChannel(
      name: "ccpocket/native_paste_bridge",
      binaryMessenger: messenger)
    pasteBridgeChannel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "setEnabled" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.nativePasteBridgeEnabled = (call.arguments as? Bool) ?? false
      result(nil)
    }
    nativePasteBridgeChannel = pasteBridgeChannel

    let clipChannel = FlutterMethodChannel(
      name: "ccpocket/clipboard",
      binaryMessenger: messenger)
    clipChannel.setMethodCallHandler { call, result in
      MacClipboardImageHelper.handleMethodCall(call, result: result)
    }
    clipboardChannel = clipChannel

    let dropHandler = ImageDropStreamHandler()
    let dropChannel = FlutterEventChannel(
      name: "ccpocket/image_drop",
      binaryMessenger: messenger)
    dropChannel.setStreamHandler(dropHandler)
    imageDropHandler = dropHandler
    imageDropChannel = dropChannel

    appUpdater = AppUpdater(binaryMessenger: messenger)
    localBridgeHelper = LocalBridgeHelper(binaryMessenger: messenger)
    appMenuBridge = AppMenuBridge(binaryMessenger: messenger, window: self)

    self.contentViewController = flutterViewController

    let restored = self.setFrameUsingName(Self.frameAutosaveName)
    if !restored {
      var targetSize = Self.defaultWindowSize
      if let visibleFrame = (self.screen ?? NSScreen.main)?.visibleFrame {
        targetSize.width = min(targetSize.width, visibleFrame.width)
        targetSize.height = min(targetSize.height, visibleFrame.height)
      }
      var frame = self.frame
      frame.size = targetSize
      self.setFrame(frame, display: true)
      self.center()
    }
    self.setFrameAutosaveName(Self.frameAutosaveName)

    RegisterGeneratedPlugins(registry: flutterViewController)

    self.registerForDraggedTypes(MacClipboardImageHelper.draggedPasteboardTypes)

    super.awakeFromNib()
  }

  func installMenuBarIfNeeded() {
    appMenuBridge?.installMenusIfNeeded()
  }

  func openSettingsFromMenu() {
    appMenuBridge?.dispatch(action: "openSettings")
  }

  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    if isCommandEquals(event), appMenuBridge?.handleZoomInShortcutIfEnabled() == true {
      return true
    }

    guard nativePasteBridgeEnabled else {
      return super.performKeyEquivalent(with: event)
    }
    guard isCommandV(event) else {
      return super.performKeyEquivalent(with: event)
    }
    let pasteboard = NSPasteboard.general
    if MacClipboardImageHelper.pasteboardHasSupportedImage(pasteboard) {
      return super.performKeyEquivalent(with: event)
    }
    guard let text = pasteboard.string(forType: .string), !text.isEmpty else {
      return super.performKeyEquivalent(with: event)
    }

    nativePasteBridgeChannel?.invokeMethod("nativePaste", arguments: text)
    return true
  }

  private func isCommandV(_ event: NSEvent) -> Bool {
    event.keyCode == 9 &&
      event.modifierFlags.contains(.command) &&
      !event.modifierFlags.contains(.control) &&
      !event.modifierFlags.contains(.shift) &&
      !event.modifierFlags.contains(.option)
  }

  private func isCommandEquals(_ event: NSEvent) -> Bool {
    event.charactersIgnoringModifiers == "=" &&
      event.modifierFlags.contains(.command) &&
      !event.modifierFlags.contains(.control) &&
      !event.modifierFlags.contains(.shift) &&
      !event.modifierFlags.contains(.option)
  }
}

extension MainFlutterWindow: NSDraggingDestination {
  func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    guard imageDropHandler?.isListening == true,
      MacClipboardImageHelper.pasteboardHasSupportedImage(sender.draggingPasteboard)
    else {
      return []
    }
    return .copy
  }

  func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
    guard imageDropHandler?.isListening == true,
      MacClipboardImageHelper.pasteboardHasSupportedImage(sender.draggingPasteboard)
    else {
      return []
    }
    return .copy
  }

  func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    guard let dropHandler = imageDropHandler, dropHandler.isListening else {
      return false
    }
    let images = MacClipboardImageHelper.readDroppedImages(from: sender.draggingPasteboard)
    guard !images.isEmpty else {
      return false
    }
    dropHandler.send(images)
    return true
  }
}

private final class ImageDropStreamHandler: NSObject, FlutterStreamHandler {
  private var sink: FlutterEventSink?

  var isListening: Bool { sink != nil }

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    sink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  func send(_ images: [[String: Any]]) {
    guard let sink, !images.isEmpty else { return }
    sink(images)
  }
}

private enum MacClipboardImageHelper {
  static let maxImageBytes = 20 * 1024 * 1024
  static let maxDroppedImages = 10

  private static let gifType = NSPasteboard.PasteboardType("com.compuserve.gif")
  private static let webpType = NSPasteboard.PasteboardType("org.webmproject.webp")
  private static let publicWebpType = NSPasteboard.PasteboardType("public.webp")
  private static let jpegType = NSPasteboard.PasteboardType("public.jpeg")

  static let draggedPasteboardTypes: [NSPasteboard.PasteboardType] = [
    .fileURL,
    gifType,
    webpType,
    publicWebpType,
    .png,
    jpegType,
    .tiff,
  ]

  private static let directFormats: [(types: [NSPasteboard.PasteboardType], mimeType: String)] = [
    ([gifType], "image/gif"),
    ([webpType, publicWebpType], "image/webp"),
    ([.png], "image/png"),
    ([jpegType], "image/jpeg"),
  ]

  private static let supportedExtensions: [String: String] = [
    "gif": "image/gif",
    "webp": "image/webp",
    "png": "image/png",
    "jpg": "image/jpeg",
    "jpeg": "image/jpeg",
  ]

  static func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "hasImage":
      result(pasteboardHasSupportedImage(NSPasteboard.general))
    case "readImage":
      switch readSingleImage(from: NSPasteboard.general) {
      case .found(let payload):
        result(payload)
      case .none:
        result(nil)
      case .tooLarge:
        result(
          FlutterError(
            code: "image_load_failed",
            message: "Clipboard image exceeds size limit",
            details: nil))
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private enum ReadResult {
    case found([String: Any])
    case none
    case tooLarge
  }

  static func pasteboardHasSupportedImage(_ pasteboard: NSPasteboard) -> Bool {
    guard let types = pasteboard.types else { return false }
    for format in directFormats {
      if format.types.contains(where: { types.contains($0) }) {
        return true
      }
    }
    if types.contains(.fileURL),
      let urls = readFileURLs(from: pasteboard),
      urls.contains(where: { mimeTypeForFileURL($0) != nil })
    {
      return true
    }
    return types.contains(.tiff)
  }

  private static func readSingleImage(from pasteboard: NSPasteboard) -> ReadResult {
    // 1. Direct encoded image representations in priority order.
    for format in directFormats {
      for pbType in format.types {
        if let data = pasteboard.data(forType: pbType), !data.isEmpty {
          guard data.count <= maxImageBytes else { return .tooLarge }
          let mimeType = detectMimeType(from: data) ?? format.mimeType
          return .found([
            "bytes": FlutterStandardTypedData(bytes: data),
            "mimeType": mimeType,
          ])
        }
      }
    }

    // 2. Local image file URLs (checked before TIFF so Finder file-icon TIFFs
    //    do not shadow the copied image file).
    if let urls = readFileURLs(from: pasteboard) {
      for url in urls {
        guard let fallbackMime = mimeTypeForFileURL(url) else { continue }
        switch readImageFile(at: url, fallbackMime: fallbackMime) {
        case .found(let payload):
          return .found(payload)
        case .tooLarge:
          return .tooLarge
        case .none:
          continue
        }
      }
    }

    // 3. TIFF fallback (e.g. macOS screenshots / Copy Image) encoded to PNG.
    if let tiffData = pasteboard.data(forType: .tiff), !tiffData.isEmpty,
      let pngData = convertTiffToPng(tiffData), !pngData.isEmpty
    {
      guard pngData.count <= maxImageBytes else { return .tooLarge }
      return .found([
        "bytes": FlutterStandardTypedData(bytes: pngData),
        "mimeType": "image/png",
      ])
    }

    return .none
  }

  static func readDroppedImages(from pasteboard: NSPasteboard) -> [[String: Any]] {
    var results: [[String: Any]] = []

    if let urls = readFileURLs(from: pasteboard), !urls.isEmpty {
      for url in urls {
        guard results.count < maxDroppedImages else { break }
        guard let fallbackMime = mimeTypeForFileURL(url) else { continue }
        if case .found(let payload) = readImageFile(at: url, fallbackMime: fallbackMime) {
          results.append(payload)
        }
      }
      if !results.isEmpty {
        return results
      }
    }

    if case .found(let payload) = readSingleImage(from: pasteboard) {
      results.append(payload)
    }
    return results
  }

  private static func readFileURLs(from pasteboard: NSPasteboard) -> [URL]? {
    pasteboard.readObjects(
      forClasses: [NSURL.self],
      options: [.urlReadingFileURLsOnly: true]) as? [URL]
  }

  private static func mimeTypeForFileURL(_ url: URL) -> String? {
    guard url.isFileURL else { return nil }
    let ext = url.pathExtension.lowercased()
    return supportedExtensions[ext]
  }

  private static func readImageFile(at url: URL, fallbackMime: String) -> ReadResult {
    guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
      values.isRegularFile == true
    else {
      return .none
    }
    if let fileSize = values.fileSize {
      if fileSize <= 0 { return .none }
      if fileSize > maxImageBytes { return .tooLarge }
    }
    guard let data = try? Data(contentsOf: url), !data.isEmpty else {
      return .none
    }
    guard data.count <= maxImageBytes else { return .tooLarge }
    let mimeType = detectMimeType(from: data) ?? fallbackMime
    return .found([
      "bytes": FlutterStandardTypedData(bytes: data),
      "mimeType": mimeType,
    ])
  }

  private static func convertTiffToPng(_ tiffData: Data) -> Data? {
    guard let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
    return bitmap.representation(using: .png, properties: [:])
  }

  private static func detectMimeType(from data: Data) -> String? {
    let bytes = [UInt8](data.prefix(12))
    if bytes.count >= 4,
      bytes[0] == 0x47, bytes[1] == 0x49, bytes[2] == 0x46, bytes[3] == 0x38
    {
      return "image/gif"
    }
    if bytes.count >= 12,
      bytes[0] == 0x52, bytes[1] == 0x49, bytes[2] == 0x46, bytes[3] == 0x46,
      bytes[8] == 0x57, bytes[9] == 0x45, bytes[10] == 0x42, bytes[11] == 0x50
    {
      return "image/webp"
    }
    if bytes.count >= 8,
      bytes[0] == 0x89, bytes[1] == 0x50, bytes[2] == 0x4E, bytes[3] == 0x47
    {
      return "image/png"
    }
    if bytes.count >= 3,
      bytes[0] == 0xFF, bytes[1] == 0xD8, bytes[2] == 0xFF
    {
      return "image/jpeg"
    }
    return nil
  }
}
