import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var windowChromeChannel: FlutterMethodChannel?
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
    appUpdater = AppUpdater(binaryMessenger: flutterViewController.engine.binaryMessenger)

    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
