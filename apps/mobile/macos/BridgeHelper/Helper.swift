// "CC Pocket Bridge" helper app.
//
// The sandboxed main app cannot register a LaunchAgent itself, so it opens
// this non-sandboxed helper bundled inside it. The helper reads the request
// the main app left in its container, registers or unregisters the agent
// bundled in the helper, writes the result to ~/.ccpocket/launcher-helper.json
// and quits. See docs/design/local-bridge-management.md.
import AppKit
import CoreGraphics
import ServiceManagement

let agentPlistName = "com.k9i.ccpocket.bridge-agent.plist"
/// Requests older than this are ignored: the helper only acts on a request
/// the main app has just written.
let maxRequestAge: TimeInterval = 30

let home = String(cString: getpwuid(getuid())!.pointee.pw_dir)

/// Bundle identifier of the app this helper is embedded in
/// (`Host.app/Contents/Helpers/CC Pocket Bridge.app`).
func hostBundleIdentifier() -> String? {
  let host = Bundle.main.bundleURL
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
  return Bundle(url: host)?.bundleIdentifier
}

func readRequest() -> (id: String, action: String)? {
  guard let hostId = hostBundleIdentifier() else { return nil }
  let path =
    "\(home)/Library/Containers/\(hostId)/Data/Library/Application Support/local-bridge-helper/request.json"
  guard
    let data = FileManager.default.contents(atPath: path),
    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
    let id = json["id"] as? String,
    let action = json["action"] as? String,
    let createdAt = json["createdAt"] as? Double,
    abs(Date().timeIntervalSince1970 - createdAt / 1000) < maxRequestAge
  else { return nil }
  return (id, action)
}

func statusName(_ status: SMAppService.Status) -> String {
  switch status {
  case .notRegistered: return "notRegistered"
  case .enabled: return "enabled"
  case .requiresApproval: return "requiresApproval"
  case .notFound: return "notFound"
  @unknown default: return "unknown"
  }
}

/// Whether the Bridge may read protected folders. macOS attributes the
/// Bridge's processes and this helper alike to the app that contains the
/// helper, so this answers for the Bridge. The attempt also makes that app
/// appear in System Settings > Privacy & Security > Full Disk Access.
func hasFullDiskAccess() -> Bool? {
  // Readable only with Full Disk Access. Not every Mac has each of them.
  let protected = [
    "/Library/Application Support/com.apple.TCC/TCC.db",
    home + "/Library/Safari",
    home + "/Library/Mail",
  ]
  for path in protected {
    let fd = open(path, O_RDONLY)
    if fd >= 0 {
      close(fd)
      return true
    }
    if errno == EPERM || errno == EACCES { return false }
  }
  return nil
}

func permissions() -> [String: Any] {
  var result: [String: Any] = ["screenCapture": CGPreflightScreenCaptureAccess()]
  if let fullDiskAccess = hasFullDiskAccess() { result["fullDiskAccess"] = fullDiskAccess }
  return result
}

func handleRequest() {
  guard let request = readRequest() else { return }
  let service = SMAppService.agent(plistName: agentPlistName)
  var result: [String: Any] = ["id": request.id, "action": request.action, "ok": true]
  do {
    switch request.action {
    case "register":
      // Registering again restarts nothing; an enabled agent stays as is.
      if service.status != .enabled { try service.register() }
    case "unregister":
      if service.status != .notRegistered { try service.unregister() }
    case "status":
      break
    case "requestScreenCapture":
      // Lists the app under Screen Recording so the user can turn it on.
      _ = CGRequestScreenCaptureAccess()
    default:
      result["ok"] = false
      result["error"] = "unknown action"
    }
  } catch {
    result["ok"] = false
    result["error"] = "\(error)"
  }
  result["status"] = statusName(service.status)
  result["permissions"] = permissions()
  result["updatedAt"] = Int(Date().timeIntervalSince1970 * 1000)

  let dir = home + "/.ccpocket"
  try? FileManager.default.createDirectory(
    atPath: dir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
  if let data = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]) {
    try? data.write(to: URL(fileURLWithPath: dir + "/launcher-helper.json"), options: .atomic)
  }
}

final class HelperDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    handleRequest()
    NSApp.terminate(nil)
  }
}

let delegate = HelperDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
