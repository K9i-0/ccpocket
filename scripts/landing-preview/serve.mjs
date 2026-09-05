// Serve only the two capture fixtures on localhost, with media range support.
import { createServer } from "node:http";
import { createReadStream, statSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(process.argv[2] || "/private/tmp/ccpocket-lp-media");
const files = new Map([
  [
    "/pocket-preview.mp4",
    { path: resolve(root, "pocket-preview.mp4"), type: "video/mp4" },
  ],
  [
    "/pocket-chime.wav",
    { path: resolve(root, "pocket-chime.wav"), type: "audio/wav" },
  ],
]);
for (const file of files.values()) file.size = statSync(file.path).size;
createServer((req, res) => {
  const file = files.get(req.url);
  if (!file || !["GET", "HEAD"].includes(req.method)) {
    res.writeHead(404).end();
    return;
  }
  let start = 0;
  let end = file.size - 1;
  const range = req.headers.range;
  if (range) {
    const match = /^bytes=(\d*)-(\d*)$/.exec(range);
    if (match && (match[1] || match[2])) {
      if (!match[1]) start = Math.max(0, file.size - Number(match[2]));
      else {
        start = Number(match[1]);
        if (match[2]) end = Math.min(end, Number(match[2]));
      }
    } else start = file.size;
    if (!Number.isSafeInteger(start) || start > end || start < 0) {
      res.writeHead(416, { "Content-Range": `bytes */${file.size}` }).end();
      return;
    }
  }
  res.writeHead(range ? 206 : 200, {
    "Content-Type": file.type,
    "Content-Length": end - start + 1,
    "Accept-Ranges": "bytes",
    ...(range ? { "Content-Range": `bytes ${start}-${end}/${file.size}` } : {}),
  });
  if (req.method === "HEAD") res.end();
  else {
    const stream = createReadStream(file.path, { start, end });
    stream.on("error", () => res.destroy());
    res.on("close", () => stream.destroy());
    stream.pipe(res);
  }
}).listen(8898, "127.0.0.1", () =>
  console.log("LP media fixtures: http://127.0.0.1:8898"),
);
