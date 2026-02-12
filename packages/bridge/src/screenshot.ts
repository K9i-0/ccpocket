/**
 * Screenshot module — macOS native screenshot capture via CLI commands.
 *
 * - `listWindows()`: Enumerate on-screen windows using CGWindowListCopyWindowInfo
 *   via Swift's CoreGraphics (Quartz PyObjC is unreliable across Python installs).
 * - `takeScreenshot()`: Capture full-screen or a specific window via `screencapture`.
 */

import { execFile } from "node:child_process";
import { tmpdir } from "node:os";
import { join } from "node:path";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface WindowBounds {
  x: number;
  y: number;
  width: number;
  height: number;
}

export interface WindowInfo {
  windowId: number;
  ownerName: string;
  windowTitle: string;
  bounds: WindowBounds;
}

export interface ScreenshotOptions {
  mode: "fullscreen" | "window";
  windowId?: number;
}

export interface ScreenshotResult {
  filePath: string;
}

// ---------------------------------------------------------------------------
// listWindows
// ---------------------------------------------------------------------------

/**
 * Swift inline script that calls CGWindowListCopyWindowInfo and outputs JSON.
 * Uses `swift -e` which is available on any macOS with Xcode CLT.
 * Python + Quartz was unreliable (PyObjC missing on non-system python installs).
 */
const LIST_WINDOWS_SWIFT = `
import CoreGraphics
import Foundation

let windowList = CGWindowListCopyWindowInfo(
    [.optionOnScreenOnly, .excludeDesktopElements],
    kCGNullWindowID
) as? [[String: Any]] ?? []

var out: [[String: Any]] = []
for w in windowList {
    guard let layer = w[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
    guard let owner = w[kCGWindowOwnerName as String] as? String, !owner.isEmpty else { continue }
    let bounds = w[kCGWindowBounds as String] as? [String: Any] ?? [:]
    let width = bounds["Width"] as? Double ?? 0
    let height = bounds["Height"] as? Double ?? 0
    if width < 50 || height < 50 { continue }
    out.append([
        "windowId": w[kCGWindowNumber as String] as? Int ?? 0,
        "ownerName": owner,
        "windowTitle": (w[kCGWindowName as String] as? String) ?? "",
        "bounds": [
            "x": (bounds["X"] as? Double ?? 0) as Any,
            "y": (bounds["Y"] as? Double ?? 0) as Any,
            "width": width as Any,
            "height": height as Any,
        ] as Any,
    ])
}
let data = try JSONSerialization.data(withJSONObject: out, options: [])
print(String(data: data, encoding: .utf8)!)
`;

export async function listWindows(): Promise<WindowInfo[]> {
  if (process.platform !== "darwin") {
    throw new Error("listWindows is only supported on macOS");
  }

  return new Promise<WindowInfo[]>((resolve, reject) => {
    execFile(
      "swift",
      ["-e", LIST_WINDOWS_SWIFT],
      { timeout: 15_000 },
      (err, stdout, stderr) => {
        if (err) {
          reject(
            new Error(
              `Failed to list windows: ${err.message}${stderr ? ` — ${stderr}` : ""}`,
            ),
          );
          return;
        }
        try {
          const windows = JSON.parse(stdout) as WindowInfo[];
          resolve(windows);
        } catch (parseErr) {
          reject(new Error(`Failed to parse window list: ${parseErr}`));
        }
      },
    );
  });
}

// ---------------------------------------------------------------------------
// takeScreenshot
// ---------------------------------------------------------------------------

export async function takeScreenshot(
  options: ScreenshotOptions,
): Promise<ScreenshotResult> {
  if (process.platform !== "darwin") {
    throw new Error("takeScreenshot is only supported on macOS");
  }

  const filePath = join(
    tmpdir(),
    `ccpocket-screenshot-${Date.now()}.png`,
  );

  const args: string[] = ["-x"]; // silent (no capture sound)

  if (options.mode === "window") {
    if (options.windowId == null) {
      throw new Error("windowId is required for window mode");
    }
    args.push("-o"); // no window shadow
    args.push("-l", String(options.windowId));
  }

  args.push("-t", "png", filePath);

  return new Promise<ScreenshotResult>((resolve, reject) => {
    execFile(
      "screencapture",
      args,
      { timeout: 10_000 },
      (err, _stdout, stderr) => {
        if (err) {
          reject(
            new Error(
              `screencapture failed: ${err.message}${stderr ? ` — ${stderr}` : ""}`,
            ),
          );
          return;
        }
        resolve({ filePath });
      },
    );
  });
}
