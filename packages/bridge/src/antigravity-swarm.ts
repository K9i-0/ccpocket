import { readFileSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

/**
 * Antigravity swarms (`/swarm`), read from the files the swarm plugin itself
 * reads. ACP reports nothing about a swarm beyond the coordinator's own tool
 * calls: not who the workers are, not what they post. See "Swarm" in
 * docs/antigravity-acp-integration.md for why these two files, and only
 * these, are read.
 */

/** `agy`'s data directory when no `--app-data-dir` is given. */
export const ANTIGRAVITY_DEFAULT_PROFILE = "antigravity-cli";

/** Tools only a swarm member has. Seeing one means the session has a swarm. */
export const SWARM_TOOL_NAMES = new Set([
  "swarm",
  "post_message",
  "read_board",
  "swarm_wait",
]);

const MEMBERS_MAX_BYTES = 1024 * 1024;
const BOARD_MAX_BYTES = 8 * 1024 * 1024;
const POST_MAX_CHARS = 20_000;
const CONVERSATION_ID_RE = /^[A-Za-z0-9][A-Za-z0-9-]{7,63}$/;

export interface SwarmMember {
  name: string;
  conversationId: string;
  role: string;
  killed: boolean;
  /** In a turn, as far as the roster knows. */
  working: boolean;
}

export interface SwarmRoster {
  title?: string;
  members: SwarmMember[];
}

export interface SwarmPost {
  seq: number;
  agent: string;
  text: string;
  time?: string;
  /** `brief` for the post `swarm add` makes of a worker's brief. */
  kind?: string;
}

/** The member a post opens by addressing (`@writer please ...`), if any. */
export function swarmPostTarget(text: string): string | undefined {
  return /^\s*@([A-Za-z0-9_-]+)/.exec(text)?.[1];
}

export function isSwarmConversationId(value: unknown): value is string {
  return typeof value === "string" && CONVERSATION_ID_RE.test(value);
}

export function antigravityAppDataDir(profile: string): string {
  return join(homedir(), ".gemini", profile);
}

/** Where the swarm a conversation coordinates keeps its roster and board. */
export function antigravitySwarmDir(
  appDataDir: string,
  sessionId: string,
): string | undefined {
  if (!isSwarmConversationId(sessionId)) return undefined;
  return join(appDataDir, "brain", sessionId, ".system_generated", "swarm");
}

function readCapped(path: string, maxBytes: number): string | undefined {
  try {
    const stat = statSync(path);
    if (!stat.isFile() || stat.size > maxBytes) return undefined;
    return readFileSync(path, "utf8");
  } catch {
    return undefined;
  }
}

/** Changes whenever either file does; `""` while there is no swarm. */
export function swarmFilesSignature(swarmDir: string): string {
  return ["members.json", "board.jsonl"]
    .map((name) => {
      try {
        const stat = statSync(join(swarmDir, name));
        return `${stat.mtimeMs}:${stat.size}`;
      } catch {
        return "";
      }
    })
    .join("|")
    .replace(/^\|$/, "");
}

export function readSwarmRoster(swarmDir: string): SwarmRoster | undefined {
  const raw = readCapped(join(swarmDir, "members.json"), MEMBERS_MAX_BYTES);
  if (raw === undefined) return undefined;
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    // Read while it was being rewritten; the next poll gets it whole.
    return undefined;
  }
  if (typeof parsed !== "object" || parsed === null) return undefined;
  const root = parsed as Record<string, unknown>;
  const rawMembers =
    typeof root.members === "object" && root.members !== null
      ? (root.members as Record<string, unknown>)
      : {};
  const members: SwarmMember[] = [];
  for (const [name, value] of Object.entries(rawMembers)) {
    if (typeof value !== "object" || value === null) continue;
    const member = value as Record<string, unknown>;
    if (!isSwarmConversationId(member.conversation_id)) continue;
    const killed = member.killed === true;
    members.push({
      name,
      conversationId: member.conversation_id,
      role: typeof member.role === "string" ? member.role : "worker",
      killed,
      working: !killed && member.wake_mode === "working",
    });
  }
  return {
    ...(typeof root.title === "string" && root.title.trim()
      ? { title: root.title.trim() }
      : {}),
    members,
  };
}

/** Board posts after `afterSeq`, oldest first. */
export function readSwarmPosts(swarmDir: string, afterSeq: number): SwarmPost[] {
  const raw = readCapped(join(swarmDir, "board.jsonl"), BOARD_MAX_BYTES);
  if (!raw) return [];
  const posts: SwarmPost[] = [];
  for (const line of raw.split("\n")) {
    if (!line.trim()) continue;
    let parsed: unknown;
    try {
      parsed = JSON.parse(line);
    } catch {
      // A line still being appended.
      continue;
    }
    if (typeof parsed !== "object" || parsed === null) continue;
    const post = parsed as Record<string, unknown>;
    if (typeof post.seq !== "number" || !Number.isInteger(post.seq)) continue;
    if (post.seq <= afterSeq) continue;
    if (typeof post.agent !== "string" || typeof post.text !== "string") continue;
    posts.push({
      seq: post.seq,
      agent: post.agent,
      text: post.text.slice(0, POST_MAX_CHARS),
      ...(typeof post.time === "string" ? { time: post.time } : {}),
      ...(typeof post.kind === "string" ? { kind: post.kind } : {}),
    });
  }
  return posts.sort((a, b) => a.seq - b.seq);
}
