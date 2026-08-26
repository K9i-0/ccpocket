import { randomBytes } from "node:crypto";
import { chmodSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

export interface CodexAppServerAuth {
  token: string;
  tokenFilePath: string;
  cleanup(): void;
}

export function createCodexAppServerAuth(): CodexAppServerAuth {
  const directory = mkdtempSync(join(tmpdir(), "ccpocket-codex-auth-"));
  const tokenFilePath = join(directory, "capability-token");
  try {
    chmodSync(directory, 0o700);
    const token = randomBytes(32).toString("base64url");
    writeFileSync(tokenFilePath, token, { encoding: "utf8", mode: 0o600, flag: "wx" });
    chmodSync(tokenFilePath, 0o600);
    let cleaned = false;
    return {
      token,
      tokenFilePath,
      cleanup(): void {
        if (cleaned) return;
        cleaned = true;
        rmSync(directory, { recursive: true, force: true });
      },
    };
  } catch (error) {
    rmSync(directory, { recursive: true, force: true });
    throw error;
  }
}
