import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var windowChromeChannel: FlutterMethodChannel?
  private var nativePasteBridgeChannel: FlutterMethodChannel?
  private var nativePasteBridgeEnabled = false
  private var appUpdater: AppUpdater?

  override func awakeFromNib() {
    titleVisibility = .hidden
    titlebarAppearsTransparent = true
    styleMask.insert(.fullSizeContentView)
    isMovableByWindowBackground = false

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

    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    guard nativePasteBridgeEnabled else {
      return super.performKeyEquivalent(with: event)
    }
    guard isCommandV(event) else {
      return super.performKeyEquivalent(with: event)
    }
    guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else {
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
}
