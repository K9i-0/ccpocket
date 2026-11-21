import { hasGitHead } from "../../git-project-state.js";
import { resolve } from "node:path";
import { WebSocket } from "ws";
import { SdkProcess } from "../../sdk-process.js";
import type { ClientMessage } from "../../parser.js";
import {
  listWorktrees,
  removeWorktree,
  getMainBranch,
} from "../../worktree.js";
import {
  stageFiles,
  stageHunks,
  unstageFiles,
  unstageHunks,
  gitCommit,
  gitPush,
  listBranches,
  createBranch,
  checkoutBranch,
  revertFiles,
  revertHunks,
  gitFetch,
  gitPull,
  gitRemoteStatus,
  gitStatus,
} from "../../git-operations.js";
import { generateCommitMessage } from "../../git-assist.js";
import {
  getGitHubItem,
  listGitHubItems,
  toGitHubError,
} from "../../github-cli.js";
import { projectRequestMetadata } from "../shared.js";
import type { BridgeWebSocketServer } from "../../websocket.js";
import { isPathAllowed, buildPathNotAllowedError } from "../file-access.js";
import { collectImageChanges, loadDiffImageAsync } from "../git-diff.js";

export async function handleGetDiff(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "get_diff" }>,
  ws: WebSocket,
): Promise<void> {
  if (!isPathAllowed(server, msg.projectPath)) {
    server.send(ws, {
      type: "diff_result",
      ...projectRequestMetadata(msg),
      staged: msg.staged === true,
      diff: "",
      error: buildPathNotAllowedError(msg.projectPath, msg.requestId)
        .message,
      errorCode: "path_not_allowed",
    });
    return;
  }
  server.collectGitDiff(
    msg.projectPath,
    ({ diff, error }) => {
      if (error) {
        if (/not a git repository/i.test(error)) {
          server.send(ws, {
            type: "diff_result",
            ...projectRequestMetadata(msg),
            staged: msg.staged === true,
            diff: "",
            error: "This project is not a git repository",
            errorCode: "git_not_available",
          });
        } else {
          server.send(ws, {
            type: "diff_result",
            ...projectRequestMetadata(msg),
            staged: msg.staged === true,
            diff: "",
            error: `Failed to get diff: ${error}`,
          });
        }
        return;
      }
      void collectImageChanges(msg.projectPath, diff).then(
        (imageChanges) => {
          if (imageChanges.length > 0) {
            server.send(ws, {
              type: "diff_result",
              ...projectRequestMetadata(msg),
              staged: msg.staged === true,
              diff,
              hasCommits: hasGitHead(msg.projectPath),
              imageChanges,
            });
          } else {
            server.send(ws, {
              type: "diff_result",
              ...projectRequestMetadata(msg),
              staged: msg.staged === true,
              diff,
              hasCommits: hasGitHead(msg.projectPath),
            });
          }
        },
      );
    },
    msg.staged === true
      ? { staged: true }
      : msg.staged === false
        ? { unstaged: true }
        : undefined,
  );
}

export async function handleGetDiffImage(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "get_diff_image" }>,
  ws: WebSocket,
): Promise<void> {
  if (
    !isPathAllowed(server, msg.projectPath) ||
    !isPathAllowed(server, resolve(msg.projectPath, msg.filePath))
  ) {
    server.send(ws, {
      type: "diff_image_result",
      ...projectRequestMetadata(msg),
      filePath: msg.filePath,
      version: msg.version,
      error: "Path not allowed",
    });
    return;
  }
  if (msg.version === "both") {
    void (async () => {
      try {
        const [oldResult, newResult] = await Promise.all([
          loadDiffImageAsync(server, msg.projectPath, msg.filePath, "old"),
          loadDiffImageAsync(server, msg.projectPath, msg.filePath, "new"),
        ]);
        const errors = [oldResult.error, newResult.error].filter(Boolean);
        server.send(ws, {
          type: "diff_image_result",
          ...projectRequestMetadata(msg),
          filePath: msg.filePath,
          version: "both" as const,
          oldBase64: oldResult.base64,
          newBase64: newResult.base64,
          mimeType: oldResult.mimeType ?? newResult.mimeType,
          ...(errors.length > 0 ? { error: errors.join("; ") } : {}),
        });
      } catch {
        // WebSocket may have closed; ignore send errors.
      }
    })();
  } else {
    const version = msg.version as "old" | "new";
    void (async () => {
      try {
        const result = await loadDiffImageAsync(
          server,
          msg.projectPath,
          msg.filePath,
          version,
        );
        server.send(ws, {
          type: "diff_image_result",
          ...projectRequestMetadata(msg),
          filePath: msg.filePath,
          version,
          ...result,
        });
      } catch {
        // WebSocket may have closed; ignore send errors.
      }
    })();
  }
}

export async function handleListWorktrees(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "list_worktrees" }>,
  ws: WebSocket,
): Promise<void> {
  if (!isPathAllowed(server, msg.projectPath)) {
    server.send(ws, {
      type: "worktree_list",
      ...projectRequestMetadata(msg),
      worktrees: [],
      error: buildPathNotAllowedError(msg.projectPath, msg.requestId).message,
    });
    return;
  }
  try {
    const worktrees = listWorktrees(msg.projectPath);
    const mainBranch = getMainBranch(msg.projectPath);
    server.send(ws, {
      type: "worktree_list",
      ...projectRequestMetadata(msg),
      worktrees,
      mainBranch,
    });
  } catch (err) {
    server.send(ws, {
      type: "worktree_list",
      ...projectRequestMetadata(msg),
      worktrees: [],
      error: `Failed to list worktrees: ${err}`,
    });
  }
}

export async function handleRemoveWorktree(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "remove_worktree" }>,
  ws: WebSocket,
): Promise<void> {
  if (!isPathAllowed(server, msg.projectPath)) {
    server.send(ws, {
      type: "worktree_removed",
      ...projectRequestMetadata(msg),
      worktreePath: msg.worktreePath,
      error: buildPathNotAllowedError(msg.projectPath, msg.requestId).message,
    });
    return;
  }
  try {
    removeWorktree(msg.projectPath, msg.worktreePath);
    server.worktreeStore.deleteByWorktreePath(msg.worktreePath);
    server.send(ws, {
      type: "worktree_removed",
      ...projectRequestMetadata(msg),
      worktreePath: msg.worktreePath,
    });
  } catch (err) {
    server.send(ws, {
      type: "worktree_removed",
      ...projectRequestMetadata(msg),
      worktreePath: msg.worktreePath,
      error: `Failed to remove worktree: ${err}`,
    });
  }
}

export async function handleGitStage(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "git_stage" }>,
  ws: WebSocket,
): Promise<void> {
  if (!isPathAllowed(server, msg.projectPath)) {
    server.send(ws, {
      type: "git_stage_result",
      ...projectRequestMetadata(msg),
      success: false,
      error: buildPathNotAllowedError(msg.projectPath, msg.requestId).message,
    });
    return;
  }
  try {
    if (msg.files?.length) stageFiles(msg.projectPath, msg.files);
    if (msg.hunks?.length) stageHunks(msg.projectPath, msg.hunks);
    server.send(ws, {
      type: "git_stage_result",
      ...projectRequestMetadata(msg),
      success: true,
    });
  } catch (err) {
    server.send(ws, {
      type: "git_stage_result",
      ...projectRequestMetadata(msg),
      success: false,
      error: String(err),
    });
  }
}

export async function handleGitUnstage(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "git_unstage" }>,
  ws: WebSocket,
): Promise<void> {
  if (!isPathAllowed(server, msg.projectPath)) {
    server.send(ws, {
      type: "git_unstage_result",
      ...projectRequestMetadata(msg),
      success: false,
      error: buildPathNotAllowedError(msg.projectPath, msg.requestId).message,
    });
    return;
  }
  try {
    unstageFiles(msg.projectPath, msg.files ?? []);
    server.send(ws, {
      type: "git_unstage_result",
      ...projectRequestMetadata(msg),
      success: true,
    });
  } catch (err) {
    server.send(ws, {
      type: "git_unstage_result",
      ...projectRequestMetadata(msg),
      success: false,
      error: String(err),
    });
  }
}

export async function handleGitUnstageHunks(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "git_unstage_hunks" }>,
  ws: WebSocket,
): Promise<void> {
  if (!isPathAllowed(server, msg.projectPath)) {
    server.send(ws, {
      type: "git_unstage_hunks_result",
      ...projectRequestMetadata(msg),
      success: false,
      error: buildPathNotAllowedError(msg.projectPath, msg.requestId).message,
    });
    return;
  }
  try {
    unstageHunks(msg.projectPath, msg.hunks);
    server.send(ws, {
      type: "git_unstage_hunks_result",
      ...projectRequestMetadata(msg),
      success: true,
    });
  } catch (err) {
    server.send(ws, {
      type: "git_unstage_hunks_result",
      ...projectRequestMetadata(msg),
      success: false,
      error: String(err),
    });
  }
}

export async function handleGitCommit(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "git_commit" }>,
  ws: WebSocket,
): Promise<void> {
  if (!isPathAllowed(server, msg.projectPath)) {
    server.send(ws, {
      type: "git_commit_result",
      ...projectRequestMetadata(msg),
      success: false,
      error: buildPathNotAllowedError(msg.projectPath, msg.requestId).message,
    });
    return;
  }
  const session = msg.sessionId
    ? server.sessionManager.get(msg.sessionId)
    : undefined;
  try {
    const message =
      msg.autoGenerate === true
        ? (() => {
            if (!msg.sessionId) {
              throw new Error(
                "git_commit with autoGenerate=true requires sessionId",
              );
            }
            if (!session) {
              throw new Error(`Session ${msg.sessionId} not found`);
            }
            const expectedPath = resolve(
              session.worktreePath ?? session.projectPath,
            );
            const requestedPath = resolve(msg.projectPath);
            if (requestedPath !== expectedPath) {
              throw new Error(
                "git_commit projectPath must match the active session cwd",
              );
            }
            return generateCommitMessage({
              provider: session.provider,
              projectPath: msg.projectPath,
              model:
                session.provider === "claude"
                  ? session.process instanceof SdkProcess
                    ? session.process.model
                    : undefined
                  : session.codexSettings?.model,
            });
          })()
        : msg.message ?? "";
    const result = gitCommit(msg.projectPath, message);
    server.send(ws, {
      type: "git_commit_result",
      ...projectRequestMetadata(msg),
      success: true,
      commitHash: result.hash,
      message: result.message,
    });
  } catch (err) {
    server.send(ws, {
      type: "git_commit_result",
      ...projectRequestMetadata(msg),
      success: false,
      error: err instanceof Error ? err.message : String(err),
    });
  }
}

export async function handleGitPush(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "git_push" }>,
  ws: WebSocket,
): Promise<void> {
  if (!isPathAllowed(server, msg.projectPath)) {
    server.send(ws, {
      type: "git_push_result",
      ...projectRequestMetadata(msg),
      success: false,
      error: buildPathNotAllowedError(msg.projectPath, msg.requestId).message,
    });
    return;
  }
  try {
    gitPush(msg.projectPath);
    server.send(ws, {
      type: "git_push_result",
      ...projectRequestMetadata(msg),
      success: true,
    });
  } catch (err) {
    server.send(ws, {
      type: "git_push_result",
      ...projectRequestMetadata(msg),
      success: false,
      error: String(err),
    });
  }
}

export async function handleGitBranches(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "git_branches" }>,
  ws: WebSocket,
): Promise<void> {
  if (!isPathAllowed(server, msg.projectPath)) {
    server.send(ws, {
      type: "git_branches_result",
      ...projectRequestMetadata(msg),
      current: "",
      branches: [],
      checkedOutBranches: [],
      remoteStatusByBranch: {},
      error: buildPathNotAllowedError(msg.projectPath, msg.requestId).message,
    });
    return;
  }
  try {
    const result = listBranches(msg.projectPath);
    server.send(ws, {
      type: "git_branches_result",
      ...projectRequestMetadata(msg),
      current: result.current,
      branches: result.branches,
      checkedOutBranches: result.checkedOutBranches,
      remoteStatusByBranch: result.remoteStatusByBranch,
    });
  } catch (err) {
    server.send(ws, {
      type: "git_branches_result",
      ...projectRequestMetadata(msg),
      current: "",
      branches: [],
      remoteStatusByBranch: {},
      error: String(err),
    });
  }
}

export async function handleGitCreateBranch(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "git_create_branch" }>,
  ws: WebSocket,
): Promise<void> {
  if (!isPathAllowed(server, msg.projectPath)) {
    server.send(ws, {
      type: "git_create_branch_result",
      ...projectRequestMetadata(msg),
      success: false,
      error: buildPathNotAllowedError(msg.projectPath, msg.requestId).message,
    });
    return;
  }
  try {
    createBranch(msg.projectPath, msg.name, msg.checkout);
    server.send(ws, {
      type: "git_create_branch_result",
      ...projectRequestMetadata(msg),
      success: true,
    });
  } catch (err) {
    server.send(ws, {
      type: "git_create_branch_result",
      ...projectRequestMetadata(msg),
      success: false,
      error: String(err),
    });
  }
}

export async function handleGitCheckoutBranch(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "git_checkout_branch" }>,
  ws: WebSocket,
): Promise<void> {
  if (!isPathAllowed(server, msg.projectPath)) {
    server.send(ws, {
      type: "git_checkout_branch_result",
      ...projectRequestMetadata(msg),
      success: false,
      error: buildPathNotAllowedError(msg.projectPath, msg.requestId).message,
    });
    return;
  }
  try {
    checkoutBranch(msg.projectPath, msg.branch);
    server.send(ws, {
      type: "git_checkout_branch_result",
      ...projectRequestMetadata(msg),
      success: true,
    });
  } catch (err) {
    server.send(ws, {
      type: "git_checkout_branch_result",
      ...projectRequestMetadata(msg),
      success: false,
      error: String(err),
    });
  }
}

export async function handleGitRevertFile(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "git_revert_file" }>,
  ws: WebSocket,
): Promise<void> {
  if (!isPathAllowed(server, msg.projectPath)) {
    server.send(ws, {
      type: "git_revert_file_result",
      ...projectRequestMetadata(msg),
      success: false,
      error: buildPathNotAllowedError(msg.projectPath, msg.requestId).message,
    });
    return;
  }
  try {
    revertFiles(msg.projectPath, msg.files);
    server.send(ws, {
      type: "git_revert_file_result",
      ...projectRequestMetadata(msg),
      success: true,
    });
  } catch (err) {
    server.send(ws, {
      type: "git_revert_file_result",
      ...projectRequestMetadata(msg),
      success: false,
      error: String(err),
    });
  }
}

export async function handleGitRevertHunks(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "git_revert_hunks" }>,
  ws: WebSocket,
): Promise<void> {
  if (!isPathAllowed(server, msg.projectPath)) {
    server.send(ws, {
      type: "git_revert_hunks_result",
      ...projectRequestMetadata(msg),
      success: false,
      error: buildPathNotAllowedError(msg.projectPath, msg.requestId).message,
    });
    return;
  }
  try {
    revertHunks(msg.projectPath, msg.hunks);
    server.send(ws, {
      type: "git_revert_hunks_result",
      ...projectRequestMetadata(msg),
      success: true,
    });
  } catch (err) {
    server.send(ws, {
      type: "git_revert_hunks_result",
      ...projectRequestMetadata(msg),
      success: false,
      error: String(err),
    });
  }
}

export async function handleGitFetch(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "git_fetch" }>,
  ws: WebSocket,
): Promise<void> {
  if (!isPathAllowed(server, msg.projectPath)) {
    server.send(ws, {
      type: "git_fetch_result",
      ...projectRequestMetadata(msg),
      success: false,
      error: buildPathNotAllowedError(msg.projectPath, msg.requestId).message,
    });
    return;
  }
  try {
    gitFetch(msg.projectPath);
    server.send(ws, {
      type: "git_fetch_result",
      ...projectRequestMetadata(msg),
      success: true,
    });
  } catch (err) {
    server.send(ws, {
      type: "git_fetch_result",
      ...projectRequestMetadata(msg),
      success: false,
      error: String(err),
    });
  }
}

export async function handleGitPull(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "git_pull" }>,
  ws: WebSocket,
): Promise<void> {
  if (!isPathAllowed(server, msg.projectPath)) {
    server.send(ws, {
      type: "git_pull_result",
      ...projectRequestMetadata(msg),
      success: false,
      error: buildPathNotAllowedError(msg.projectPath, msg.requestId).message,
    });
    return;
  }
  try {
    const result = gitPull(msg.projectPath);
    if (result.success) {
      server.send(ws, {
        type: "git_pull_result",
        ...projectRequestMetadata(msg),
        success: true,
        message: result.message,
      });
    } else {
      server.send(ws, {
        type: "git_pull_result",
        ...projectRequestMetadata(msg),
        success: false,
        error: result.message,
      });
    }
  } catch (err) {
    server.send(ws, {
      type: "git_pull_result",
      ...projectRequestMetadata(msg),
      success: false,
      error: String(err),
    });
  }
}

export async function handleGitStatus(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "git_status" }>,
  ws: WebSocket,
): Promise<void> {
  if (!isPathAllowed(server, msg.projectPath)) {
    server.send(ws, {
      type: "git_status_result",
      requestId: msg.requestId,
      sessionId: msg.sessionId,
      projectPath: msg.projectPath,
      hasUncommittedChanges: false,
      stagedCount: 0,
      unstagedCount: 0,
      untrackedCount: 0,
      remoteStatusIncluded: false,
      hasRemoteChanges: false,
      commitsAhead: 0,
      commitsBehind: 0,
      hasUpstream: false,
      error: `Path not allowed: ${msg.projectPath}`,
    });
    return;
  }
  try {
    const result = gitStatus(msg.projectPath, {
      includeRemote: msg.includeRemote,
    });
    server.send(ws, {
      type: "git_status_result",
      requestId: msg.requestId,
      sessionId: msg.sessionId,
      projectPath: msg.projectPath,
      hasUncommittedChanges: result.hasUncommittedChanges,
      stagedCount: result.stagedCount,
      unstagedCount: result.unstagedCount,
      untrackedCount: result.untrackedCount,
      remoteStatusIncluded: result.remoteStatusIncluded,
      hasRemoteChanges: result.hasRemoteChanges,
      commitsAhead: result.commitsAhead,
      commitsBehind: result.commitsBehind,
      hasUpstream: result.hasUpstream,
      branch: result.branch,
      remoteError: result.remoteError,
    });
  } catch (err) {
    server.send(ws, {
      type: "git_status_result",
      requestId: msg.requestId,
      sessionId: msg.sessionId,
      projectPath: msg.projectPath,
      hasUncommittedChanges: false,
      stagedCount: 0,
      unstagedCount: 0,
      untrackedCount: 0,
      remoteStatusIncluded: false,
      hasRemoteChanges: false,
      commitsAhead: 0,
      commitsBehind: 0,
      hasUpstream: false,
      error: String(err),
    });
  }
}

export async function handleGitRemoteStatus(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "git_remote_status" }>,
  ws: WebSocket,
): Promise<void> {
  if (!isPathAllowed(server, msg.projectPath)) {
    server.send(ws, {
      type: "git_remote_status_result",
      ...projectRequestMetadata(msg),
      ahead: 0,
      behind: 0,
      branch: "",
      hasUpstream: false,
      error: buildPathNotAllowedError(msg.projectPath, msg.requestId).message,
    });
    return;
  }
  try {
    const result = gitRemoteStatus(msg.projectPath);
    server.send(ws, {
      type: "git_remote_status_result",
      ...projectRequestMetadata(msg),
      ahead: result.ahead,
      behind: result.behind,
      branch: result.branch,
      hasUpstream: result.hasUpstream,
    });
  } catch (err) {
    server.send(ws, {
      type: "git_remote_status_result",
      ...projectRequestMetadata(msg),
      ahead: 0,
      behind: 0,
      branch: "",
      hasUpstream: false,
    });
  }
}

export async function handleGithubList(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "github_list" | "github_item" }>,
  ws: WebSocket,
): Promise<void> {
  // The gh CLI runs asynchronously; every outcome answers with the
  // operation-specific result so the client's pending request clears.
  const request = msg;
  const correlation =
    request.type === "github_list"
      ? {
          type: "github_list_result" as const,
          requestId: request.requestId,
          projectPath: request.projectPath,
          kind: request.kind,
        }
      : {
          type: "github_item_result" as const,
          requestId: request.requestId,
          projectPath: request.projectPath,
          kind: request.kind,
          number: request.number,
        };
  if (!isPathAllowed(server, request.projectPath)) {
    server.send(ws, {
      ...correlation,
      error: {
        code: "failed",
        message: buildPathNotAllowedError(
          request.projectPath,
          request.requestId,
        ).message,
      },
    });
    return;
  }
  void (async () => {
    try {
      if (request.type === "github_list") {
        const result = await listGitHubItems(
          request.projectPath,
          request.kind,
        );
        server.send(ws, {
          ...correlation,
          repository: result.repository,
          items: result.items,
        });
      } else {
        const result = await getGitHubItem(
          request.projectPath,
          request.kind,
          request.number,
        );
        server.send(ws, { ...correlation, item: result.item });
      }
    } catch (err) {
      server.send(ws, { ...correlation, error: toGitHubError(err) });
    }
  })();
}
