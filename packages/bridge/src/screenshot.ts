/**
 * Screenshot module — macOS native screenshot capture via CLI commands.
 *
 * - `listWindows()`: Enumerate on-screen windows using CGWindowListCopyWindowInfo
 *   via the macOS-bundled python3 + Quartz bridge.
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
 * Python one-liner that calls CGWindowListCopyWindowInfo and outputs JSON.
 * Uses /usr/bin/python3 explicitly because Homebrew python may lack Quartz.
 */
const LIST_WINDOWS_SCRIPT = `
import json, Quartz
wl = Quartz.CGWindowListCopyWindowInfo(
    Quartz.kCGWindowListOptionOnScreenOnly | Quartz.kCGWindowListExcludeDesktopElements,
    Quartz.kCGNullWindowID
)
out = []
for w in wl:
    layer = w.get("kCGWindowLayer", -1)
    owner = w.get("kCGWindowOwnerName", "")
    if layer != 0 or not owner:
        continue
    b = w.get("kCGWindowBounds", {})
    width = b.get("Width", 0)
    height = b.get("Height", 0)
    if width < 50 or height < 50:
        continue
    out.append({
        "windowId": int(w.get("kCGWindowNumber", 0)),
        "ownerName": str(owner),
        "windowTitle": str(w.get("kCGWindowName", "") or ""),
        "bounds": {
            "x": b.get("X", 0),
            "y": b.get("Y", 0),
            "width": width,
            "height": height
        }
    })
print(json.dumps(out))
`.trim();

export async function listWindows(): Promise<WindowInfo[]> {
  if (process.platform !== "darwin") {
    throw new Error("listWindows is only supported on macOS");
  }

  return new Promise<WindowInfo[]>((resolve, reject) => {
    execFile(
      "/usr/bin/python3",
      ["-c", LIST_WINDOWS_SCRIPT],
      { timeout: 5_000 },
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
