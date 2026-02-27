/**
 * sim-stream: iOS Simulator Remote Viewer (Prototype)
 *
 * アーキテクチャ:
 *   映像: screencapture -l (Window ID指定) → JPEG → HTTP MJPEG multipart
 *   入力: AXe CLI (tap/swipe/type/button)
 *
 * screencapture は macOS 標準コマンドでウィンドウ単位のキャプチャに対応。
 * 1枚 ~60ms (≈15fps) で高品質な JPEG を出力する。
 */

import { createServer } from "node:http";
import { spawn, execSync, execFileSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import { WebSocketServer } from "ws";

// --- Config ---
const PORT = parseInt(process.env.SIM_STREAM_PORT || "8100", 10);
const TARGET_FPS = parseInt(process.env.SIM_STREAM_FPS || "12", 10);
const FRAME_INTERVAL = Math.floor(1000 / TARGET_FPS);
const BOUNDARY = "--simframe";

// --- Detect booted simulator ---
function getBootedSimulator() {
  try {
    const output = execSync("xcrun simctl list devices booted -j", {
      encoding: "utf-8",
    });
    const data = JSON.parse(output);
    for (const runtime of Object.values(data.devices)) {
      for (const device of runtime) {
        if (device.state === "Booted") {
          return { name: device.name, udid: device.udid };
        }
      }
    }
  } catch (e) {
    console.error("Failed to detect simulator:", e.message);
  }
  return null;
}

// --- Get simulator window ID ---
function getSimulatorWindowId() {
  try {
    const output = execSync(
      `swift -e '
import CoreGraphics
let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as! [[String: Any]]
for w in windowList {
    if let owner = w["kCGWindowOwnerName"] as? String, owner.contains("Simulator"),
       let name = w["kCGWindowName"] as? String, !name.isEmpty {
        let id = w["kCGWindowNumber"] as? Int ?? 0
        let bounds = w["kCGWindowBounds"] as? [String: Any] ?? [:]
        let width = bounds["Width"] as? Int ?? 0
        let height = bounds["Height"] as? Int ?? 0
        print("\\(id),\\(name),\\(width),\\(height)")
        break
    }
}
'`,
      { encoding: "utf-8", timeout: 10000 }
    ).trim();

    if (output) {
      const parts = output.split(",");
      const id = parseInt(parts[0], 10);
      const name = parts[1];
      const width = parseInt(parts[2], 10);
      const height = parseInt(parts[3], 10);
      console.log(
        `Simulator window: id=${id}, name="${name}", size=${width}x${height}`
      );
      return { id, name, width, height };
    }
  } catch (e) {
    console.error("Failed to get window ID:", e.message);
  }
  return null;
}

// --- Get AXe content area size ---
function getAxeContentArea(udid) {
  try {
    const output = execSync(`axe describe-ui --udid ${udid}`, {
      encoding: "utf-8",
      timeout: 10000,
    });
    const data = JSON.parse(output);
    if (data.length > 0 && data[0].frame) {
      const { x, y, width, height } = data[0].frame;
      console.log(`AXe content area: ${width}x${height} at (${x},${y})`);
      return { x, y, width, height };
    }
  } catch (e) {
    console.error("Failed to get AXe content area:", e.message);
  }
  return null;
}

// --- Coordinate mapping ---
// screencapture outputs the full window including title bar and shadow.
// AXe expects point coordinates within the simulator content area.
// We need to map from screencapture pixels → AXe points.
function buildCoordMapper(windowBounds, axeContent, captureWidth, captureHeight) {
  // screencapture adds shadow/border around the window
  // Calculate the pixel-to-point scale
  const scaleX = captureWidth / windowBounds.width;
  const scaleY = captureHeight / windowBounds.height;

  // AXe content offset within the window (title bar etc.)
  const offsetX = (windowBounds.width - axeContent.width) / 2;
  const offsetY = windowBounds.height - axeContent.height;

  // In screencapture pixels, the content area starts at:
  const contentStartX = offsetX * scaleX;
  const contentStartY = offsetY * scaleY;
  const contentW = axeContent.width * scaleX;
  const contentH = axeContent.height * scaleY;

  console.log(`Coord mapping: offset=(${contentStartX.toFixed(0)},${contentStartY.toFixed(0)}), scale=${scaleX.toFixed(2)}x${scaleY.toFixed(2)}`);

  return {
    // Convert screencapture pixel coords → AXe point coords
    toAxe(pixelX, pixelY) {
      const x = (pixelX - contentStartX) / scaleX;
      const y = (pixelY - contentStartY) / scaleY;
      return { x: Math.round(x), y: Math.round(y) };
    },
    // Metadata for client
    meta: {
      captureWidth,
      captureHeight,
      contentStartX: Math.round(contentStartX),
      contentStartY: Math.round(contentStartY),
      contentWidth: Math.round(contentW),
      contentHeight: Math.round(contentH),
      axeWidth: axeContent.width,
      axeHeight: axeContent.height,
    },
  };
}

// --- Screencapture-based frame grabber ---
class FrameGrabber {
  constructor(windowId) {
    this.windowId = windowId;
    this.running = false;
    this.clients = new Set();
    this.latestFrame = null;
    this.frameCount = 0;
    this.startTime = Date.now();
    this.tmpPath = `/tmp/sim-stream-${process.pid}.jpg`;
  }

  start() {
    if (this.running) return;
    this.running = true;
    this.startTime = Date.now();
    this.frameCount = 0;
    console.log(`Frame grabber started (target ${TARGET_FPS}fps)`);
    this._loop();
  }

  stop() {
    this.running = false;
  }

  subscribe(res) {
    this.clients.add(res);
    // Start capturing if first client
    if (this.clients.size === 1 && !this.running) {
      this.start();
    }
    return () => {
      this.clients.delete(res);
      // Stop capturing if no clients
      if (this.clients.size === 0) {
        this.stop();
        console.log("No clients, pausing capture");
      }
    };
  }

  async _loop() {
    while (this.running) {
      const t0 = Date.now();
      try {
        this._capture();
      } catch (e) {
        // Skip frame on error
      }
      const elapsed = Date.now() - t0;
      const wait = Math.max(0, FRAME_INTERVAL - elapsed);
      if (wait > 0) {
        await new Promise((r) => setTimeout(r, wait));
      }
    }
  }

  _capture() {
    try {
      execFileSync(
        "screencapture",
        ["-l", String(this.windowId), "-t", "jpg", "-x", this.tmpPath],
        { timeout: 500 }
      );
      const frame = readFileSync(this.tmpPath);
      this.latestFrame = frame;
      this.frameCount++;

      // Log stats periodically
      if (this.frameCount % (TARGET_FPS * 10) === 0) {
        const elapsed = (Date.now() - this.startTime) / 1000;
        const actualFps = (this.frameCount / elapsed).toFixed(1);
        console.log(
          `Frames: ${this.frameCount}, FPS: ${actualFps}, Size: ${(frame.length / 1024).toFixed(0)}KB, Clients: ${this.clients.size}`
        );
      }

      // Send to all connected clients
      this._broadcast(frame);
    } catch (e) {
      // screencapture can fail if window moves/closes
    }
  }

  _broadcast(frame) {
    const header =
      `${BOUNDARY}\r\nContent-Type: image/jpeg\r\nContent-Length: ${frame.length}\r\n\r\n`;
    const headerBuf = Buffer.from(header);
    const tail = Buffer.from("\r\n");

    for (const res of this.clients) {
      try {
        res.write(headerBuf);
        res.write(frame);
        res.write(tail);
      } catch (e) {
        this.clients.delete(res);
      }
    }
  }

  getStats() {
    const elapsed = (Date.now() - this.startTime) / 1000;
    return {
      frameCount: this.frameCount,
      actualFps: elapsed > 0 ? (this.frameCount / elapsed).toFixed(1) : "0",
      clients: this.clients.size,
      running: this.running,
      frameSize: this.latestFrame
        ? `${(this.latestFrame.length / 1024).toFixed(0)}KB`
        : null,
    };
  }
}

// --- AXe input commands ---
function axeRun(args) {
  return new Promise((resolve, reject) => {
    const proc = spawn("axe", args);
    let stderr = "";
    proc.stderr.on("data", (d) => (stderr += d));
    proc.on("close", (code) => {
      if (code === 0) resolve();
      else reject(new Error(`axe ${args[0]} failed (${code}): ${stderr}`));
    });
    proc.on("error", reject);
  });
}

function axeTap(udid, x, y) {
  return axeRun(["tap", "-x", String(x), "-y", String(y), "--udid", udid]);
}

function axeSwipe(udid, startX, startY, endX, endY, duration) {
  const args = [
    "swipe",
    "--start-x", String(startX),
    "--start-y", String(startY),
    "--end-x", String(endX),
    "--end-y", String(endY),
    "--udid", udid,
  ];
  if (duration) args.push("--duration", String(duration / 1000)); // ms to seconds
  return axeRun(args);
}

function axeType(udid, text) {
  return axeRun(["type", text, "--udid", udid]);
}

function axeButton(udid, button) {
  return axeRun(["button", button, "--udid", udid]);
}

// --- HTML ---
const HTML_PAGE = `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
  <title>iOS Simulator Remote</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      background: #111;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      min-height: 100dvh;
      font-family: -apple-system, BlinkMacSystemFont, sans-serif;
      color: #fff;
      overflow: hidden;
      touch-action: none;
      -webkit-touch-callout: none;
      -webkit-user-select: none;
      user-select: none;
    }
    #hud {
      position: fixed;
      top: max(env(safe-area-inset-top, 4px), 4px);
      left: 50%; transform: translateX(-50%);
      font-size: 11px;
      padding: 2px 10px;
      border-radius: 10px;
      background: rgba(0,0,0,0.7);
      z-index: 10;
      color: #888;
      display: flex; gap: 8px;
    }
    #hud.ok .st { color: #4f4; }
    #hud.err .st { color: #f44; }
    #sim {
      position: relative;
      display: inline-block;
      border-radius: 12px;
      overflow: hidden;
      box-shadow: 0 2px 20px rgba(0,0,0,0.6);
    }
    #frame {
      display: block;
      max-height: 82dvh;
      max-width: 95vw;
      width: auto; height: auto;
    }
    #ov {
      position: absolute;
      top: 0; left: 0; right: 0; bottom: 0;
      z-index: 5;
    }
    .dot {
      position: absolute;
      width: 36px; height: 36px;
      border-radius: 50%;
      background: rgba(255,255,255,0.25);
      border: 2px solid rgba(255,255,255,0.5);
      transform: translate(-50%,-50%);
      pointer-events: none;
      animation: pop .35s ease-out forwards;
    }
    @keyframes pop {
      0% { opacity:1; transform:translate(-50%,-50%) scale(.4); }
      100% { opacity:0; transform:translate(-50%,-50%) scale(1.4); }
    }
    #bar {
      position: fixed;
      bottom: max(env(safe-area-inset-bottom, 8px), 8px);
      display: flex; gap: 6px; z-index: 10;
    }
    .b {
      padding: 7px 14px;
      background: #222; border: 1px solid #444;
      border-radius: 8px; color: #ccc; font-size: 13px;
      cursor: pointer;
      -webkit-tap-highlight-color: transparent;
    }
    .b:active { background: #444; }
  </style>
</head>
<body>
  <div id="hud"><span class="st">Connecting...</span><span class="fps"></span></div>
  <div id="sim">
    <img id="frame" alt="">
    <div id="ov"></div>
  </div>
  <div id="bar">
    <button class="b" id="bh">Home</button>
    <button class="b" id="bl">Lock</button>
  </div>
  <script>
    const img = document.getElementById('frame');
    const ov = document.getElementById('ov');
    const hud = document.getElementById('hud');
    const stEl = hud.querySelector('.st');
    const fpsEl = hud.querySelector('.fps');

    // --- Stream via fetch + ReadableStream ---
    let fpsCnt = 0, fpsStart = performance.now();

    async function startStream() {
      try {
        const res = await fetch('/stream');
        if (!res.body) throw new Error('No body');
        const reader = res.body.getReader();
        let buf = new Uint8Array(0);

        while (true) {
          const { done, value } = await reader.read();
          if (done) break;

          const next = new Uint8Array(buf.length + value.length);
          next.set(buf); next.set(value, buf.length);
          buf = next;

          // Extract JPEG frames (SOI=FFD8, EOI=FFD9)
          while (true) {
            const soi = find(buf, 0xFF, 0xD8, 0);
            if (soi === -1) { buf = new Uint8Array(0); break; }
            const eoi = find(buf, 0xFF, 0xD9, soi + 2);
            if (eoi === -1) { if (soi > 0) buf = buf.slice(soi); break; }

            const frame = buf.slice(soi, eoi + 2);
            buf = buf.slice(eoi + 2);

            const blob = new Blob([frame], { type: 'image/jpeg' });
            const url = URL.createObjectURL(blob);
            const old = img.src;
            img.src = url;
            if (old && old.startsWith('blob:')) URL.revokeObjectURL(old);

            fpsCnt++;
            const el = performance.now() - fpsStart;
            if (el > 2000) {
              fpsEl.textContent = (fpsCnt/el*1000).toFixed(1) + ' fps';
              fpsCnt = 0; fpsStart = performance.now();
            }
          }
        }
      } catch (e) {
        stEl.textContent = 'Reconnecting...';
        hud.className = 'err';
        setTimeout(startStream, 2000);
      }
    }

    function find(b, m1, m2, s) {
      for (let i = s; i < b.length - 1; i++) if (b[i]===m1 && b[i+1]===m2) return i;
      return -1;
    }
    startStream();

    // --- WebSocket ---
    let ws;
    function connectWS() {
      const p = location.protocol === 'https:' ? 'wss' : 'ws';
      ws = new WebSocket(p+'://'+location.host+'/ws');
      ws.onopen = () => { stEl.textContent='Connected'; hud.className='ok'; };
      ws.onclose = () => { stEl.textContent='Reconnecting...'; hud.className='err'; setTimeout(connectWS,2000); };
      ws.onerror = () => ws.close();
    }
    connectWS();
    function send(m) { if (ws?.readyState===1) ws.send(JSON.stringify(m)); }

    // --- Coordinate mapping ---
    // screencapture outputs at actual pixel size of the window
    // AXe expects point coordinates (not pixels)
    // On non-retina displays, pixels = points
    // The img naturalWidth/Height matches the screencapture output
    function map(cx, cy) {
      const r = img.getBoundingClientRect();
      const sx = img.naturalWidth / r.width;
      const sy = img.naturalHeight / r.height;
      return { x: Math.round((cx-r.left)*sx), y: Math.round((cy-r.top)*sy) };
    }

    function dot(cx, cy) {
      const r = img.getBoundingClientRect();
      const d = document.createElement('div');
      d.className='dot';
      d.style.left=(cx-r.left)+'px'; d.style.top=(cy-r.top)+'px';
      ov.appendChild(d); setTimeout(()=>d.remove(),350);
    }

    // --- Touch ---
    let ts=null, tt=0;
    ov.addEventListener('touchstart', e=>{
      e.preventDefault();
      const t=e.touches[0]; ts={x:t.clientX,y:t.clientY}; tt=Date.now();
    },{passive:false});
    ov.addEventListener('touchend', e=>{
      e.preventDefault();
      if(!ts) return;
      const t=e.changedTouches[0];
      const dx=t.clientX-ts.x, dy=t.clientY-ts.y, dist=Math.hypot(dx,dy);
      if(dist<15){
        const c=map(t.clientX,t.clientY); dot(t.clientX,t.clientY);
        send({type:'tap',x:c.x,y:c.y});
      } else {
        const s=map(ts.x,ts.y), en=map(t.clientX,t.clientY);
        send({type:'swipe',startX:s.x,startY:s.y,endX:en.x,endY:en.y,
              duration:Math.max(Date.now()-tt,200)});
      }
      ts=null;
    },{passive:false});

    // --- Mouse ---
    let ms=null, mt=0;
    ov.addEventListener('mousedown',e=>{ms={x:e.clientX,y:e.clientY};mt=Date.now();});
    ov.addEventListener('mouseup',e=>{
      if(!ms)return;
      const dx=e.clientX-ms.x,dy=e.clientY-ms.y;
      if(Math.hypot(dx,dy)<10){
        const c=map(e.clientX,e.clientY); dot(e.clientX,e.clientY);
        send({type:'tap',x:c.x,y:c.y});
      } else {
        const s=map(ms.x,ms.y),en=map(e.clientX,e.clientY);
        send({type:'swipe',startX:s.x,startY:s.y,endX:en.x,endY:en.y,
              duration:Math.max(Date.now()-mt,200)});
      }
      ms=null;
    });

    // --- Buttons ---
    document.getElementById('bh').onclick=()=>send({type:'button',button:'home'});
    document.getElementById('bl').onclick=()=>send({type:'button',button:'lock'});

    // --- Keyboard ---
    document.addEventListener('keydown',e=>{
      if(e.key.length===1) send({type:'type',text:e.key});
      else if(e.key==='Enter') send({type:'key',key:'return'});
      else if(e.key==='Backspace') send({type:'key',key:'delete'});
    });
  </script>
</body>
</html>`;

// --- Main ---
const sim = getBootedSimulator();
if (!sim) {
  console.error("No booted simulator found. Boot a simulator first.");
  process.exit(1);
}
console.log(`Simulator: ${sim.name} (${sim.udid})`);

const win = getSimulatorWindowId();
if (!win) {
  console.error("Could not find Simulator window.");
  process.exit(1);
}

const axeContent = getAxeContentArea(sim.udid);

// Get capture image dimensions from first screenshot
execFileSync("screencapture", ["-l", String(win.id), "-t", "jpg", "-x", "/tmp/sim-stream-init.jpg"], { timeout: 2000 });
const initCapture = execSync("sips -g pixelWidth -g pixelHeight /tmp/sim-stream-init.jpg 2>/dev/null", { encoding: "utf-8" });
const capW = parseInt(initCapture.match(/pixelWidth:\s*(\d+)/)?.[1] || "0", 10);
const capH = parseInt(initCapture.match(/pixelHeight:\s*(\d+)/)?.[1] || "0", 10);
console.log(`Capture size: ${capW}x${capH}`);

let coordMapper = null;
if (axeContent && capW && capH) {
  coordMapper = buildCoordMapper(
    { width: win.width, height: win.height },
    axeContent,
    capW,
    capH
  );
}

const grabber = new FrameGrabber(win.id);

// HTTP Server
const server = createServer((req, res) => {
  if (req.url === "/stream") {
    res.writeHead(200, {
      "Content-Type": `multipart/x-mixed-replace; boundary=${BOUNDARY}`,
      "Cache-Control": "no-cache, no-store",
      Connection: "close",
      Pragma: "no-cache",
    });
    const unsub = grabber.subscribe(res);
    req.on("close", unsub);
    return;
  }

  if (req.url === "/" || req.url === "/index.html") {
    res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
    res.end(HTML_PAGE);
    return;
  }

  if (req.url === "/status") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(
      JSON.stringify({
        simulator: sim,
        window: win,
        capture: { width: capW, height: capH },
        coordMapping: coordMapper?.meta || null,
        targetFps: TARGET_FPS,
        ...grabber.getStats(),
      })
    );
    return;
  }

  res.writeHead(404);
  res.end("Not found");
});

// WebSocket
const wss = new WebSocketServer({ noServer: true });
server.on("upgrade", (req, socket, head) => {
  if (req.url === "/ws") {
    wss.handleUpgrade(req, socket, head, (ws) => wss.emit("connection", ws));
  } else {
    socket.destroy();
  }
});

wss.on("connection", (ws) => {
  console.log("WS client connected");

  // Send coordinate mapping info to client
  if (coordMapper) {
    ws.send(JSON.stringify({ type: "coord_info", ...coordMapper.meta }));
  }

  ws.on("message", async (data) => {
    try {
      const msg = JSON.parse(data.toString());

      // Convert pixel coordinates → AXe points (server-side)
      const mapCoord = (px, py) => {
        if (coordMapper) return coordMapper.toAxe(px, py);
        return { x: px, y: py };
      };

      switch (msg.type) {
        case "tap": {
          const p = mapCoord(msg.x, msg.y);
          console.log(`Tap pixel(${msg.x},${msg.y}) → axe(${p.x},${p.y})`);
          await axeTap(sim.udid, p.x, p.y);
          break;
        }
        case "swipe": {
          const s = mapCoord(msg.startX, msg.startY);
          const e = mapCoord(msg.endX, msg.endY);
          console.log(`Swipe axe(${s.x},${s.y})→(${e.x},${e.y})`);
          await axeSwipe(sim.udid, s.x, s.y, e.x, e.y, msg.duration);
          break;
        }
        case "type":
          console.log(`Type: "${msg.text}"`);
          await axeType(sim.udid, msg.text);
          break;
        case "key":
          console.log(`Key: ${msg.key}`);
          await axeRun(["key", msg.key, "--udid", sim.udid]);
          break;
        case "button":
          console.log(`Button: ${msg.button}`);
          await axeButton(sim.udid, msg.button);
          break;
      }
    } catch (e) {
      console.error("Input error:", e.message);
    }
  });
  ws.on("close", () => console.log("WS client disconnected"));
});

server.listen(PORT, "0.0.0.0", () => {
  console.log(`\n🖥️  Simulator Stream Server`);
  console.log(`   http://localhost:${PORT}`);
  console.log(`   Target FPS: ${TARGET_FPS}`);
  console.log(`   Window: "${win.name}" (${win.width}x${win.height})`);
  console.log(`\n   📱 Open on iPhone: http://<Mac_Tailscale_IP>:${PORT}\n`);
});

// Cleanup
process.on("SIGINT", () => {
  console.log("\nShutting down...");
  grabber.stop();
  server.close();
  process.exit(0);
});
process.on("SIGTERM", () => {
  grabber.stop();
  server.close();
  process.exit(0);
});
