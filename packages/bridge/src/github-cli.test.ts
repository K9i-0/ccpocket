import { describe, expect, it, vi } from "vitest";
import {
  GITHUB_BODY_MAX_LENGTH,
  GITHUB_DETAIL_COMMENT_LIMIT,
  GitHubCliError,
  classifyGhFailure,
  getGitHubItem,
  gitHubRepositoryFromRemoteUrl,
  listGitHubItems,
  mapGitHubAuthor,
  mapGitHubComments,
  mapGitHubItemDetail,
  mapGitHubItemList,
  resolveGitHubRepository,
  summarizeStatusCheckRollup,
  toGitHubError,
  type RunCommand,
} from "./github-cli.js";

// Shapes captured from `gh pr list --json ...` / `gh issue list --json ...`.
const PR_LIST_FIXTURE = [
  {
    author: { id: "U_1", is_bot: false, login: "alex", name: "Alex" },
    createdAt: "2026-07-19T21:42:23Z",
    isDraft: true,
    labels: [
      { id: "LA_1", name: "size:M", description: "", color: "fbca04" },
      { id: "LA_2", name: "risk:high", description: "", color: "b60205" },
    ],
    number: 175,
    statusCheckRollup: [
      {
        __typename: "StatusContext",
        context: "PR Readiness",
        state: "FAILURE",
      },
      { __typename: "StatusContext", context: "CodeRabbit", state: "SUCCESS" },
    ],
    title: "Add Windows tray launcher",
    updatedAt: "2026-08-29T04:15:50Z",
    url: "https://github.com/K9i-0/ccpocket/pull/175",
  },
  {
    author: { id: "BOT_1", is_bot: true, login: "app/dependabot" },
    createdAt: "2026-11-10T01:00:00Z",
    isDraft: false,
    labels: [{ id: "LA_3", name: "dependencies" }],
    number: 330,
    statusCheckRollup: [
      {
        __typename: "CheckRun",
        name: "bridge",
        status: "COMPLETED",
        conclusion: "SUCCESS",
      },
      {
        __typename: "CheckRun",
        name: "mobile",
        status: "COMPLETED",
        conclusion: "SKIPPED",
      },
    ],
    title: "chore(deps): bump ws",
    updatedAt: "2026-11-10T01:05:00Z",
    url: "https://github.com/K9i-0/ccpocket/pull/330",
  },
];

const ISSUE_LIST_FIXTURE = [
  {
    author: { id: "U_2", is_bot: false, login: "K9i-0", name: "K9i" },
    createdAt: "2026-11-13T21:16:39Z",
    labels: [{ id: "LA_3", name: "dependencies" }],
    number: 329,
    title: "Older issue",
    updatedAt: "2026-11-13T21:16:39Z",
    url: "https://github.com/K9i-0/ccpocket/issues/329",
  },
  {
    author: { id: "U_2", is_bot: false, login: "K9i-0", name: "K9i" },
    createdAt: "2026-11-13T21:16:41Z",
    labels: [],
    number: 331,
    title: "Newer issue",
    updatedAt: "2026-11-13T21:16:41Z",
    url: "https://github.com/K9i-0/ccpocket/issues/331",
  },
];

function comment(index: number) {
  return {
    id: `IC_${index}`,
    author: { login: index % 2 === 0 ? "github-actions" : "alex" },
    authorAssociation: "NONE",
    body: `comment ${index}`,
    createdAt: new Date(Date.UTC(2026, 0, 1, 0, index)).toISOString(),
  };
}

describe("gitHubRepositoryFromRemoteUrl", () => {
  it.each([
    ["https://github.com/K9i-0/ccpocket.git", "K9i-0/ccpocket"],
    ["https://github.com/K9i-0/ccpocket", "K9i-0/ccpocket"],
    ["git@github.com:K9i-0/ccpocket.git\n", "K9i-0/ccpocket"],
    ["ssh://git@github.com/K9i-0/ccpocket.git", "K9i-0/ccpocket"],
    ["https://token@GitHub.com/K9i-0/ccpocket/", "K9i-0/ccpocket"],
  ])("extracts owner/name from %s", (url, expected) => {
    expect(gitHubRepositoryFromRemoteUrl(url)).toBe(expected);
  });

  it.each([
    "https://gitlab.com/owner/repo.git",
    "git@bitbucket.org:owner/repo.git",
    "https://github.example.com/owner/repo.git",
    "https://github.com/owner",
    "https://github.com/owner/repo/extra",
    "/local/path/repo.git",
    "",
  ])("returns null for %s", (url) => {
    expect(gitHubRepositoryFromRemoteUrl(url)).toBeNull();
  });
});

describe("mapGitHubAuthor", () => {
  it("strips the app/ prefix and marks bots", () => {
    expect(mapGitHubAuthor({ login: "app/dependabot", is_bot: true })).toEqual({
      login: "dependabot",
      isBot: true,
    });
  });

  it("keeps human authors as is", () => {
    expect(mapGitHubAuthor({ login: "alex", is_bot: false })).toEqual({
      login: "alex",
      isBot: false,
    });
  });

  it("falls back to an empty login for a deleted author", () => {
    expect(mapGitHubAuthor(null)).toEqual({ login: "", isBot: false });
  });
});

describe("summarizeStatusCheckRollup", () => {
  it("returns none for an empty or missing rollup", () => {
    expect(summarizeStatusCheckRollup([])).toBe("none");
    expect(summarizeStatusCheckRollup(undefined)).toBe("none");
    expect(summarizeStatusCheckRollup(null)).toBe("none");
  });

  it("returns success when every check succeeded, was neutral or skipped", () => {
    expect(
      summarizeStatusCheckRollup([
        { status: "COMPLETED", conclusion: "SUCCESS" },
        { status: "COMPLETED", conclusion: "NEUTRAL" },
        { status: "COMPLETED", conclusion: "SKIPPED" },
        { state: "SUCCESS" },
      ]),
    ).toBe("success");
  });

  it.each(["FAILURE", "CANCELLED", "TIMED_OUT"])(
    "returns failure for a check run concluding %s",
    (conclusion) => {
      expect(
        summarizeStatusCheckRollup([
          { status: "COMPLETED", conclusion: "SUCCESS" },
          { status: "COMPLETED", conclusion },
        ]),
      ).toBe("failure");
    },
  );

  it.each(["FAILURE", "ERROR"])(
    "returns failure for a status context in state %s",
    (state) => {
      expect(summarizeStatusCheckRollup([{ state }])).toBe("failure");
    },
  );

  it.each(["IN_PROGRESS", "QUEUED", "PENDING", "WAITING"])(
    "returns pending for a check run with status %s",
    (status) => {
      expect(
        summarizeStatusCheckRollup([
          { status: "COMPLETED", conclusion: "SUCCESS" },
          { status, conclusion: "" },
        ]),
      ).toBe("pending");
    },
  );

  it.each(["PENDING", "EXPECTED"])(
    "returns pending for a status context in state %s",
    (state) => {
      expect(summarizeStatusCheckRollup([{ state }])).toBe("pending");
    },
  );

  it("returns pending for a check run awaiting approval", () => {
    expect(
      summarizeStatusCheckRollup([
        { status: "COMPLETED", conclusion: "SUCCESS" },
        { status: "COMPLETED", conclusion: "ACTION_REQUIRED" },
      ]),
    ).toBe("pending");
  });

  it.each(["STALE", "SOMETHING_NEW"])(
    "returns pending for the inconclusive conclusion %s",
    (conclusion) => {
      expect(
        summarizeStatusCheckRollup([{ status: "COMPLETED", conclusion }]),
      ).toBe("pending");
    },
  );

  it("prefers failure over pending", () => {
    expect(
      summarizeStatusCheckRollup([
        { status: "IN_PROGRESS", conclusion: "" },
        { status: "COMPLETED", conclusion: "FAILURE" },
      ]),
    ).toBe("failure");
  });
});

describe("mapGitHubItemList", () => {
  it("maps PRs with draft, bot author, labels and checks, newest first", () => {
    expect(mapGitHubItemList("pr", PR_LIST_FIXTURE)).toEqual([
      {
        number: 330,
        title: "chore(deps): bump ws",
        url: "https://github.com/K9i-0/ccpocket/pull/330",
        author: { login: "dependabot", isBot: true },
        labels: ["dependencies"],
        createdAt: "2026-11-10T01:00:00Z",
        updatedAt: "2026-11-10T01:05:00Z",
        isDraft: false,
        checks: "success",
      },
      {
        number: 175,
        title: "Add Windows tray launcher",
        url: "https://github.com/K9i-0/ccpocket/pull/175",
        author: { login: "alex", isBot: false },
        labels: ["size:M", "risk:high"],
        createdAt: "2026-07-19T21:42:23Z",
        updatedAt: "2026-08-29T04:15:50Z",
        isDraft: true,
        checks: "failure",
      },
    ]);
  });

  it("maps issues without PR-only fields", () => {
    const items = mapGitHubItemList("issue", ISSUE_LIST_FIXTURE);
    expect(items.map((item) => item.number)).toEqual([331, 329]);
    expect(items[0]).toEqual({
      number: 331,
      title: "Newer issue",
      url: "https://github.com/K9i-0/ccpocket/issues/331",
      author: { login: "K9i-0", isBot: false },
      labels: [],
      createdAt: "2026-11-13T21:16:41Z",
      updatedAt: "2026-11-13T21:16:41Z",
    });
    expect(items[0]).not.toHaveProperty("isDraft");
    expect(items[0]).not.toHaveProperty("checks");
  });

  it("reports none for a PR without checks", () => {
    const [item] = mapGitHubItemList("pr", [
      { ...PR_LIST_FIXTURE[1], statusCheckRollup: [] },
    ]);
    expect(item.checks).toBe("none");
  });

  it("returns an empty list for a non-array payload", () => {
    expect(mapGitHubItemList("pr", { message: "nope" })).toEqual([]);
  });
});

describe("mapGitHubComments", () => {
  it("keeps the latest comments, oldest first", () => {
    const raw = Array.from({ length: 25 }, (_, index) => comment(index));
    const comments = mapGitHubComments([...raw].reverse());

    expect(comments).toHaveLength(GITHUB_DETAIL_COMMENT_LIMIT);
    expect(comments[0].body).toBe("comment 5");
    expect(comments[comments.length - 1].body).toBe("comment 24");
  });

  it("maps the author and body", () => {
    expect(mapGitHubComments([comment(1)])).toEqual([
      {
        author: { login: "alex", isBot: false },
        body: "comment 1",
        createdAt: "2026-01-01T00:01:00.000Z",
      },
    ]);
  });

  it("marks app comment authors as bots", () => {
    const [mapped] = mapGitHubComments([
      { ...comment(1), author: { login: "app/coderabbitai" } },
    ]);
    expect(mapped.author).toEqual({ login: "coderabbitai", isBot: true });
  });

  it("truncates an oversized comment body", () => {
    const [mapped] = mapGitHubComments([
      { ...comment(1), body: "c".repeat(GITHUB_BODY_MAX_LENGTH + 500) },
    ]);
    expect(mapped.body.startsWith("c".repeat(GITHUB_BODY_MAX_LENGTH))).toBe(
      true,
    );
    expect(mapped.body.endsWith("… (truncated)")).toBe(true);
    expect(mapped.body.length).toBeLessThan(GITHUB_BODY_MAX_LENGTH + 50);
  });

  it("returns an empty list when comments are missing", () => {
    expect(mapGitHubComments(undefined)).toEqual([]);
  });
});

describe("mapGitHubItemDetail", () => {
  it("adds the body and comments to a PR summary", () => {
    const detail = mapGitHubItemDetail("pr", {
      ...PR_LIST_FIXTURE[0],
      body: "## Summary\nbody",
      comments: [comment(2), comment(1)],
    });

    expect(detail).toMatchObject({
      number: 175,
      isDraft: true,
      checks: "failure",
      body: "## Summary\nbody",
    });
    expect(detail.comments.map((c) => c.body)).toEqual([
      "comment 1",
      "comment 2",
    ]);
  });

  it("truncates an oversized body and keeps one at the limit", () => {
    const atLimit = "b".repeat(GITHUB_BODY_MAX_LENGTH);
    expect(
      mapGitHubItemDetail("issue", { ...ISSUE_LIST_FIXTURE[0], body: atLimit })
        .body,
    ).toBe(atLimit);

    const detail = mapGitHubItemDetail("issue", {
      ...ISSUE_LIST_FIXTURE[0],
      body: `${atLimit}overflow`,
    });
    expect(detail.body).toBe(`${atLimit}\n\n… (truncated)`);
  });

  it("defaults a missing issue body to an empty string", () => {
    const detail = mapGitHubItemDetail("issue", {
      ...ISSUE_LIST_FIXTURE[0],
      body: null,
      comments: [],
    });
    expect(detail.body).toBe("");
    expect(detail.comments).toEqual([]);
    expect(detail).not.toHaveProperty("isDraft");
  });
});

describe("classifyGhFailure", () => {
  it("reports gh_missing when gh is not on PATH", () => {
    expect(
      classifyGhFailure({ code: "ENOENT", message: "spawn gh ENOENT" }).code,
    ).toBe("gh_missing");
  });

  it("reports gh_unauthenticated from the login hint", () => {
    expect(
      classifyGhFailure({
        code: 4,
        stderr:
          "To get started with GitHub CLI, please run:  gh auth login\nAlternatively, populate the GH_TOKEN environment variable with a GitHub API authentication token.\n",
      }).code,
    ).toBe("gh_unauthenticated");
  });

  it("reports gh_unauthenticated for rejected credentials", () => {
    expect(
      classifyGhFailure({
        code: 1,
        stderr: "HTTP 401: Bad credentials (https://api.github.com/graphql)",
      }).code,
    ).toBe("gh_unauthenticated");
  });

  it("reports a timeout as failed", () => {
    expect(
      classifyGhFailure({ code: null, killed: true, signal: "SIGTERM" }),
    ).toEqual({ code: "failed", message: "GitHub CLI timed out." });
  });

  it("reports an exceeded output buffer as too large, not a timeout", () => {
    expect(
      classifyGhFailure({
        code: "ERR_CHILD_PROCESS_STDIO_MAXBUFFER",
        killed: true,
        signal: "SIGTERM",
      }),
    ).toEqual({
      code: "failed",
      message: "GitHub CLI response was too large.",
    });
  });

  it("reports other failures with the first stderr line", () => {
    expect(
      classifyGhFailure({
        code: 1,
        stderr:
          "\nGraphQL: Could not resolve to a PullRequest with the number of 9999. (repository.pullRequest)\nmore\n",
      }),
    ).toEqual({
      code: "failed",
      message:
        "GraphQL: Could not resolve to a PullRequest with the number of 9999. (repository.pullRequest)",
    });
  });

  it("truncates a long failure message", () => {
    const result = classifyGhFailure({ code: 1, stderr: "x".repeat(500) });
    expect(result.code).toBe("failed");
    expect(result.message.length).toBeLessThanOrEqual(200);
  });
});

describe("toGitHubError", () => {
  it("keeps the code of a GitHubCliError", () => {
    expect(toGitHubError(new GitHubCliError("not_github", "nope"))).toEqual({
      code: "not_github",
      message: "nope",
    });
  });

  it("maps unknown errors to failed", () => {
    expect(toGitHubError(new Error("boom"))).toEqual({
      code: "failed",
      message: "boom",
    });
  });
});

function fakeRun(
  handlers: Partial<Record<"git" | "gh", (args: string[]) => string>>,
) {
  return vi.fn<RunCommand>(async (command, args) => {
    const handler = handlers[command as "git" | "gh"];
    if (!handler) throw { code: "ENOENT", message: `spawn ${command} ENOENT` };
    return handler(args);
  });
}

describe("resolveGitHubRepository", () => {
  it("resolves owner/name from the origin remote of the project", async () => {
    const run = fakeRun({ git: () => "git@github.com:K9i-0/ccpocket.git\n" });

    await expect(resolveGitHubRepository("/p", { run })).resolves.toBe(
      "K9i-0/ccpocket",
    );
    expect(run).toHaveBeenCalledWith(
      "git",
      ["remote", "get-url", "origin"],
      expect.objectContaining({ cwd: "/p" }),
    );
  });

  it("rejects with not_github for another host", async () => {
    const run = fakeRun({ git: () => "https://gitlab.com/owner/repo.git\n" });

    await expect(resolveGitHubRepository("/p", { run })).rejects.toMatchObject({
      code: "not_github",
    });
  });

  it.each([
    [2, "error: No such remote 'origin'\n"],
    [
      128,
      "fatal: not a git repository (or any of the parent directories): .git\n",
    ],
  ])("rejects with not_github for git exit %i", async (code, stderr) => {
    const run = fakeRun({
      git: () => {
        throw { code, stderr };
      },
    });

    await expect(resolveGitHubRepository("/p", { run })).rejects.toMatchObject({
      code: "not_github",
    });
  });

  it("rejects with failed and the stderr line for other git failures", async () => {
    const run = fakeRun({
      git: () => {
        throw {
          code: 128,
          stderr:
            "fatal: detected dubious ownership in repository at '/p'\nTo add an exception...\n",
        };
      },
    });

    await expect(resolveGitHubRepository("/p", { run })).rejects.toMatchObject({
      code: "failed",
      message: "fatal: detected dubious ownership in repository at '/p'",
    });
  });

  it("reports a missing project directory when spawn fails with ENOENT", async () => {
    const run = fakeRun({});

    await expect(
      resolveGitHubRepository("/p", {
        run,
        directoryExists: async () => false,
      }),
    ).rejects.toMatchObject({
      code: "failed",
      message: "The project directory was not found on the Bridge host.",
    });
  });

  it("reports a missing git binary when the project directory exists", async () => {
    const run = fakeRun({});

    await expect(
      resolveGitHubRepository("/p", { run, directoryExists: async () => true }),
    ).rejects.toMatchObject({
      code: "failed",
      message: "git is not installed on the Bridge host.",
    });
  });
});

describe("listGitHubItems", () => {
  it("lists open PRs of the resolved repository", async () => {
    const run = fakeRun({
      git: () => "https://github.com/K9i-0/ccpocket.git\n",
      gh: () => JSON.stringify(PR_LIST_FIXTURE),
    });

    const result = await listGitHubItems("/p", "pr", { run });

    expect(result.repository).toBe("K9i-0/ccpocket");
    expect(result.items.map((item) => item.number)).toEqual([330, 175]);
    expect(run).toHaveBeenLastCalledWith(
      "gh",
      [
        "pr",
        "list",
        "--repo",
        "github.com/K9i-0/ccpocket",
        "--state",
        "open",
        "--limit",
        "100",
        "--json",
        "number,title,author,isDraft,labels,createdAt,updatedAt,statusCheckRollup,url",
      ],
      expect.anything(),
    );
  });

  it("lists open issues with the issue field set", async () => {
    const run = fakeRun({
      git: () => "https://github.com/K9i-0/ccpocket.git\n",
      gh: () => JSON.stringify(ISSUE_LIST_FIXTURE),
    });

    const result = await listGitHubItems("/p", "issue", { run });

    expect(result.items.map((item) => item.number)).toEqual([331, 329]);
    const ghArgs = run.mock.calls[1][1];
    expect(ghArgs.slice(0, 2)).toEqual(["issue", "list"]);
    expect(ghArgs[ghArgs.length - 1]).toBe(
      "number,title,author,labels,createdAt,updatedAt,url",
    );
  });

  it("rejects with gh_missing when gh is not installed", async () => {
    const run = fakeRun({ git: () => "https://github.com/K9i-0/ccpocket\n" });

    await expect(listGitHubItems("/p", "pr", { run })).rejects.toMatchObject({
      code: "gh_missing",
    });
  });

  it("rejects with gh_unauthenticated when gh needs a login", async () => {
    const run = fakeRun({
      git: () => "https://github.com/K9i-0/ccpocket\n",
      gh: () => {
        throw { code: 4, stderr: "please run:  gh auth login" };
      },
    });

    await expect(listGitHubItems("/p", "pr", { run })).rejects.toMatchObject({
      code: "gh_unauthenticated",
    });
  });

  it("rejects with failed for unparseable output", async () => {
    const run = fakeRun({
      git: () => "https://github.com/K9i-0/ccpocket\n",
      gh: () => "not json",
    });

    await expect(listGitHubItems("/p", "pr", { run })).rejects.toMatchObject({
      code: "failed",
    });
  });

  it("does not call gh for a non-GitHub project", async () => {
    const run = fakeRun({
      git: () => "https://gitlab.com/owner/repo.git\n",
      gh: () => "[]",
    });

    await expect(listGitHubItems("/p", "pr", { run })).rejects.toMatchObject({
      code: "not_github",
    });
    expect(run).toHaveBeenCalledTimes(1);
  });
});

describe("getGitHubItem", () => {
  it("views an issue with body and comments", async () => {
    const run = fakeRun({
      git: () => "https://github.com/K9i-0/ccpocket.git\n",
      gh: () =>
        JSON.stringify({
          ...ISSUE_LIST_FIXTURE[1],
          body: "details",
          comments: [comment(1)],
        }),
    });

    const result = await getGitHubItem("/p", "issue", 331, { run });

    expect(result.item).toMatchObject({ number: 331, body: "details" });
    expect(result.item.comments).toHaveLength(1);
    expect(run).toHaveBeenLastCalledWith(
      "gh",
      [
        "issue",
        "view",
        "331",
        "--repo",
        "github.com/K9i-0/ccpocket",
        "--json",
        "number,title,author,labels,createdAt,updatedAt,url,body,comments",
      ],
      expect.anything(),
    );
  });

  it("requests PR-only fields for a PR", async () => {
    const run = fakeRun({
      git: () => "https://github.com/K9i-0/ccpocket.git\n",
      gh: () =>
        JSON.stringify({ ...PR_LIST_FIXTURE[0], body: "", comments: [] }),
    });

    const result = await getGitHubItem("/p", "pr", 175, { run });

    expect(result.item.isDraft).toBe(true);
    const ghArgs = run.mock.calls[1][1];
    expect(ghArgs[ghArgs.length - 1]).toContain("isDraft");
    expect(ghArgs[ghArgs.length - 1]).toContain("statusCheckRollup");
  });
});
