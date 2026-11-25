import Cocoa
import FlutterMacOS

/// Bridges macOS native menu bar actions, dynamic menu state, window title,
/// and Dock badge between AppKit and Flutter via `ccpocket/app_menu`.
final class AppMenuBridge: NSObject, NSMenuItemValidation {
  static let channelName = "ccpocket/app_menu"

  private enum MenuKey {
    static let file = "file"
    static let view = "view"
    static let session = "session"
    static let help = "help"
  }

  private enum ActionId {
    static let openSettings = "openSettings"
    static let openLocalBridge = "openLocalBridge"
    static let checkForUpdates = "checkForUpdates"
    static let newSession = "newSession"
    static let closeActive = "closeActive"
    static let reload = "reload"
    static let disconnect = "disconnect"
    static let toggleSidebar = "toggleSidebar"
    static let openSearch = "openSearch"
    static let toggleGitPane = "toggleGitPane"
    static let toggleExplorePane = "toggleExplorePane"
    static let toggleGalleryPane = "toggleGalleryPane"
    static let actualSize = "actualSize"
    static let zoomIn = "zoomIn"
    static let zoomOut = "zoomOut"
    static let stopGeneration = "stopGeneration"
    static let permissionMode = "permissionMode"
    static let showShortcuts = "showShortcuts"
    static let openSetupGuide = "openSetupGuide"
    static let openChangelog = "openChangelog"
    static let openGitHub = "openGitHub"
  }

  private let channel: FlutterMethodChannel
  private weak var window: NSWindow?
  private var menusInstalled = false

  private var itemsByAction: [String: NSMenuItem] = [:]
  private var topMenusByKey: [String: NSMenuItem] = [:]
  private var enabledByAction: [String: Bool] = [
    ActionId.openSettings: true,
    ActionId.openLocalBridge: true,
    ActionId.checkForUpdates: true,
    ActionId.newSession: false,
    ActionId.closeActive: true,
    ActionId.reload: true,
    ActionId.disconnect: false,
    ActionId.toggleSidebar: true,
    ActionId.openSearch: true,
    ActionId.toggleGitPane: false,
    ActionId.toggleExplorePane: false,
    ActionId.toggleGalleryPane: false,
    ActionId.actualSize: true,
    ActionId.zoomIn: true,
    ActionId.zoomOut: true,
    ActionId.stopGeneration: false,
    ActionId.permissionMode: false,
    ActionId.showShortcuts: true,
    ActionId.openSetupGuide: true,
    ActionId.openChangelog: true,
    ActionId.openGitHub: true,
  ]

  init(binaryMessenger: FlutterBinaryMessenger, window: NSWindow) {
    self.channel = FlutterMethodChannel(
      name: Self.channelName,
      binaryMessenger: binaryMessenger)
    self.window = window
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handleMethodCall(call, result: result)
    }
    installMenusIfNeeded()
  }

  /// Installs or updates custom menu items in `NSApp.mainMenu` while keeping
  /// AppKit's native Edit, Window, Services, Hide, Quit, and Full Screen menus
  /// completely intact. Safe to call multiple times.
  func installMenusIfNeeded() {
    guard !menusInstalled, let mainMenu = NSApp.mainMenu else { return }
    menusInstalled = true

    configureAppMenu(mainMenu: mainMenu)
    configureFileMenu(mainMenu: mainMenu)
    configureViewMenu(mainMenu: mainMenu)
    configureSessionMenu(mainMenu: mainMenu)
    configureHelpMenu(mainMenu: mainMenu)
  }

  /// Dispatches a menu action directly to Flutter, revealing the window first
  /// when needed.
  func dispatch(action actionId: String) {
    if actionId != ActionId.closeActive, let window = window, !window.isVisible {
      window.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
    }
    channel.invokeMethod("onMenuAction", arguments: ["action": actionId])
  }

  /// Allows `MainFlutterWindow` to support unshifted `⌘=` as Zoom In alongside
  /// the menu's `⌘+` key equivalent.
  func handleZoomInShortcutIfEnabled() -> Bool {
    guard enabledByAction[ActionId.zoomIn] ?? true else { return false }
    dispatch(action: ActionId.zoomIn)
    return true
  }

  // MARK: - NSMenuItemValidation

  func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
    guard let actionId = menuItem.representedObject as? String else {
      return true
    }
    if actionId == ActionId.closeActive, window?.isVisible != true {
      return false
    }
    return enabledByAction[actionId] ?? true
  }

  // MARK: - Menu Construction

  private func makeItem(
    actionId: String,
    title: String,
    keyEquivalent: String = "",
    modifiers: NSEvent.ModifierFlags = [.command]
  ) -> NSMenuItem {
    let item = NSMenuItem(
      title: title,
      action: #selector(handleMenuItem(_:)),
      keyEquivalent: keyEquivalent)
    if !keyEquivalent.isEmpty {
      item.keyEquivalentModifierMask = modifiers
    }
    item.target = self
    item.representedObject = actionId
    itemsByAction[actionId] = item
    return item
  }

  private func configureAppMenu(mainMenu: NSMenu) {
    guard let appMenu = mainMenu.items.first?.submenu else { return }

    // Wire existing Preferences… / Settings… (⌘,) item in place.
    if let prefsIndex = appMenu.items.firstIndex(where: {
      $0.keyEquivalent == "," && $0.keyEquivalentModifierMask.contains(.command)
    }) {
      let prefsItem = appMenu.items[prefsIndex]
      prefsItem.target = self
      prefsItem.action = #selector(handleMenuItem(_:))
      prefsItem.representedObject = ActionId.openSettings
      itemsByAction[ActionId.openSettings] = prefsItem

      let localBridgeItem = makeItem(
        actionId: ActionId.openLocalBridge,
        title: "Bridge on this Mac…",
        keyEquivalent: ",",
        modifiers: [.command, .shift])
      appMenu.insertItem(localBridgeItem, at: prefsIndex + 1)
    } else {
      let settingsItem = makeItem(
        actionId: ActionId.openSettings,
        title: "Settings…",
        keyEquivalent: ",",
        modifiers: [.command])
      let localBridgeItem = makeItem(
        actionId: ActionId.openLocalBridge,
        title: "Bridge on this Mac…",
        keyEquivalent: ",",
        modifiers: [.command, .shift])
      let insertIndex = min(2, appMenu.items.count)
      appMenu.insertItem(settingsItem, at: insertIndex)
      appMenu.insertItem(localBridgeItem, at: insertIndex + 1)
    }

    // Insert "Check for Updates…" right after "About <App>".
    let checkForUpdatesItem = makeItem(
      actionId: ActionId.checkForUpdates,
      title: "Check for Updates…")
    if let aboutIndex = appMenu.items.firstIndex(where: {
      $0.action == #selector(NSApplication.orderFrontStandardAboutPanel(_:))
    }) {
      appMenu.insertItem(checkForUpdatesItem, at: aboutIndex + 1)
    } else {
      appMenu.insertItem(checkForUpdatesItem, at: min(1, appMenu.items.count))
    }
  }

  private func configureFileMenu(mainMenu: NSMenu) {
    let fileMenu = NSMenu(title: "File")
    fileMenu.addItem(makeItem(
      actionId: ActionId.newSession,
      title: "New Session",
      keyEquivalent: "n"))
    fileMenu.addItem(.separator())
    fileMenu.addItem(makeItem(
      actionId: ActionId.closeActive,
      title: "Close",
      keyEquivalent: "w"))
    fileMenu.addItem(.separator())
    fileMenu.addItem(makeItem(
      actionId: ActionId.reload,
      title: "Reconnect / Refresh",
      keyEquivalent: "r"))
    fileMenu.addItem(makeItem(
      actionId: ActionId.disconnect,
      title: "Disconnect"))

    let fileTopItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
    fileTopItem.submenu = fileMenu
    let insertIndex = min(1, mainMenu.items.count)
    mainMenu.insertItem(fileTopItem, at: insertIndex)
    topMenusByKey[MenuKey.file] = fileTopItem
  }

  private func configureViewMenu(mainMenu: NSMenu) {
    let viewTopItem: NSMenuItem
    let viewMenu: NSMenu
    if let existing = mainMenu.items.first(where: { $0.submenu?.title == "View" || $0.title == "View" }),
       let submenu = existing.submenu {
      viewTopItem = existing
      viewMenu = submenu
    } else {
      viewMenu = NSMenu(title: "View")
      viewTopItem = NSMenuItem(title: "View", action: nil, keyEquivalent: "")
      viewTopItem.submenu = viewMenu
      mainMenu.insertItem(viewTopItem, at: min(3, mainMenu.items.count))
    }
    topMenusByKey[MenuKey.view] = viewTopItem

    let items: [NSMenuItem] = [
      makeItem(
        actionId: ActionId.toggleSidebar,
        title: "Toggle Sidebar",
        keyEquivalent: "\\"),
      makeItem(
        actionId: ActionId.openSearch,
        title: "Quick Search",
        keyEquivalent: "k"),
      .separator(),
      makeItem(
        actionId: ActionId.toggleGitPane,
        title: "Git Diff",
        keyEquivalent: "g",
        modifiers: [.command, .shift]),
      makeItem(
        actionId: ActionId.toggleExplorePane,
        title: "File Explorer",
        keyEquivalent: "e",
        modifiers: [.command, .shift]),
      makeItem(
        actionId: ActionId.toggleGalleryPane,
        title: "Gallery",
        keyEquivalent: "i",
        modifiers: [.command, .shift]),
      .separator(),
      makeItem(
        actionId: ActionId.actualSize,
        title: "Actual Size",
        keyEquivalent: "0"),
      makeItem(
        actionId: ActionId.zoomIn,
        title: "Zoom In",
        keyEquivalent: "+"),
      makeItem(
        actionId: ActionId.zoomOut,
        title: "Zoom Out",
        keyEquivalent: "-"),
      .separator(),
    ]

    for (offset, item) in items.enumerated() {
      viewMenu.insertItem(item, at: offset)
    }
  }

  private func configureSessionMenu(mainMenu: NSMenu) {
    let sessionMenu = NSMenu(title: "Session")
    sessionMenu.addItem(makeItem(
      actionId: ActionId.stopGeneration,
      title: "Stop Generation",
      keyEquivalent: "."))
    sessionMenu.addItem(makeItem(
      actionId: ActionId.permissionMode,
      title: "Permission Mode",
      keyEquivalent: "p",
      modifiers: [.command, .shift]))

    let sessionTopItem = NSMenuItem(title: "Session", action: nil, keyEquivalent: "")
    sessionTopItem.submenu = sessionMenu

    let insertIndex: Int
    if let viewItem = topMenusByKey[MenuKey.view],
       let viewIndex = mainMenu.items.firstIndex(of: viewItem) {
      insertIndex = viewIndex + 1
    } else {
      insertIndex = max(0, mainMenu.items.count - 2)
    }
    mainMenu.insertItem(sessionTopItem, at: insertIndex)
    topMenusByKey[MenuKey.session] = sessionTopItem
  }

  private func configureHelpMenu(mainMenu: NSMenu) {
    let helpTopItem: NSMenuItem
    let helpMenu: NSMenu
    if let existing = mainMenu.items.first(where: {
      $0.submenu === NSApp.helpMenu || $0.submenu?.title == "Help" || $0.title == "Help"
    }), let submenu = existing.submenu {
      helpTopItem = existing
      helpMenu = submenu
    } else {
      helpMenu = NSMenu(title: "Help")
      helpTopItem = NSMenuItem(title: "Help", action: nil, keyEquivalent: "")
      helpTopItem.submenu = helpMenu
      mainMenu.addItem(helpTopItem)
      NSApp.helpMenu = helpMenu
    }
    topMenusByKey[MenuKey.help] = helpTopItem

    helpMenu.addItem(makeItem(
      actionId: ActionId.showShortcuts,
      title: "Keyboard Shortcuts",
      keyEquivalent: "/"))
    helpMenu.addItem(.separator())
    helpMenu.addItem(makeItem(
      actionId: ActionId.openSetupGuide,
      title: "Setup Guide"))
    helpMenu.addItem(makeItem(
      actionId: ActionId.openChangelog,
      title: "Changelog"))
    helpMenu.addItem(makeItem(
      actionId: ActionId.openGitHub,
      title: "GitHub Repository"))
  }

  // MARK: - Actions & MethodChannel

  @objc private func handleMenuItem(_ sender: NSMenuItem) {
    guard let actionId = sender.representedObject as? String else { return }
    dispatch(action: actionId)
  }

  private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    installMenusIfNeeded()
    switch call.method {
    case "updateMenuState":
      if let payload = call.arguments as? [String: Any] {
        applyMenuState(payload)
      }
      result(nil)
    case "setWindowTitle":
      if let payload = call.arguments as? [String: Any],
         let title = payload["title"] as? String {
        window?.title = title
      }
      result(nil)
    case "setDockBadge":
      let label = (call.arguments as? [String: Any])?["label"] as? String
      let trimmed = label?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      NSApp.dockTile.badgeLabel = trimmed.isEmpty ? nil : trimmed
      result(nil)
    case "performCloseWindow":
      window?.performClose(nil)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func applyMenuState(_ payload: [String: Any]) {
    if let menuTitles = payload["menuTitles"] as? [String: String] {
      for (key, title) in menuTitles {
        guard !title.isEmpty, let topItem = topMenusByKey[key] else { continue }
        topItem.title = title
        topItem.submenu?.title = title
      }
    }

    if let items = payload["items"] as? [String: [String: Any]] {
      for (actionId, state) in items {
        guard let item = itemsByAction[actionId] else { continue }
        if let title = state["title"] as? String, !title.isEmpty {
          item.title = title
        }
        if let enabled = state["enabled"] as? Bool {
          enabledByAction[actionId] = enabled
          item.isEnabled = enabled
        }
        if let checked = state["checked"] as? Bool {
          item.state = checked ? .on : .off
        }
      }
    }
  }
}
