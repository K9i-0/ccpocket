import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow, NSToolbarDelegate {
  private let windowToolbar = NSToolbar(identifier: "ccpocket.mainToolbar")

  override func awakeFromNib() {
    titleVisibility = .hidden
    titlebarAppearsTransparent = true
    styleMask.insert(.fullSizeContentView)
    toolbarStyle = .unified
    isMovableByWindowBackground = true

    windowToolbar.delegate = self
    windowToolbar.displayMode = .iconOnly
    windowToolbar.sizeMode = .regular
    windowToolbar.allowsUserCustomization = false
    windowToolbar.showsBaselineSeparator = false
    toolbar = windowToolbar

    let flutterViewController = FlutterViewController()
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
