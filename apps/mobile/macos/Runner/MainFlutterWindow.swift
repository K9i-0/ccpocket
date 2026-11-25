import Cocoa
import FlutterMacOS
import UniformTypeIdentifiers

class MainFlutterWindow: NSWindow {
  private static let frameAutosaveName = NSWindow.FrameAutosaveName("MainFlutterWindow")
  private static let defaultWindowSize = NSSize(width: 1200, height: 800)
  private static let minimumWindowSize = NSSize(width: 480, height: 520)

  private static let pasteboardImageTypes: Set<NSPasteboard.PasteboardType> = [
    .png,
    .tiff,
    NSPasteboard.PasteboardType("public.jpeg"),
    NSPasteboard.PasteboardType("public.heic"),
    NSPasteboard.PasteboardType("public.webp"),
    NSPasteboard.PasteboardType("public.gif"),
  ]

  private var windowChromeChannel: FlutterMethodChannel?
  private var nativePasteBridgeChannel: FlutterMethodChannel?
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
    let chromeChannel = FlutterMethodChannel(
      name: "ccpocket/window_chrome",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
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
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    pasteBridgeChannel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "setEnabled" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.nativePasteBridgeEnabled = (call.arguments as? Bool) ?? false
      result(nil)
    }
    nativePasteBridgeChannel = pasteBridgeChannel
    appUpdater = AppUpdater(binaryMessenger: flutterViewController.engine.binaryMessenger)
    localBridgeHelper = LocalBridgeHelper(
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    appMenuBridge = AppMenuBridge(
      binaryMessenger: flutterViewController.engine.binaryMessenger,
      window: self)

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
    if pasteboardContainsImage(pasteboard) {
      return super.performKeyEquivalent(with: event)
    }
    guard let text = pasteboard.string(forType: .string), !text.isEmpty else {
      return super.performKeyEquivalent(with: event)
    }

    nativePasteBridgeChannel?.invokeMethod("nativePaste", arguments: text)
    return true
  }

  private func pasteboardContainsImage(_ pasteboard: NSPasteboard) -> Bool {
    guard let types = pasteboard.types else { return false }
    let hasDirectImageType = types.contains { type in
      if Self.pasteboardImageTypes.contains(type) {
        return true
      }
      return UTType(type.rawValue)?.conforms(to: .image) == true
    }
    if hasDirectImageType {
      return true
    }
    if types.contains(.fileURL),
       let urls = pasteboard.readObjects(
         forClasses: [NSURL.self],
         options: [.urlReadingFileURLsOnly: true]) as? [URL] {
      return urls.contains { url in
        guard !url.pathExtension.isEmpty else { return false }
        return UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true
      }
    }
    return false
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
