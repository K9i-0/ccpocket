// bridge-launcher: the program of the "CC Pocket Bridge" LaunchAgent.
//
// launchd starts it at login and again whenever it exits (KeepAlive). It
// checks that the Bridge can start, reports problems in
// ~/.ccpocket/launcher-status.json for the app to show, then replaces itself
// with the Bridge running on the user's Node through a login shell.
// See docs/design/local-bridge-management.md.
import Foundation

let bridgeCommand = "exec npx --yes @ccpocket/bridge@1"
let minimumNode = (major: 22, minor: 19)
/// Starts this close together mean the Bridge exits right after starting.
let quickStartWindow: TimeInterval = 45
let quickStartLimit = 4
let maxLogBytes: UInt64 = 2 * 1024 * 1024

let home = String(cString: getpwuid(getuid())!.pointee.pw_dir)
let dataDir = home + "/.ccpocket"
let logsDir = dataDir + "/logs"
let statusPath = dataDir + "/launcher-status.json"
let startsPath = dataDir + "/launcher-starts.json"
let fileManager = FileManager.default

func writeStatus(_ state: String, _ extra: [String: Any] = [:]) {
  var body: [String: Any] = [
    "state": state,
    "updatedAt": Int(Date().timeIntervalSince1970 * 1000),
    "pid": Int(getpid()),
  ]
  body.merge(extra) { _, new in new }
  guard let data = try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
  else { return }
  try? data.write(to: URL(fileURLWithPath: statusPath), options: .atomic)
}

/// Report a problem and leave; launchd starts the launcher again, so the
/// check repeats until the user has fixed it.
func waitAndExit(_ state: String, _ extra: [String: Any] = [:]) -> Never {
  writeStatus(state, extra)
  sleep(20)
  exit(0)
}

func configuredPort() -> Int {
  guard
    let data = fileManager.contents(atPath: dataDir + "/bridge-config.json"),
    let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
    let settings = json["settings"] as? [String: Any],
    let port = settings["port"] as? Int
  else { return 8765 }
  return port
}

func isPortInUse(_ port: Int) -> Bool {
  let fd = socket(AF_INET, SOCK_STREAM, 0)
  guard fd >= 0 else { return false }
  defer { close(fd) }
  var address = sockaddr_in()
  address.sin_family = sa_family_t(AF_INET)
  address.sin_port = in_port_t(port).bigEndian
  address.sin_addr.s_addr = inet_addr("127.0.0.1")
  return withUnsafePointer(to: &address) {
    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
      connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) == 0
    }
  }
}

/// `node -v` as the user's login shell sees it (mise, nvm, Homebrew, ...).
func nodeVersion() -> String? {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/bin/zsh")
  process.arguments = ["-lic", "command -v npx >/dev/null 2>&1 && node -v"]
  let pipe = Pipe()
  process.standardOutput = pipe
  process.standardError = FileHandle.nullDevice
  process.standardInput = FileHandle.nullDevice
  do { try process.run() } catch { return nil }
  let timeout = DispatchWorkItem { process.terminate() }
  DispatchQueue.global().asyncAfter(deadline: .now() + 30, execute: timeout)
  let data = pipe.fileHandleForReading.readDataToEndOfFile()
  process.waitUntilExit()
  timeout.cancel()
  guard process.terminationStatus == 0 else { return nil }
  // Shell startup files may print before the version: take the last line.
  return String(data: data, encoding: .utf8)?
    .split(whereSeparator: \.isNewline)
    .map { $0.trimmingCharacters(in: .whitespaces) }
    .last { $0.hasPrefix("v") }
}

func isSupported(_ version: String) -> Bool {
  let parts = version.dropFirst().split(separator: ".").compactMap { Int($0) }
  guard parts.count >= 2 else { return false }
  return parts[0] > minimumNode.major
    || (parts[0] == minimumNode.major && parts[1] >= minimumNode.minor)
}

/// Record this start and tell whether the Bridge keeps exiting right away.
func recordStartAndDetectCrashLoop() -> Bool {
  let now = Date().timeIntervalSince1970
  var starts: [Double] = []
  if let data = fileManager.contents(atPath: startsPath),
    let saved = try? JSONSerialization.jsonObject(with: data) as? [Double]
  {
    starts = saved.filter { now - $0 < quickStartWindow }
  }
  let looping = starts.count >= quickStartLimit - 1
  // After a safe-mode start the count begins again.
  starts = looping ? [] : starts + [now]
  if let data = try? JSONSerialization.data(withJSONObject: starts) {
    try? data.write(to: URL(fileURLWithPath: startsPath), options: .atomic)
  }
  return looping
}

func redirectOutput() {
  try? fileManager.createDirectory(atPath: logsDir, withIntermediateDirectories: true)
  let logPath = logsDir + "/bridge.log"
  if let size = (try? fileManager.attributesOfItem(atPath: logPath))?[.size] as? UInt64,
    size > maxLogBytes
  {
    try? fileManager.removeItem(atPath: logPath + ".1")
    try? fileManager.moveItem(atPath: logPath, toPath: logPath + ".1")
  }
  freopen(logPath, "a", stdout)
  freopen(logPath, "a", stderr)
  chmod(logPath, 0o600)
}

try? fileManager.createDirectory(
  atPath: dataDir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
writeStatus("starting")

let port = configuredPort()
if isPortInUse(port) {
  // Another Bridge (manual, or the `setup` service) already serves the port.
  waitAndExit("port_in_use", ["port": port])
}

guard let version = nodeVersion() else { waitAndExit("node_missing") }
guard isSupported(version) else {
  waitAndExit("node_too_old", ["nodeVersion": version])
}

let safeMode = recordStartAndDetectCrashLoop()
writeStatus("started", ["nodeVersion": version, "safeMode": safeMode, "port": port])
redirectOutput()

setenv("CCPOCKET_BRIDGE_SUPERVISED", "1", 1)
if safeMode {
  // The saved settings keep the Bridge from starting: run on defaults so the
  // app can reach it and fix them.
  setenv("CCPOCKET_BRIDGE_SAFE_MODE", "1", 1)
} else {
  unsetenv("CCPOCKET_BRIDGE_SAFE_MODE")
}

let arguments = ["zsh", "-lic", bridgeCommand]
var argv: [UnsafeMutablePointer<CChar>?] = arguments.map { strdup($0) } + [nil]
execv("/bin/zsh", &argv)
// Only reached when exec failed.
writeStatus("exec_failed", ["errno": Int(errno)])
sleep(20)
exit(1)
