import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow, NSToolbarDelegate {
  private let windowToolbar = NSToolbar(identifier: "ccpocket.mainToolbar")
  private var windowChromeChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    titleVisibility = .hidden
    titlebarAppearsTransparent = true
    styleMask.insert(.fullSizeContentView)
    toolbarStyle = .unified
    isMovableByWindowBackground = false

    windowToolbar.delegate = self
    windowToolbar.displayMode = .iconOnly
    windowToolbar.sizeMode = .regular
    windowToolbar.allowsUserCustomization = false
    windowToolbar.showsBaselineSeparator = false
    toolbar = windowToolbar

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

    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    []
  }

  func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    []
  }
}
