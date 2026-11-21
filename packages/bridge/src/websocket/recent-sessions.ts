import type { CodexThreadSummary } from "../codex-process.js";
import type { ClientMessage, RecentProjectFilter } from "../parser.js";
import {
  codexEntryAsThreadListShape,
  recentSessionIdentityKey,
  type SessionIndexEntry,
  type CodexSessionIndexMetadata,
  getAllRecentSessions,
  getPinnedCodexSessions,
  loadCodexSessionNames,
  listIndexedCodexThreadIds,
} from "../sessions-index.js";
import { threadTimestampToIso } from "./shared.js";
import type { AntigravityRecentSession } from "../antigravity-sessions.js";
import { recentSessionMetadataSearchField } from "../recent-session-search.js";
import { resolvePlatformPath } from "../path-utils.js";
import type { BridgeWebSocketServer } from "../websocket.js";

export function codexThreadToRecentSession(
  thread: CodexThreadSummary,
  indexed?: CodexSessionIndexMetadata,
): Record<string, unknown> {
  // thread/list only exposes a single preview blob; prefer the real
  // first/last/summary texts parsed from the rollout file so display-mode
  // switches (first prompt / last prompt / summary) show distinct content.
  return {
    sessionId: thread.id,
    provider: "codex",
    ...(thread.name ? { name: thread.name } : {}),
    ...(thread.agentNickname ? { agentNickname: thread.agentNickname } : {}),
    ...(thread.agentRole ? { agentRole: thread.agentRole } : {}),
    summary: indexed?.summary || thread.preview || undefined,
    firstPrompt: indexed?.firstPrompt || thread.preview || "",
    ...(indexed?.lastPrompt ? { lastPrompt: indexed.lastPrompt } : {}),
    created: threadTimestampToIso(thread.createdAt),
    modified: threadTimestampToIso(thread.updatedAt),
    gitBranch: thread.gitBranch ?? "",
    projectPath: thread.cwd,
    ...(indexed?.resumeCwd ? { resumeCwd: indexed.resumeCwd } : {}),
    isSidechain: false,
    ...(indexed?.codexSettings ? { codexSettings: indexed.codexSettings } : {}),
  };
}

export function recentSessionModifiedTime(session: unknown): number {
  const modified = (session as { modified?: unknown })?.modified;
  return typeof modified === "string" ? new Date(modified).getTime() || 0 : 0;
}

export function recentSessionDedupeKey(session: unknown, fallbackIndex: number): string {
  const value = session as { provider?: unknown; sessionId?: unknown };
  return typeof value.provider === "string" && typeof value.sessionId === "string"
    ? `${value.provider}:${value.sessionId}`
    : `unknown:${fallbackIndex}`;
}

export type ListRecentSessionsMessage = Extract<
  ClientMessage,
  { type: "list_recent_sessions" }
>;

export interface RecentSessionsListing {
  sessions: unknown[];
  hasMore: boolean;
  /**
   * Requested pinned sessions that match the listing filters, independent of
   * pagination. Only set for first-page list requests that sent pins.
   */
  pinnedSessions?: unknown[];
}

/**
 * Provider-qualified keys of the pinned sessions a request asks for, or
 * undefined when pinned sessions must not be resolved for this request
 * (project-scoped pages, later pages, or no pins sent).
 */
export function pinnedSessionKeysForRecentRequest(
  msg: ListRecentSessionsMessage,
): Set<string> | undefined {
  // With pinnedOnly the page itself already contains every pinned session.
  if (msg.pinnedOnly === true) return undefined;
  if (msg.requestScope === "project") return undefined;
  if ((msg.offset ?? 0) !== 0) return undefined;
  const pinned = msg.pinnedSessions;
  if (!pinned || pinned.length === 0) return undefined;
  return new Set(
    pinned
      .filter((pin) => !msg.provider || pin.provider === msg.provider)
      .map((pin) => recentSessionIdentityKey(pin.provider, pin.sessionId)),
  );
}

/**
 * Keys of `pinnedSessions` that define the result set of a `pinnedOnly`
 * request (any scope / offset), or undefined when `pinnedOnly` is not set.
 */
export function pinnedOnlySessionKeys(
  msg: ListRecentSessionsMessage,
): Set<string> | undefined {
  if (msg.pinnedOnly !== true) return undefined;
  return new Set(
    (msg.pinnedSessions ?? [])
      .filter((pin) => !msg.provider || pin.provider === msg.provider)
      .map((pin) => recentSessionIdentityKey(pin.provider, pin.sessionId)),
  );
}

/**
 * In-flight coalescing key of a `list_recent_sessions` request. Includes every
 * field that changes the result (pins only where they are used).
 */
export function recentSessionsCoalescingKey(
  msg: ListRecentSessionsMessage,
): string {
  const pinnedKeys = pinnedSessionKeysForRecentRequest(msg);
  const pinnedOnlyKeys = pinnedOnlySessionKeys(msg);
  const sortedFilters = (filters: RecentProjectFilter[] | undefined) =>
    filters
      ? filters
          .map((filter) =>
            JSON.stringify([
              filter.projectPath ?? null,
              filter.projectId ?? null,
              filter.workspaceKind ?? null,
            ]),
          )
          .sort()
      : null;
  return JSON.stringify({
    limit: msg.limit ?? null,
    offset: msg.offset ?? null,
    projectPath: msg.projectPath ?? null,
    projectId: msg.projectId ?? null,
    workspaceKind: msg.workspaceKind ?? null,
    requestScope: msg.requestScope ?? null,
    provider: msg.provider ?? null,
    includeAntigravity: msg.includeAntigravity ?? null,
    namedOnly: msg.namedOnly ?? null,
    searchQuery: msg.searchQuery ?? null,
    searchContent: msg.searchContent ?? null,
    pinnedSessions: pinnedKeys ? [...pinnedKeys].sort() : null,
    projectFilters: sortedFilters(msg.projectFilters),
    modifiedAfter: msg.modifiedAfter ?? null,
    modifiedBefore: msg.modifiedBefore ?? null,
    dateField: msg.dateField ?? null,
    pinnedOnly: msg.pinnedOnly ?? null,
    pinnedOnlySessions: pinnedOnlyKeys ? [...pinnedOnlyKeys].sort() : null,
    pinnedProjects: msg.pinnedOnly ? sortedFilters(msg.pinnedProjects) : null,
  });
}

/** Content (transcript) search requested with a non-empty query. */
export function isRecentContentSearch(msg: ListRecentSessionsMessage): boolean {
  return msg.searchContent === true && Boolean(msg.searchQuery?.trim());
}

/** `projectFilters` apply to list requests only (project scope replaces them). */
export function effectiveRecentProjectFilters(
  msg: ListRecentSessionsMessage,
): RecentProjectFilter[] | undefined {
  return msg.requestScope !== "project" && (msg.projectFilters?.length ?? 0) > 0
    ? msg.projectFilters
    : undefined;
}

/**
 * Whether the request uses any `recent_sessions_filters_v1` filter, which
 * routes it through the predicate-based listing path.
 */
export function recentSessionsFiltersRequested(
  msg: ListRecentSessionsMessage,
): boolean {
  return (
    effectiveRecentProjectFilters(msg) !== undefined ||
    msg.modifiedAfter !== undefined ||
    msg.modifiedBefore !== undefined ||
    msg.pinnedOnly === true ||
    // Keyword searches, single projects and named only too: app-server
    // `thread/list` paging / searchTerm took seconds, while the index plus the
    // Codex thread snapshot answers in tens of milliseconds.
    Boolean(msg.searchQuery?.trim()) ||
    msg.projectPath !== undefined ||
    msg.projectId !== undefined ||
    msg.workspaceKind !== undefined ||
    msg.namedOnly === true ||
    isRecentContentSearch(msg)
  );
}

export function recentDateBound(value: string | undefined): number | undefined {
  if (value === undefined) return undefined;
  const time = Date.parse(value);
  return Number.isFinite(time) ? time : undefined;
}

/**
 * Predicate over (workspace-enriched) recent sessions combining, with AND:
 * the single project fields, `projectFilters` (OR), the date range and
 * `pinnedOnly` (pinned session keys OR any `pinnedProjects` entry).
 */
export function buildRecentSessionPredicate(
  msg: ListRecentSessionsMessage,
  listProjects: () => ReadonlyArray<{ id: string; rootPaths: readonly string[] }>,
  pinnedKeys?: ReadonlySet<string>,
): (session: unknown) => boolean {
  type Probe = {
    provider?: unknown;
    sessionId?: unknown;
    projectPath?: unknown;
    created?: unknown;
    modified?: unknown;
    workspace?: Record<string, unknown>;
  };
  const projectMatcher = (filter: RecentProjectFilter) => {
    const primaryProjectIds = new Set(
      filter.projectPath === undefined
        ? []
        : listProjects()
            .filter((project) => project.rootPaths[0] === filter.projectPath)
            .map((project) => project.id),
    );
    return (value: Probe): boolean => {
      const workspace = value.workspace;
      if (filter.projectId && workspace?.projectId !== filter.projectId) {
        return false;
      }
      if (filter.workspaceKind && workspace?.kind !== filter.workspaceKind) {
        return false;
      }
      if (filter.projectPath !== undefined) {
        const matchesPrimaryProject =
          typeof workspace?.projectId === "string" &&
          primaryProjectIds.has(workspace.projectId);
        if (value.projectPath !== filter.projectPath && !matchesPrimaryProject) {
          return false;
        }
      }
      return true;
    };
  };
  const matchesScope = projectMatcher({
    projectPath: msg.projectPath,
    projectId: msg.projectId,
    workspaceKind: msg.workspaceKind,
  });
  const projectFilterMatchers =
    effectiveRecentProjectFilters(msg)?.map(projectMatcher);
  const pinnedProjectMatchers =
    msg.pinnedOnly === true
      ? (msg.pinnedProjects ?? []).map(projectMatcher)
      : undefined;
  const after = recentDateBound(msg.modifiedAfter);
  const before = recentDateBound(msg.modifiedBefore);
  const dateField = msg.dateField === "created" ? "created" : "modified";

  return (session: unknown): boolean => {
    const value = (session ?? {}) as Probe;
    if (!matchesScope(value)) return false;
    if (
      projectFilterMatchers &&
      !projectFilterMatchers.some((matches) => matches(value))
    ) {
      return false;
    }
    if (after !== undefined || before !== undefined) {
      const raw = value[dateField];
      const time = typeof raw === "string" ? Date.parse(raw) : Number.NaN;
      if (!Number.isFinite(time)) return false;
      if (after !== undefined && time < after) return false;
      if (before !== undefined && time >= before) return false;
    }
    if (pinnedProjectMatchers) {
      const pinned =
        typeof value.provider === "string" &&
        typeof value.sessionId === "string" &&
        (pinnedKeys?.has(
          recentSessionIdentityKey(value.provider, value.sessionId),
        ) ??
          false);
      if (!pinned && !pinnedProjectMatchers.some((matches) => matches(value))) {
        return false;
      }
    }
    return true;
  };
}

/**
 * Pinned entries from the rollout/index scan, shaped like the page entries the
 * app-server `thread/list` listing produces for Codex.
 */
export function pinnedIndexEntriesAsListingShape(
  entries: readonly SessionIndexEntry[] | undefined,
): SessionIndexEntry[] | undefined {
  return entries?.map((entry) =>
    entry.provider === "codex" ? codexEntryAsThreadListShape(entry) : entry,
  );
}

export function mergeRecentSessionPages(sessions: unknown[]): unknown[] {
  const seen = new Set<string>();
  const merged: unknown[] = [];
  for (const session of sessions) {
    const key = recentSessionDedupeKey(session, merged.length);
    if (seen.has(key)) continue;
    seen.add(key);
    merged.push(session);
  }
  return merged.sort(
    (a, b) => recentSessionModifiedTime(b) - recentSessionModifiedTime(a),
  );
}

export async function listFilteredAntigravitySessions(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "list_recent_sessions" }>,
): Promise<{ sessions: unknown[]; pinnedSessions?: unknown[] }> {
  const pinnedKeys = pinnedSessionKeysForRecentRequest(msg);
  const pinnedOnlyKeys = pinnedOnlySessionKeys(msg);
  if (
    pinnedOnlyKeys &&
    pinnedOnlyKeys.size === 0 &&
    (msg.pinnedProjects?.length ?? 0) === 0
  ) {
    return { sessions: [] };
  }
  const normalizedMsg = msg.projectPath
    ? {
        ...msg,
        projectPath: resolvePlatformPath(msg.projectPath, server.platform),
      }
    : msg;
  const raw = await server.listRecentAntigravitySessions(normalizedMsg);
  const enriched = raw.map((session) =>
    enrichRecentSessionWorkspace(server, session),
  );
  const matches = buildRecentSessionPredicate(
    normalizedMsg,
    () => server.workspaceStore?.listProjects() ?? [],
    pinnedOnlyKeys,
  );
  const filtered = enriched.filter((session) => {
    if (!matches(session)) return false;
    if (normalizedMsg.namedOnly) {
      const id = (session as AntigravityRecentSession).sessionId;
      if (!server.antigravityStore.get(id)?.name?.trim()) return false;
    }
    return true;
  });
  const pinnedSessions = pinnedKeys
    ? filtered.filter((session) =>
        pinnedKeys.has(
          recentSessionIdentityKey(
            "antigravity",
            (session as AntigravityRecentSession).sessionId,
          ),
        ),
      )
    : undefined;
  return {
    sessions: filtered,
    ...(pinnedSessions ? { pinnedSessions } : {}),
  };
}

/**
 * Resolve pinned Codex threads for a listing backed by app-server
 * `thread/list`. Parses only the pinned rollout files instead of paging the
 * whole thread list, and never fails the page itself.
 */
export async function listPinnedCodexSessions(
  server: BridgeWebSocketServer,
  msg: ListRecentSessionsMessage,
  pinnedKeys: ReadonlySet<string>,
  matchesWorkspace?: (session: unknown) => boolean,
): Promise<unknown[]> {
  const threadIds = (msg.pinnedSessions ?? [])
    .filter(
      (pin) =>
        pin.provider === "codex" &&
        pinnedKeys.has(recentSessionIdentityKey(pin.provider, pin.sessionId)),
    )
    .map((pin) => pin.sessionId);
  if (threadIds.length === 0) return [];
  try {
    const entries = await getPinnedCodexSessions({
      threadIds,
      // The workspace-filtered listing does not pre-filter thread/list by cwd.
      projectPath: matchesWorkspace ? undefined : msg.projectPath,
      namedOnly: msg.namedOnly,
      searchQuery: msg.searchQuery,
      archivedSessionIds: server.archiveStore.archivedIds(),
      sessionFilter: matchesWorkspace
        ? (session) =>
            matchesWorkspace(enrichRecentSessionWorkspace(server, session))
        : undefined,
    });
    return entries.map((entry) => enrichRecentSessionWorkspace(server, entry));
  } catch (err) {
    console.warn(`[ws] Failed to resolve pinned Codex sessions: ${err}`);
    return [];
  }
}

/**
 * Codex threads from the app-server snapshot that the index cannot see
 * (only compressed `.jsonl.zst` rollouts), filtered like index entries.
 * Their search covers metadata only (name, preview, folder, branch).
 * `pinnedSessions` lists matching pinned threads regardless of [limit].
 */
export async function listSnapshotOnlyCodexSessions(
  server: BridgeWebSocketServer,
  msg: ListRecentSessionsMessage,
  matchesWorkspace: (session: unknown) => boolean,
  limit: number,
  pinnedKeys?: ReadonlySet<string>,
): Promise<{ sessions: unknown[]; pinnedSessions: unknown[] }> {
  if (msg.provider === "claude") return { sessions: [], pinnedSessions: [] };
  // Never wait for the first snapshot load (10-20 s on large histories,
  // longer than the app's request timeout): answer from the index alone
  // until it is ready.
  if (!server.codexThreadSnapshot.isReady) {
    server.codexThreadSnapshot.warm();
    return { sessions: [], pinnedSessions: [] };
  }
  const [threads, indexedIds, names] = await Promise.all([
    server.codexThreadSnapshot.get(),
    listIndexedCodexThreadIds(),
    loadCodexSessionNames(),
  ]);
  const archivedIds = server.archiveStore.archivedIds();
  const query = msg.searchQuery?.trim() ? msg.searchQuery : undefined;
  const sessions: unknown[] = [];
  const pinnedSessions: unknown[] = [];
  for (const thread of threads) {
    if (indexedIds.has(thread.id.toLowerCase())) continue;
    if (archivedIds.has(thread.id)) continue;
    const name = names.get(thread.id) ?? thread.name ?? undefined;
    if (msg.namedOnly && !name) continue;
    let entry: Record<string, unknown> = {
      ...codexThreadToRecentSession(thread),
      ...(name ? { name } : {}),
    };
    if (query) {
      const field = recentSessionMetadataSearchField(
        entry as Parameters<typeof recentSessionMetadataSearchField>[0],
        query,
      );
      if (!field) continue;
      entry = { ...entry, searchMatch: { field } };
    }
    const enriched = enrichRecentSessionWorkspace(server, entry);
    if (!matchesWorkspace(enriched)) continue;
    if (pinnedKeys?.has(recentSessionIdentityKey("codex", thread.id))) {
      pinnedSessions.push(enriched);
    }
    if (sessions.length < limit) sessions.push(enriched);
  }
  return { sessions, pinnedSessions };
}

export async function listWorkspaceFilteredIndexedSessions(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "list_recent_sessions" }>,
  matchesWorkspace: (session: unknown) => boolean,
  limit: number,
  pinnedKeys?: ReadonlySet<string>,
  contentSearchMaxFiles?: number,
): Promise<{
  sessions: unknown[];
  pinnedSessions?: unknown[];
  incomplete: boolean;
  filesRead?: number;
}> {
  // Antigravity conversations carry no project assignment to filter by.
  if (msg.provider === "antigravity") {
    return { sessions: [], incomplete: false };
  }
  const result = await getAllRecentSessions({
    limit,
    offset: 0,
    // Project identity is authoritative. Do not pre-filter by the current
    // primary root: assignments may retain an older snapshot or worktree cwd.
    provider: msg.provider,
    namedOnly: msg.namedOnly,
    searchQuery: msg.searchQuery,
    ...(isRecentContentSearch(msg) ? { searchContent: true } : {}),
    ...(contentSearchMaxFiles !== undefined
      ? { contentSearchLimits: { maxFiles: contentSearchMaxFiles } }
      : {}),
    archivedSessionIds: server.archiveStore.archivedIds(),
    sessionFilter: (session) =>
      matchesWorkspace(enrichRecentSessionWorkspace(server, session)),
    pinnedSessionKeys: pinnedKeys,
  });
  const pinnedSessions = pinnedIndexEntriesAsListingShape(
    result.pinnedSessions,
  );
  return {
    sessions: result.sessions.map((session) =>
      enrichRecentSessionWorkspace(server, session),
    ),
    ...(pinnedSessions
      ? {
          pinnedSessions: pinnedSessions.map((session) =>
            enrichRecentSessionWorkspace(server, session),
          ),
        }
      : {}),
    incomplete: result.contentSearchIncomplete === true,
    ...(result.contentSearchFilesRead !== undefined
      ? { filesRead: result.contentSearchFilesRead }
      : {}),
  };
}

export async function listRecentSessionsRaw(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "list_recent_sessions" }>,
  pinnedKeys?: ReadonlySet<string>,
): Promise<RecentSessionsListing> {
  if (msg.provider === "codex") {
    return server.listRecentCodexSessions(msg, pinnedKeys);
  }

  if (!msg.provider) {
    return listRecentAllProviderSessions(server, msg, pinnedKeys);
  }

  return getAllRecentSessions({
    limit: msg.limit,
    offset: msg.offset,
    projectPath: msg.projectPath,
    // Codex and unfiltered requests returned above; Antigravity never
    // reaches this index scan.
    provider: "claude",
    namedOnly: msg.namedOnly,
    searchQuery: msg.searchQuery,
    archivedSessionIds: server.archiveStore.archivedIds(),
    pinnedSessionKeys: pinnedKeys,
  });
}

export function enrichRecentSessionWorkspace(
  server: BridgeWebSocketServer,
  session: unknown,
): unknown {
  if (!session || typeof session !== "object") return session;
  const value = session as Record<string, unknown>;
  const provider = value.provider;
  const providerSessionId = value.sessionId;
  const projectPath = value.projectPath;
  if (
    (provider !== "claude" &&
      provider !== "codex" &&
      provider !== "antigravity") ||
    typeof providerSessionId !== "string" ||
    typeof projectPath !== "string"
  ) {
    return session;
  }
  const workspace = server.workspaceStore?.resolveRecentWorkspace(
    provider,
    providerSessionId,
  );
  return {
    ...value,
    workspace: workspace ?? {
      kind: "unassigned",
      rootPaths: projectPath ? [projectPath] : [],
    },
  };
}

export async function listRecentAllProviderSessions(
  server: BridgeWebSocketServer,
  msg: Extract<ClientMessage, { type: "list_recent_sessions" }>,
  pinnedKeys?: ReadonlySet<string>,
): Promise<RecentSessionsListing> {
  const limit = msg.limit ?? 20;
  const offset = msg.offset ?? 0;
  const sourceLimit = offset + limit;

  const [scanResult, codexResult] = await Promise.all([
    getAllRecentSessions({
      limit: sourceLimit,
      offset: 0,
      projectPath: msg.projectPath,
      namedOnly: msg.namedOnly,
      searchQuery: msg.searchQuery,
      archivedSessionIds: server.archiveStore.archivedIds(),
      // Both providers are already scanned here, so pinned Codex threads
      // come from the same pass (no extra lookup).
      pinnedSessionKeys: pinnedKeys,
    }),
    server.listRecentCodexSessions({
      ...msg,
      provider: "codex",
      limit: sourceLimit,
      offset: 0,
    }),
  ]);

  const merged = mergeRecentSessionPages([
    ...codexResult.sessions,
    ...scanResult.sessions,
  ]);

  const pinnedSessions = pinnedIndexEntriesAsListingShape(
    scanResult.pinnedSessions,
  );
  return {
    sessions: merged.slice(offset, offset + limit),
    hasMore:
      merged.length > offset + limit ||
      scanResult.hasMore ||
      codexResult.hasMore,
    ...(pinnedSessions ? { pinnedSessions } : {}),
  };
}
