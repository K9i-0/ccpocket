import { describe, expect, it } from "vitest";
import {
  getCachedToolsReport,
  getToolsReport,
  installCommandsFor,
  type ToolChecks,
  type ToolsReport,
} from "./tools.js";

function checks(overrides: Partial<ToolChecks> = {}): ToolChecks {
  return {
    node: async () => ({ name: "Node.js", status: "pass", message: "v24.1.0" }),
    git: async () => ({ name: "Git", status: "pass", message: "v2.50.0" }),
    providers: async () => ({
      providers: [
        {
          name: "Claude Code CLI",
          installed: true,
          version: "2.1.0",
          authenticated: true,
          authMessage: "API credential configured",
        },
        {
          name: "Codex CLI",
          installed: true,
          version: "codex 0.50",
          authenticated: false,
          authMessage: "Not authenticated",
          remediation: "Run: codex login",
        },
      ],
    }),
    gh: async () => ({
      name: "GitHub CLI",
      status: "skip",
      message: "Not installed (optional for GitHub triage)",
      remediation: "Install: https://cli.github.com/",
    }),
    tailscale: async () => ({
      name: "Tailscale",
      status: "warn",
      message: "Installed but not connected",
      remediation: "Run: tailscale up",
    }),
    ...overrides,
  };
}

describe("getToolsReport", () => {
  it("reports install state, sign-in commands and install commands", async () => {
    const report = await getToolsReport("darwin", checks());
    expect(report.ready).toBe(true);
    const byId = Object.fromEntries(report.tools.map((t) => [t.id, t]));
    expect(report.tools.map((t) => t.id)).toEqual([
      "node", "git", "claude", "codex", "antigravity", "gh", "tailscale",
    ]);
    expect(byId.node).toMatchObject({
      installed: true, ready: true, version: "v24.1.0", requirement: "required",
    });
    expect(byId.claude).toMatchObject({ installed: true, ready: true });
    expect(byId.claude.setupCommand).toBeUndefined();
    expect(byId.codex).toMatchObject({
      installed: true, ready: false, setupCommand: "codex login",
    });
    expect(byId.antigravity).toMatchObject({
      installed: false, ready: false, requirement: "agent",
    });
    expect(byId.antigravity.installCommands[0].command).toBe(
      "curl -fsSL https://antigravity.google/cli/install.sh | bash",
    );
    expect(byId.antigravity.docsUrl).toContain("antigravity.google");
    expect(byId.gh).toMatchObject({ installed: false, ready: false });
    expect(byId.gh.installCommands).toEqual([
      { label: "Homebrew", command: "brew install gh" },
    ]);
    expect(byId.gh.setupCommand).toBeUndefined();
    expect(byId.tailscale.version).toBeUndefined();
    expect(byId.tailscale.message).toBe("Installed but not connected");
    expect(byId.git).toMatchObject({ version: "v2.50.0" });
    expect(byId.git.message).toBeUndefined();
    expect(byId.tailscale).toMatchObject({
      installed: true, ready: false, setupCommand: "tailscale up",
    });
  });

  it("is not ready without a signed-in agent or with an old Node", async () => {
    const noAgent = await getToolsReport(
      "linux",
      checks({ providers: async () => ({ providers: [] }) }),
    );
    expect(noAgent.ready).toBe(false);

    const oldNode = await getToolsReport(
      "linux",
      checks({
        node: async () => ({
          name: "Node.js",
          status: "fail",
          message: "v20.0.0 (requires >=22.19.0)",
        }),
      }),
    );
    expect(oldNode.ready).toBe(false);
    expect(oldNode.tools[0]).toMatchObject({ installed: true, ready: false });
  });
});

describe("installCommandsFor", () => {
  it("falls back to the default commands of a tool", () => {
    expect(installCommandsFor("claude", "linux")[0].command).toContain(
      "claude.ai/install.sh",
    );
    expect(installCommandsFor("claude", "win32").map((c) => c.label)).toEqual([
      "PowerShell",
      "winget",
    ]);
    expect(installCommandsFor("tailscale", "darwin")[0].command).toBe(
      "brew install --cask tailscale-app",
    );
    expect(installCommandsFor("node", "linux")).toEqual([]);
  });
});

describe("getCachedToolsReport", () => {
  it("reuses a recent report unless a refresh is asked for", async () => {
    let calls = 0;
    const load = async (): Promise<ToolsReport> => {
      calls += 1;
      return { platform: "darwin", tools: [], ready: false };
    };
    await getCachedToolsReport(true, 1_000, load);
    await getCachedToolsReport(false, 20_000, load);
    expect(calls).toBe(1);
    await getCachedToolsReport(true, 21_000, load);
    expect(calls).toBe(2);
    await getCachedToolsReport(false, 60_000, load);
    expect(calls).toBe(3);
  });
});
