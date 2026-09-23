/** macOS: node --import tsx scripts/verify-finder-sandbox.mts
 * Runs the production Dart proof in an ad-hoc signed, sandboxed AOT executable.
 * Does not start/restart the production Bridge or open Finder.
 */
import assert from "node:assert/strict";
import { execFile, spawn, type ChildProcess } from "node:child_process";
import { mkdtemp, readFile, writeFile, copyFile, mkdir, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { promisify } from "node:util";
import { verifyFinderSocketProof } from "../packages/bridge/src/finder-reveal.js";

assert.equal(process.platform, "darwin", "This check requires macOS");
const run = promisify(execFile);
const root = fileURLToPath(new URL("../", import.meta.url));
const temporary = await mkdtemp(join(tmpdir(), "ccpocket-finder-sandbox-"));
const children = new Set<ChildProcess>();

async function probe(binary: string) {
  const child = spawn(binary, [], { stdio: ["pipe", "pipe", "pipe"] });
  children.add(child);
  let stderr = "";
  child.stderr.on("data", chunk => { stderr += chunk; });
  const completion = new Promise<void>((ok, fail) => {
    child.once("error", fail);
    child.once("exit", (code, signal) => {
      children.delete(child);
      if (code === 0) ok(); else fail(new Error(`Probe exited ${code}/${signal}: ${stderr}`));
    });
  });
  // Attach immediately, including if the process fails before its first output.
  void completion.catch(() => {});
  const response = await new Promise<Record<string, unknown>>((ok, fail) => {
    let output = "";
    const timeout = setTimeout(() => fail(new Error(`Probe startup timeout: ${stderr}`)), 15_000);
    completion.then(() => {
      if (!output.includes("\n")) fail(new Error(`Probe produced no response: ${stderr}`));
    }, fail).finally(() => clearTimeout(timeout));
    child.stdout.on("data", chunk => {
      output += chunk;
      const newline = output.indexOf("\n");
      if (newline < 0) return;
      clearTimeout(timeout);
      try { ok(JSON.parse(output.slice(0, newline))); } catch (error) { fail(error); }
    });
  });
  return { child, response, completion };
}

try {
  const source = join(temporary, "probe.dart");
  const binary = join(temporary, "probe");
  const withoutServer = join(temporary, "Without.app/Contents/MacOS/probe");
  const withServer = join(temporary, "With.app/Contents/MacOS/probe");
  const productionProof = pathToFileURL(resolve(root, "apps/mobile/lib/features/file_peek/finder_local_proof_io.dart")).href;
  await writeFile(source, `
import 'dart:convert';
import 'dart:io';
import ${JSON.stringify(productionProof)};
void main() async {
  try {
    final proof = await FinderLocalProof.create();
    stdout.writeln(jsonEncode({'port': proof.port, 'token': proof.token}));
    await stdin.first;
    await proof.dispose();
  } catch (error) {
    stdout.writeln(jsonEncode({'error': error.toString()}));
  }
}
`);
  await run("dart", ["compile", "exe", source, "-o", binary], { timeout: 120_000 });
  // Ad-hoc executables cannot carry restricted keychain entitlements. Keep the
  // production sandbox/network permissions; this probe never uses Keychain.
  const production = (await readFile(resolve(root, "apps/mobile/macos/Runner/Release.entitlements"), "utf8"))
    .replace(/\s*<key>keychain-access-groups<\/key>\s*<array\s*\/>/, "")
    .replaceAll("$(PRODUCT_BUNDLE_IDENTIFIER)", "com.k9i.ccpocket.finder-sandbox-probe");
  const serverEntitlement = /\s*<key>com\.apple\.security\.network\.server<\/key>\s*<true\s*\/>/;
  assert(serverEntitlement.test(production), "Release must include the server entitlement");
  for (const [destination, contents] of [
    [withoutServer, production.replace(serverEntitlement, "")],
    [withServer, production],
  ]) {
    await mkdir(resolve(destination, ".."), { recursive: true });
    await writeFile(resolve(destination, "../../Info.plist"), `<?xml version="1.0"?><plist version="1.0"><dict>
      <key>CFBundleIdentifier</key><string>com.k9i.ccpocket.finder-sandbox-probe</string>
      <key>CFBundleExecutable</key><string>probe</string>
      <key>CFBundlePackageType</key><string>APPL</string>
    </dict></plist>`);
    await copyFile(binary, destination);
    const entitlements = resolve(destination, "../../..") + ".plist";
    await writeFile(entitlements, contents);
    await run("codesign", ["--force", "--sign", "-", "--identifier",
      "com.k9i.ccpocket.finder-sandbox-probe", "--entitlements", entitlements, resolve(destination, "../../..")]);
  }

  const denied = await probe(withoutServer);
  assert.match(String(denied.response.error), /[Pp]ermitted|[Pp]ermission|denied/);
  await denied.completion;
  console.log("PASS: sandbox blocks the loopback listener without the release server entitlement");

  const allowed = await probe(withServer);
  const { port, token } = allowed.response;
  assert.equal(typeof port, "number", JSON.stringify(allowed.response));
  assert.equal(typeof token, "string");
  assert.equal(await verifyFinderSocketProof(port as number, token as string), true);
  assert.equal(await verifyFinderSocketProof(port as number, token as string), false);
  allowed.child.stdin!.end("done\n");
  await allowed.completion;
  console.log("PASS: sandboxed production Dart proof is accepted once by the production Bridge verifier");
} finally {
  for (const child of children) child.kill();
  await rm(temporary, { recursive: true, force: true });
}
