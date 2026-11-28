import { readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";

/**
 * Subagents a conversation starts with `invoke_subagent`, read from the files
 * `agy` keeps for them. ACP only reports the call itself, which closes the
 * moment the subagent starts: not which conversation it became, and not what
 * it sends back. See "サブエージェントの報告" in
 * docs/antigravity-acp-integration.md for why these files are read.
 */

const FILE_MAX_BYTES = 1024 * 1024;
const REPORT_MAX_CHARS = 20_000;
const SESSION_ID_RE = /^[A-Za-z0-9][A-Za-z0-9-]*$/;
const FILE_ID_RE = /^[A-Za-z0-9][A-Za-z0-9-]{7,63}$/;

export interface SubagentDescriptor {
  /** The file's id, which is the conversation id. */
  id: string;
  conversationId: string;
  /** `image-generator`, for one. */
  typeName: string;
  /** The `Role` the call gave it. */
  role: string;
  /** When the file was last written, for the order subagents started in. */
  writtenAt: number;
}

/** What a subagent sent back to the conversation that started it. */
export interface SubagentReport {
  id: string;
  /** The subagent's conversation id. */
  sender: string;
  content: string;
  time: string;
}

/** Where a conversation keeps its subagents and the messages sent to it. */
export function antigravitySubagentDir(
  appDataDir: string,
  sessionId: string,
): string | undefined {
  if (!SESSION_ID_RE.test(sessionId)) return undefined;
  return join(appDataDir, "brain", sessionId, ".system_generated");
}

/** Ids (file names without `.json`) under `subagents` or `messages`. */
export function listSubagentFileIds(
  dir: string,
  kind: "subagents" | "messages",
): string[] {
  let names: string[];
  try {
    names = readdirSync(join(dir, kind));
  } catch {
    return [];
  }
  const ids: string[] = [];
  for (const name of names) {
    if (!name.endsWith(".json")) continue;
    const id = name.slice(0, -".json".length);
    // `messages/read.json` is an index, not a message.
    if (FILE_ID_RE.test(id) && id !== "read") ids.push(id);
  }
  return ids;
}

function readRecord(path: string): Record<string, unknown> | undefined {
  try {
    const stat = statSync(path);
    if (!stat.isFile() || stat.size > FILE_MAX_BYTES) return undefined;
    const parsed: unknown = JSON.parse(readFileSync(path, "utf8"));
    return typeof parsed === "object" && parsed !== null
      ? (parsed as Record<string, unknown>)
      : undefined;
  } catch {
    // Missing, or read while it was being written; the next poll gets it whole.
    return undefined;
  }
}

export function readSubagentDescriptor(
  dir: string,
  id: string,
): SubagentDescriptor | undefined {
  const path = join(dir, "subagents", `${id}.json`);
  const root = readRecord(path);
  if (!root) return undefined;
  let writtenAt = 0;
  try {
    writtenAt = statSync(path).mtimeMs;
  } catch {
    // Gone since it was read; its place in the order is a guess.
  }
  const descriptor =
    typeof root.subagentDescriptor === "object" && root.subagentDescriptor !== null
      ? (root.subagentDescriptor as Record<string, unknown>)
      : {};
  return {
    id,
    conversationId: typeof root.conversationId === "string" ? root.conversationId : id,
    typeName: typeof descriptor.typeName === "string" ? descriptor.typeName : "",
    role: typeof descriptor.role === "string" ? descriptor.role : "",
    writtenAt,
  };
}

export function readSubagentReport(
  dir: string,
  id: string,
): SubagentReport | undefined {
  const root = readRecord(join(dir, "messages", `${id}.json`));
  if (!root) return undefined;
  if (typeof root.sender !== "string" || typeof root.content !== "string") {
    return undefined;
  }
  return {
    id,
    sender: root.sender,
    content: root.content.slice(0, REPORT_MAX_CHARS),
    time: typeof root.timestamp === "string" ? root.timestamp : "",
  };
}
