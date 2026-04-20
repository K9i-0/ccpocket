#!/usr/bin/env swift
//
// sim-tap.swift — Tap native iOS Simulator UI elements by accessibility label.
//
// Usage:
//   swift scripts/sim-tap.swift tap "許可"        # Find & tap button by label
//   swift scripts/sim-tap.swift describe          # Dump accessible elements
//   swift scripts/sim-tap.swift wait "許可" 10    # Wait up to 10s for element, then tap
//
// Requires: Accessibility permission for Terminal/iTerm in System Settings.
//

import AppKit
import Foundation

let storeScreenshotBundleId = "com.k9i.ccpocket"

// MARK: - AX Helpers

func axValue<T>(_ element: AXUIElement, _ attr: String) -> T? {
    var value: AnyObject?
    guard AXUIElementCopyAttributeValue(element, attr as CFString, &value) == .success else {
        return nil
    }
    return value as? T
}

func axChildren(_ element: AXUIElement) -> [AXUIElement] {
    axValue(element, kAXChildrenAttribute) ?? []
}

func axRole(_ element: AXUIElement) -> String? {
    axValue(element, kAXRoleAttribute)
}

func axTitle(_ element: AXUIElement) -> String? {
    axValue(element, kAXTitleAttribute)
}

func axDescription(_ element: AXUIElement) -> String? {
    axValue(element, kAXDescriptionAttribute)
}

func axValue_(_ element: AXUIElement) -> String? {
    axValue(element, kAXValueAttribute)
}

func axLabel(_ element: AXUIElement) -> String {
    axTitle(element) ?? axDescription(element) ?? axValue_(element) ?? ""
}

func axPosition(_ element: AXUIElement) -> CGPoint? {
    var value: AnyObject?
    guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &value) == .success,
          let v = value else { return nil }
    var point = CGPoint.zero
    AXValueGetValue(v as! AXValue, .cgPoint, &point)
    return point
}

func axSize(_ element: AXUIElement) -> CGSize? {
    var value: AnyObject?
    guard AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &value) == .success,
          let v = value else { return nil }
    var size = CGSize.zero
    AXValueGetValue(v as! AXValue, .cgSize, &size)
    return size
}

// MARK: - Tree traversal

struct ElementInfo {
    let element: AXUIElement
    let role: String
    let label: String
    let position: CGPoint?
    let size: CGSize?
    let depth: Int
}

func walkTree(_ element: AXUIElement, depth: Int = 0, maxDepth: Int = 15, results: inout [ElementInfo]) {
    guard depth <= maxDepth else { return }
    let role = axRole(element) ?? "unknown"
    let label = axLabel(element)
    let pos = axPosition(element)
    let sz = axSize(element)
    results.append(ElementInfo(element: element, role: role, label: label, position: pos, size: sz, depth: depth))
    for child in axChildren(element) {
        walkTree(child, depth: depth + 1, maxDepth: maxDepth, results: &results)
    }
}

// MARK: - Find Simulator window

func findSimulatorApp() -> AXUIElement? {
    let apps = NSWorkspace.shared.runningApplications
    guard let sim = apps.first(where: { $0.bundleIdentifier == "com.apple.iphonesimulator" }) else {
        fputs("Error: Simulator.app is not running.\n", stderr)
        return nil
    }
    return AXUIElementCreateApplication(sim.processIdentifier)
}

@discardableResult
func activateSimulator() -> Bool {
    let apps = NSWorkspace.shared.runningApplications
    guard let sim = apps.first(where: { $0.bundleIdentifier == "com.apple.iphonesimulator" }) else {
        fputs("Error: Simulator.app is not running.\n", stderr)
        return false
    }
    sim.activate()
    usleep(300_000)
    return true
}

func runAppleScript(_ source: String) -> Bool {
    var error: NSDictionary?
    let script = NSAppleScript(source: source)
    let result = script?.executeAndReturnError(&error)
    if result != nil { return true }
    if let error {
        fputs("AppleScript error: \(error)\n", stderr)
    }
    return false
}

@discardableResult
func runCommand(_ launchPath: String, _ arguments: [String]) -> (status: Int32, stdout: String, stderr: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: launchPath)
    process.arguments = arguments

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        return (1, "", "Failed to run \(launchPath): \(error)")
    }

    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
    return (
        process.terminationStatus,
        String(decoding: stdoutData, as: UTF8.self),
        String(decoding: stderrData, as: UTF8.self)
    )
}

func imageSize(at path: String) -> (width: Int, height: Int)? {
    let result = runCommand("/usr/bin/sips", ["-g", "pixelWidth", "-g", "pixelHeight", path])
    guard result.status == 0 else { return nil }

    var width: Int?
    var height: Int?
    for line in result.stdout.split(separator: "\n") {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("pixelWidth:") {
            width = Int(trimmed.replacingOccurrences(of: "pixelWidth:", with: "").trimmingCharacters(in: .whitespaces))
        }
        if trimmed.hasPrefix("pixelHeight:") {
            height = Int(trimmed.replacingOccurrences(of: "pixelHeight:", with: "").trimmingCharacters(in: .whitespaces))
        }
    }
    guard let width, let height else { return nil }
    return (width, height)
}

func captureStoreScreenshot(device: String, outputPath: String) -> Bool {
    let screenshot = runCommand("/usr/bin/xcrun", ["simctl", "io", "booted", "screenshot", outputPath])
    guard screenshot.status == 0 else {
        fputs("Error: Failed to capture screenshot.\n\(screenshot.stderr)\n", stderr)
        return false
    }

    guard let size = imageSize(at: outputPath) else {
        fputs("Error: Failed to inspect screenshot size at \(outputPath).\n", stderr)
        return false
    }

    if device.lowercased() == "ipad", size.width < size.height {
        let rotate = runCommand("/usr/bin/sips", ["-r", "270", outputPath, "--out", outputPath])
        guard rotate.status == 0 else {
            fputs("Error: Failed to rotate iPad screenshot.\n\(rotate.stderr)\n", stderr)
            return false
        }
    }

    if let normalizedSize = imageSize(at: outputPath) {
        print("Captured \(device) screenshot at \(outputPath) (\(normalizedSize.width)x\(normalizedSize.height))")
    } else {
        print("Captured \(device) screenshot at \(outputPath)")
    }
    return true
}

func setSimulatorOrientation(_ orientationItem: String) -> Bool {
    guard activateSimulator() else { return false }
    let orientationScript = """
    tell application "Simulator" to activate
    tell application "System Events"
      tell process "Simulator"
        click menu item "\(orientationItem)" of menu 1 of menu item "Orientation" of menu "Device" of menu bar 1
      end tell
    end tell
    """
    if runAppleScript(orientationScript) {
        usleep(300_000)
        return true
    }
    return false
}

func rotateSimulator(direction: String) -> Bool {
    guard activateSimulator() else { return false }
    let menuItem: String
    let keyCode: Int
    let orientationItem: String
    switch direction.lowercased() {
    case "right":
        menuItem = "Rotate Right"
        keyCode = 124
        orientationItem = "Landscape Right"
    case "left":
        menuItem = "Rotate Left"
        keyCode = 123
        orientationItem = "Landscape Left"
    default:
        fputs("Error: Unknown rotate direction \"\(direction)\". Use 'left' or 'right'.\n", stderr)
        return false
    }

    if setSimulatorOrientation(orientationItem) {
        return true
    }

    let menuScript = """
    tell application "Simulator" to activate
    tell application "System Events"
      tell process "Simulator"
        click menu item "\(menuItem)" of menu "Device" of menu bar 1
      end tell
    end tell
    """
    if runAppleScript(menuScript) {
        usleep(300_000)
        return true
    }

    let shortcutScript = """
    tell application "Simulator" to activate
    tell application "System Events"
      key code \(keyCode) using {command down}
    end tell
    """
    return runAppleScript(shortcutScript)
}

// MARK: - Commands

func describe() {
    guard let app = findSimulatorApp() else { exit(1) }
    var elements: [ElementInfo] = []
    walkTree(app, results: &elements)
    for e in elements {
        let indent = String(repeating: "  ", count: e.depth)
        let posStr: String
        if let p = e.position, let s = e.size {
            posStr = " (\(Int(p.x)),\(Int(p.y)) \(Int(s.width))x\(Int(s.height)))"
        } else {
            posStr = ""
        }
        let labelStr = e.label.isEmpty ? "" : " \"\(e.label)\""
        print("\(indent)[\(e.role)]\(labelStr)\(posStr)")
    }
}

func findElement(named name: String) -> ElementInfo? {
    guard let app = findSimulatorApp() else { return nil }
    var elements: [ElementInfo] = []
    walkTree(app, results: &elements)
    // Prefer exact match on buttons first
    if let match = elements.first(where: { $0.label == name && $0.role.contains("Button") }) {
        return match
    }
    // Then exact match on any element
    if let match = elements.first(where: { $0.label == name }) {
        return match
    }
    // Then substring match
    if let match = elements.first(where: { $0.label.contains(name) && $0.role.contains("Button") }) {
        return match
    }
    return elements.first(where: { $0.label.contains(name) })
}

func tap(name: String, quiet: Bool = false) -> Bool {
    guard let info = findElement(named: name) else {
        if !quiet {
            fputs("Error: Element \"\(name)\" not found.\n", stderr)
        }
        return false
    }
    guard let pos = info.position, let size = info.size else {
        if !quiet {
            fputs("Error: Element \"\(name)\" has no position.\n", stderr)
        }
        return false
    }
    let centerX = pos.x + size.width / 2
    let centerY = pos.y + size.height / 2
    print("Tapping \"\(info.label)\" [\(info.role)] at (\(Int(centerX)), \(Int(centerY)))")

    // Perform AX press action
    let result = AXUIElementPerformAction(info.element, kAXPressAction as CFString)
    if result == .success {
        print("OK (AXPress)")
        return true
    }

    // Fallback: click via CGEvent
    let point = CGPoint(x: centerX, y: centerY)
    let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
    let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
    mouseDown?.post(tap: .cghidEventTap)
    usleep(100_000)
    mouseUp?.post(tap: .cghidEventTap)
    print("OK (CGEvent click)")
    return true
}

func wait(name: String, timeout: Int) -> Bool {
    let deadline = Date().addingTimeInterval(Double(timeout))
    while Date() < deadline {
        if tap(name: name) { return true }
        Thread.sleep(forTimeInterval: 1.0)
    }
    fputs("Error: Timed out waiting for \"\(name)\" after \(timeout)s.\n", stderr)
    return false
}

// MARK: - CGEvent-based dialog dismissal (fallback for iPad)

/// Finds the Simulator device window bounds via CGWindowList.
func findSimulatorWindowBounds() -> CGRect? {
    guard let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
        return nil
    }
    for w in windowList {
        guard let owner = w["kCGWindowOwnerName"] as? String, owner == "Simulator",
              let bounds = w["kCGWindowBounds"] as? [String: Any],
              let width = bounds["Width"] as? CGFloat, width > 100 else { continue }
        let x = bounds["X"] as? CGFloat ?? 0
        let y = bounds["Y"] as? CGFloat ?? 0
        let height = bounds["Height"] as? CGFloat ?? 0
        return CGRect(x: x, y: y, width: width, height: height)
    }
    return nil
}

func simulatorLooksLandscape() -> Bool? {
    guard let bounds = findSimulatorWindowBounds() else { return nil }
    let titleBarH: CGFloat = 22
    let contentHeight = max(0, bounds.height - titleBarH)
    return bounds.width > contentHeight
}

func grantSimulatorPermission(service: String, bundleId: String = storeScreenshotBundleId) -> Bool {
    let grant = runCommand("/usr/bin/xcrun", ["simctl", "privacy", "booted", "grant", service, bundleId])
    if grant.status == 0 {
        return true
    }
    fputs("Warning: Failed to grant \(service) permission for \(bundleId).\n\(grant.stderr)\n", stderr)
    return false
}

func prepareStorePermissions(bundleId: String = storeScreenshotBundleId) -> Int {
    let services = ["notifications", "speech-recognition", "microphone"]
    var granted = 0
    for service in services {
        if grantSimulatorPermission(service: service, bundleId: bundleId) {
            granted += 1
        }
    }
    return granted
}

/// Clicks a point in the simulator by mapping iPad/iPhone coordinates to screen coordinates.
func clickInSimulator(simX: CGFloat, simY: CGFloat, deviceWidth: CGFloat, deviceHeight: CGFloat) -> Bool {
    guard let winBounds = findSimulatorWindowBounds() else {
        fputs("Error: Could not find Simulator window.\n", stderr)
        return false
    }
    let titleBarH: CGFloat = 22
    let scaleX = winBounds.width / deviceWidth
    let scaleY = (winBounds.height - titleBarH) / deviceHeight
    let clickX = winBounds.origin.x + simX * scaleX
    let clickY = winBounds.origin.y + titleBarH + simY * scaleY

    let point = CGPoint(x: clickX, y: clickY)
    guard let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left),
          let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left) else {
        fputs("Error: Failed to create CGEvents.\n", stderr)
        return false
    }
    mouseDown.post(tap: .cghidEventTap)
    usleep(100_000)
    mouseUp.post(tap: .cghidEventTap)
    return true
}

/// Dismisses native iOS dialogs by clicking common button positions.
/// Uses CGEvent clicks as a fallback when AX API cannot see simulator-internal UI.
/// The `labels` parameter specifies button labels to try via AX first.
/// The `buttonPositions` parameter provides (x, y) coordinates in device resolution
/// for CGEvent fallback (e.g., the "許可" / "Allow" button center).
func dismissDialogs(labels: [String], buttonPositions: [(CGFloat, CGFloat)], deviceWidth: CGFloat, deviceHeight: CGFloat, maxAttempts: Int = 5) -> Int {
    var dismissed = 0
    for _ in 0..<maxAttempts {
        var found = false
        // Try AX-based tap first
        for label in labels {
            if tap(name: label, quiet: true) {
                dismissed += 1
                found = true
                Thread.sleep(forTimeInterval: 1.0)
                break
            }
        }
        if found { continue }

        // Fallback: CGEvent click at known button positions
        // Activate Simulator first
        let apps = NSWorkspace.shared.runningApplications
        if let sim = apps.first(where: { $0.bundleIdentifier == "com.apple.iphonesimulator" }) {
            sim.activate()
            usleep(300_000)
        }

        var clicked = false
        for (bx, by) in buttonPositions {
            if clickInSimulator(simX: bx, simY: by, deviceWidth: deviceWidth, deviceHeight: deviceHeight) {
                clicked = true
                break
            }
        }
        if clicked {
            Thread.sleep(forTimeInterval: 1.0)
            // Check if something actually changed by trying again
            // If nothing happened, we're done
            dismissed += 1
        } else {
            break
        }
    }
    return dismissed
}

/// Dismiss all common iOS permission dialogs on iPad Pro 13-inch landscape
/// (2752x2064) after rotating right.
func dismissIPadDialogs() -> Int {
    // Common "許可" / "Allow" button positions for centered iOS alert dialogs
    // on iPad Pro 13-inch (M4/M5): 2752x2064 resolution.
    // Right button ("許可") center after rotate-right ≈ (1242, 1180)
    let positions: [(CGFloat, CGFloat)] = [
        (1242, 1180),  // Standard centered dialog - right button
        (1092, 1180),  // Lower dialog variant
        (1380, 1180),  // Wider system prompt variant
    ]
    return dismissDialogs(
        labels: [
            "許可",
            "Allow",
            "OK",
            "続ける",
            "Continue",
            "今はしない",
            "Not Now",
            "後で",
            "Later",
            "許可しない",
            "Don't Allow",
            "ディクテーションを有効にする",
            "Enable Dictation",
        ],
        buttonPositions: positions,
        deviceWidth: 2752,
        deviceHeight: 2064
    )
}

/// Dismiss all common iOS permission dialogs on iPhone 17 Pro (1206x2622).
func dismissIPhoneDialogs() -> Int {
    let positions: [(CGFloat, CGFloat)] = [
        (780, 1580),   // Standard centered dialog - right button
    ]
    return dismissDialogs(
        labels: ["許可", "Allow", "OK"],
        buttonPositions: positions,
        deviceWidth: 1206,
        deviceHeight: 2622
    )
}

func prepareStoreCapture(device: String) -> Bool {
    switch device.lowercased() {
    case "ipad":
        let granted = prepareStorePermissions()
        guard setSimulatorOrientation("Landscape Left") else {
            fputs("Error: Failed to set iPad simulator orientation to Landscape Left.\n", stderr)
            return false
        }
        Thread.sleep(forTimeInterval: 0.8)
        var dismissed = dismissIPadDialogs()
        Thread.sleep(forTimeInterval: 1.0)
        dismissed += dismissIPadDialogs()
        print("Prepared iPad simulator. Granted \(granted) permission(s), dismissed \(dismissed) dialog(s).")
        return true
    case "iphone":
        guard activateSimulator() else { return false }
        let granted = prepareStorePermissions()
        var dismissed = dismissIPhoneDialogs()
        Thread.sleep(forTimeInterval: 1.0)
        dismissed += dismissIPhoneDialogs()
        print("Prepared iPhone simulator. Granted \(granted) permission(s), dismissed \(dismissed) dialog(s).")
        return true
    default:
        fputs("Error: Unknown device \"\(device)\". Use 'iphone' or 'ipad'.\n", stderr)
        return false
    }
}

// MARK: - Main

let args = CommandLine.arguments
guard args.count >= 2 else {
    fputs("""
    Usage:
      swift \(args[0]) tap <label>              Tap element by label
      swift \(args[0]) describe                 List all accessible elements
      swift \(args[0]) wait <label> [sec]       Wait for element then tap (default 10s)
      swift \(args[0]) rotate <left|right>      Rotate Simulator via the Device menu
      swift \(args[0]) capture-store <device> <path>
                                               Capture a screenshot and normalize orientation
      swift \(args[0]) dismiss-dialogs <device> Dismiss native dialogs (iphone|ipad)
      swift \(args[0]) prepare-store <device>   Rotate/dismiss dialogs for store capture

    """, stderr)
    exit(2)
}

switch args[1] {
case "describe":
    describe()
case "tap":
    guard args.count >= 3 else {
        fputs("Usage: tap <label>\n", stderr)
        exit(2)
    }
    exit(tap(name: args[2]) ? 0 : 1)
case "wait":
    guard args.count >= 3 else {
        fputs("Usage: wait <label> [timeout_sec]\n", stderr)
        exit(2)
    }
    let timeout = args.count >= 4 ? (Int(args[3]) ?? 10) : 10
    exit(wait(name: args[2], timeout: timeout) ? 0 : 1)
case "rotate":
    guard args.count >= 3 else {
        fputs("Usage: rotate <left|right>\n", stderr)
        exit(2)
    }
    exit(rotateSimulator(direction: args[2]) ? 0 : 1)
case "capture-store":
    guard args.count >= 4 else {
        fputs("Usage: capture-store <iphone|ipad> <path>\n", stderr)
        exit(2)
    }
    exit(captureStoreScreenshot(device: args[2], outputPath: args[3]) ? 0 : 1)
case "dismiss-dialogs":
    guard args.count >= 3 else {
        fputs("Usage: dismiss-dialogs <iphone|ipad>\n", stderr)
        exit(2)
    }
    let device = args[2].lowercased()
    let count: Int
    switch device {
    case "ipad":
        count = dismissIPadDialogs()
    case "iphone":
        count = dismissIPhoneDialogs()
    default:
        fputs("Error: Unknown device \"\(device)\". Use 'iphone' or 'ipad'.\n", stderr)
        exit(2)
    }
    if count > 0 {
        print("Dismissed \(count) dialog(s) on \(device)")
    } else {
        print("No dialogs found on \(device)")
    }
case "prepare-store":
    guard args.count >= 3 else {
        fputs("Usage: prepare-store <iphone|ipad>\n", stderr)
        exit(2)
    }
    exit(prepareStoreCapture(device: args[2]) ? 0 : 1)
default:
    fputs("Unknown command: \(args[1])\n", stderr)
    exit(2)
}
