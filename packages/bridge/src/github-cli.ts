import { execFile } from "node:child_process";
import { stat } from "node:fs/promises";
import { normalizeRepositoryUrl } from "./repository-root.js";

// Read-only access to GitHub through the `gh` CLI on the Bridge host.
// See docs/github-triage.md for the protocol contract.

export type GitHubItemKind = "pr" | "issue";
export type GitHubChecksState = "success" | "failure" | "pending" | "none";
export type GitHubErrorCode =
  | "gh_missing"
  | "gh_unauthenticated"
  | "not_github"
  | "failed";

export interface GitHubError {
  code: GitHubErrorCode;
  message: string;
}

export interface GitHubAuthor {
  /** Login without the `app/` prefix gh adds to GitHub Apps. */
  login: string;
  isBot: boolean;
}

export interface GitHubItemSummary {
  number: number;
  title: string;
  url: string;
  author: GitHubAuthor;
  labels: string[];
  createdAt: string;
  updatedAt: string;
  /** PR only. */
  isDraft?: boolean;
  /** PR only, summarized from statusCheckRollup. */
  checks?: GitHubChecksState;
}

export interface GitHubComment {
  author: GitHubAuthor;
  body: string;
  createdAt: string;
}

export interface GitHubItemDetail extends GitHubItemSummary {
  body: string;
  /** Latest comments, oldest first. */
  comments: GitHubComment[];
}

export class GitHubCliError extends Error {
  readonly code: GitHubErrorCode;

  constructor(code: GitHubErrorCode, message: string) {
    super(message);
    this.name = "GitHubCliError";
    this.code = code;
  }
}

export const GITHUB_LIST_LIMIT = 100;
export const GITHUB_DETAIL_COMMENT_LIMIT = 20;
/** Longest body or comment sent to the client, in UTF-16 code units. */
export const GITHUB_BODY_MAX_LENGTH = 20_000;
const BODY_TRUNCATION_MARKER = "\n\n… (truncated)";

/** Pinned in `--repo` so `GH_HOST` on the host cannot redirect the call. */
const GITHUB_HOST = "github.com";
const COMMAND_TIMEOUT_MS = 20_000;
const GIT_TIMEOUT_MS = 5_000;
const MAX_BUFFER_BYTES = 32 * 1024 * 1024;
const MAX_ERROR_MESSAGE_LENGTH = 200;

const PR_SUMMARY_FIELDS =
  "number,title,author,isDraft,labels,createdAt,updatedAt,statusCheckRollup,url";
const ISSUE_SUMMARY_FIELDS = "number,title,author,labels,createdAt,updatedAt,url";

/** Failure of a spawned command, as reported by `execFile`. */
export interface CommandFailure {
  /** Exit code, or a string such as `ENOENT` when the process never ran. */
  code?: number | string | null;
  killed?: boolean;
  signal?: string | null;
  stderr?: string;
  message?: string;
}

/** Runs a command without a shell and resolves with stdout. */
export type RunCommand = (
  command: string,
  args: string[],
  options: { cwd?: string; timeoutMs: number },
) => Promise<string>;

const defaultRunCommand: RunCommand = (command, args, options) =>
  new Promise((resolve, reject) => {
    execFile(
      command,
      args,
      {
        cwd: options.cwd,
        encoding: "utf-8",
        timeout: options.timeoutMs,
        maxBuffer: MAX_BUFFER_BYTES,
        env: {
          ...process.env,
          GH_PROMPT_DISABLED: "1",
          GH_NO_UPDATE_NOTIFIER: "1",
          NO_COLOR: "1",
          // Error classification matches on git's English messages.
          LC_ALL: "C",
        },
      },
      (error, stdout, stderr) => {
        if (!error) {
          resolve(stdout);
          return;
        }
        const failure: CommandFailure = {
          code: (error as NodeJS.ErrnoException).code,
          killed: error.killed,
          signal: error.signal,
          stderr: typeof stderr === "string" ? stderr : "",
          message: error.message,
        };
        reject(failure);
      },
    );
  });

export interface GitHubCliDeps {
  run?: RunCommand;
  /** Whether the project directory exists; defaults to a filesystem check. */
  directoryExists?: (path: string) => Promise<boolean>;
}

const defaultDirectoryExists = async (path: string): Promise<boolean> => {
  try {
    return (await stat(path)).isDirectory();
  } catch {
    return false;
  }
};

// ---------------------------------------------------------------------------
// Pure helpers
// ---------------------------------------------------------------------------

/**
 * Extract `owner/name` from a git remote URL that points at github.com.
 * Returns null for other hosts and for URLs that are not a repository path.
 */
export function gitHubRepositoryFromRemoteUrl(url: string): string | null {
  const normalized = normalizeRepositoryUrl(url);
  if (!normalized) return null;
  const segments = normalized.split("/");
  if (segments.length !== 3 || segments[0] !== "github.com") return null;
  if (!segments[1] || !segments[2]) return null;
  // The normalized form lowercases GitHub paths; keep the remote's casing.
  const original = url
    .trim()
    .replace(/\/+$/, "")
    .replace(/\.git$/, "")
    .replace(/\/+$/, "")
    .split(/[/:]/);
  const name = original[original.length - 1];
  const owner = original[original.length - 2];
  if (
    owner?.toLowerCase() === segments[1] &&
    name?.toLowerCase() === segments[2]
  ) {
    return `${owner}/${name}`;
  }
  return `${segments[1]}/${segments[2]}`;
}

function asRecord(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {};
}

function asString(value: unknown): string {
  return typeof value === "string" ? value : "";
}

export function mapGitHubAuthor(raw: unknown): GitHubAuthor {
  const author = asRecord(raw);
  const rawLogin = asString(author.login);
  const isApp = rawLogin.startsWith("app/");
  const login = isApp ? rawLogin.slice("app/".length) : rawLogin;
  return {
    login,
    // Comment authors carry no `is_bot`; fall back to the login form.
    isBot: author.is_bot === true || isApp || login.endsWith("[bot]"),
  };
}

const FAILURE_CHECK_STATES = new Set([
  "FAILURE",
  "ERROR",
  "CANCELLED",
  "TIMED_OUT",
  "STARTUP_FAILURE",
]);
const SUCCESS_CHECK_STATES = new Set(["SUCCESS", "NEUTRAL", "SKIPPED"]);

/**
 * Summarize gh's `statusCheckRollup`. Check runs report `status` plus
 * `conclusion`; commit status contexts report `state`.
 */
export function summarizeStatusCheckRollup(rollup: unknown): GitHubChecksState {
  if (!Array.isArray(rollup) || rollup.length === 0) return "none";
  let pending = false;
  for (const entry of rollup) {
    const check = asRecord(entry);
    const status = asString(check.status).toUpperCase();
    const outcome = (
      asString(check.conclusion) || asString(check.state)
    ).toUpperCase();
    if (FAILURE_CHECK_STATES.has(outcome)) return "failure";
    if (status && status !== "COMPLETED") {
      pending = true;
    } else if (!SUCCESS_CHECK_STATES.has(outcome)) {
      // PENDING, EXPECTED, QUEUED and IN_PROGRESS have no result yet.
      // ACTION_REQUIRED usually means a workflow waits for a maintainer's
      // approval on an external PR. STALE and unknown values are not a
      // verdict either, so none of them may read as success or failure.
      pending = true;
    }
  }
  return pending ? "pending" : "success";
}

export function mapGitHubItemSummary(
  kind: GitHubItemKind,
  raw: unknown,
): GitHubItemSummary {
  const item = asRecord(raw);
  const labels = Array.isArray(item.labels)
    ? item.labels
        .map((label) => asString(asRecord(label).name))
        .filter((name) => name.length > 0)
    : [];
  return {
    number: typeof item.number === "number" ? item.number : 0,
    title: asString(item.title),
    url: asString(item.url),
    author: mapGitHubAuthor(item.author),
    labels,
    createdAt: asString(item.createdAt),
    updatedAt: asString(item.updatedAt),
    ...(kind === "pr"
      ? {
          isDraft: item.isDraft === true,
          checks: summarizeStatusCheckRollup(item.statusCheckRollup),
        }
      : {}),
  };
}

/** Map a `gh pr list` / `gh issue list` payload, newest first. */
export function mapGitHubItemList(
  kind: GitHubItemKind,
  raw: unknown,
): GitHubItemSummary[] {
  if (!Array.isArray(raw)) return [];
  return raw
    .map((item) => mapGitHubItemSummary(kind, item))
    .filter((item) => item.number > 0)
    .sort((a, b) => b.createdAt.localeCompare(a.createdAt))
    .slice(0, GITHUB_LIST_LIMIT);
}

/** Cap a body so one huge item cannot produce an oversized message. */
export function truncateGitHubBody(text: string): string {
  if (text.length <= GITHUB_BODY_MAX_LENGTH) return text;
  return `${text.slice(0, GITHUB_BODY_MAX_LENGTH)}${BODY_TRUNCATION_MARKER}`;
}

/** Keep the latest comments, oldest first. */
export function mapGitHubComments(raw: unknown): GitHubComment[] {
  if (!Array.isArray(raw)) return [];
  return raw
    .map((entry) => {
      const comment = asRecord(entry);
      return {
        author: mapGitHubAuthor(comment.author),
        body: truncateGitHubBody(asString(comment.body)),
        createdAt: asString(comment.createdAt),
      };
    })
    .sort((a, b) => a.createdAt.localeCompare(b.createdAt))
    .slice(-GITHUB_DETAIL_COMMENT_LIMIT);
}

export function mapGitHubItemDetail(
  kind: GitHubItemKind,
  raw: unknown,
): GitHubItemDetail {
  const item = asRecord(raw);
  return {
    ...mapGitHubItemSummary(kind, item),
    body: truncateGitHubBody(asString(item.body)),
    comments: mapGitHubComments(item.comments),
  };
}

function shortMessage(text: string, fallback: string): string {
  const line = text
    .split("\n")
    .map((part) => part.trim())
    .find((part) => part.length > 0);
  const message = line ?? fallback;
  return message.length > MAX_ERROR_MESSAGE_LENGTH
    ? `${message.slice(0, MAX_ERROR_MESSAGE_LENGTH - 1)}…`
    : message;
}

const UNAUTHENTICATED_PATTERN =
  /gh auth login|gh auth refresh|not logged in|HTTP 401|Bad credentials|authentication token/i;

/** Classify a failed `gh` invocation. */
export function classifyGhFailure(failure: CommandFailure): GitHubError {
  if (failure.code === "ENOENT") {
    return {
      code: "gh_missing",
      message: "GitHub CLI (gh) is not installed on the Bridge host.",
    };
  }
  const stderr = failure.stderr ?? "";
  // gh exits with 4 when a command needs authentication.
  if (failure.code === 4 || UNAUTHENTICATED_PATTERN.test(stderr)) {
    return {
      code: "gh_unauthenticated",
      message:
        "GitHub CLI is not authenticated on the Bridge host. Run: gh auth login",
    };
  }
  // Checked before `killed`: exceeding maxBuffer also kills the process.
  if (failure.code === "ERR_CHILD_PROCESS_STDIO_MAXBUFFER") {
    return { code: "failed", message: "GitHub CLI response was too large." };
  }
  if (failure.killed || failure.code === "ETIMEDOUT") {
    return { code: "failed", message: "GitHub CLI timed out." };
  }
  return {
    code: "failed",
    message: shortMessage(
      stderr || (failure.message ?? ""),
      "GitHub CLI failed.",
    ),
  };
}

/** Convert anything thrown by this module into a protocol error. */
export function toGitHubError(error: unknown): GitHubError {
  if (error instanceof GitHubCliError) {
    return { code: error.code, message: error.message };
  }
  return {
    code: "failed",
    message: shortMessage(
      error instanceof Error ? error.message : String(error),
      "GitHub request failed.",
    ),
  };
}

// ---------------------------------------------------------------------------
// Commands
// ---------------------------------------------------------------------------

const NO_GITHUB_REMOTE_PATTERN = /not a git repository|No such remote/i;

/** Resolve `owner/name` from the project's `origin` remote. */
export async function resolveGitHubRepository(
  projectPath: string,
  deps: GitHubCliDeps = {},
): Promise<string> {
  const run = deps.run ?? defaultRunCommand;
  let remoteUrl: string;
  try {
    remoteUrl = await run("git", ["remote", "get-url", "origin"], {
      cwd: projectPath,
      timeoutMs: GIT_TIMEOUT_MS,
    });
  } catch (error) {
    const failure = asRecord(error) as CommandFailure;
    const stderr = failure.stderr ?? "";
    if (NO_GITHUB_REMOTE_PATTERN.test(stderr)) {
      throw new GitHubCliError(
        "not_github",
        "This project has no GitHub origin remote.",
      );
    }
    // spawn reports ENOENT for a missing cwd as well as for a missing binary.
    if (failure.code === "ENOENT") {
      const exists = await (deps.directoryExists ?? defaultDirectoryExists)(
        projectPath,
      );
      throw new GitHubCliError(
        "failed",
        exists
          ? "git is not installed on the Bridge host."
          : "The project directory was not found on the Bridge host.",
      );
    }
    // e.g. "detected dubious ownership" or a permission error.
    throw new GitHubCliError(
      "failed",
      shortMessage(
        stderr || (failure.message ?? ""),
        "Failed to read the git remote.",
      ),
    );
  }
  const repository = gitHubRepositoryFromRemoteUrl(remoteUrl);
  if (!repository) {
    throw new GitHubCliError(
      "not_github",
      "The origin remote of this project is not a github.com repository.",
    );
  }
  return repository;
}

async function runGhJson(run: RunCommand, args: string[]): Promise<unknown> {
  let stdout: string;
  try {
    stdout = await run("gh", args, { timeoutMs: COMMAND_TIMEOUT_MS });
  } catch (error) {
    const classified = classifyGhFailure(asRecord(error) as CommandFailure);
    throw new GitHubCliError(classified.code, classified.message);
  }
  try {
    return JSON.parse(stdout) as unknown;
  } catch {
    throw new GitHubCliError(
      "failed",
      "GitHub CLI returned an unexpected response.",
    );
  }
}

/** List open PRs or issues of the project's repository, newest first. */
export async function listGitHubItems(
  projectPath: string,
  kind: GitHubItemKind,
  deps: GitHubCliDeps = {},
): Promise<{ repository: string; items: GitHubItemSummary[] }> {
  const run = deps.run ?? defaultRunCommand;
  const repository = await resolveGitHubRepository(projectPath, deps);
  const raw = await runGhJson(run, [
    kind,
    "list",
    "--repo",
    `${GITHUB_HOST}/${repository}`,
    "--state",
    "open",
    "--limit",
    String(GITHUB_LIST_LIMIT),
    "--json",
    kind === "pr" ? PR_SUMMARY_FIELDS : ISSUE_SUMMARY_FIELDS,
  ]);
  return { repository, items: mapGitHubItemList(kind, raw) };
}

/** Fetch one PR or issue with its body and latest comments. */
export async function getGitHubItem(
  projectPath: string,
  kind: GitHubItemKind,
  number: number,
  deps: GitHubCliDeps = {},
): Promise<{ repository: string; item: GitHubItemDetail }> {
  const run = deps.run ?? defaultRunCommand;
  const repository = await resolveGitHubRepository(projectPath, deps);
  const raw = await runGhJson(run, [
    kind,
    "view",
    String(number),
    "--repo",
    `${GITHUB_HOST}/${repository}`,
    "--json",
    `${kind === "pr" ? PR_SUMMARY_FIELDS : ISSUE_SUMMARY_FIELDS},body,comments`,
  ]);
  return { repository, item: mapGitHubItemDetail(kind, raw) };
}
