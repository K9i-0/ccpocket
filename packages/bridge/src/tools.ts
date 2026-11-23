import {
  checkCliProviders,
  checkGit,
  checkGitHubCli,
  checkNodeVersion,
  checkTailscale,
  type CheckResult,
  type ProviderResult,
} from "./doctor.js";

/**
 * Tools ccpocket relies on, with install state and copyable commands, for the
 * setup guide in the app (`GET /tools`). Texts shown to users are localized in
 * the app by [ToolStatus.id]; messages here are diagnostic English.
 */
export type ToolId =
  | "node"
  | "git"
  | "claude"
  | "codex"
  | "antigravity"
  | "gh"
  | "tailscale";

/**
 * - `required`: the Bridge cannot work without it.
 * - `agent`: a coding agent; at least one of them is required.
 * - `optional`: enables an extra feature.
 */
export type ToolRequirement = "required" | "agent" | "optional";

export interface ToolCommand {
  /** Short label such as "Homebrew" or "npm". */
  label: string;
  command: string;
}

export interface ToolStatus {
  id: ToolId;
  name: string;
  requirement: ToolRequirement;
  installed: boolean;
  version?: string;
  /** Installed, new enough, and signed in where that can be checked. */
  ready: boolean;
  /** Why it is not ready, or a note such as the auth method in use. */
  message?: string;
  /** Ways to install it on this platform; may be empty (see [docsUrl]). */
  installCommands: ToolCommand[];
  /** Command to run when it is installed but not signed in / connected. */
  setupCommand?: string;
  docsUrl: string;
}

export interface ToolsReport {
  platform: NodeJS.Platform;
  tools: ToolStatus[];
  /** Node, Git and at least one agent are ready. */
  ready: boolean;
}

type PlatformCommands = Partial<Record<NodeJS.Platform, ToolCommand[]>> & {
  default?: ToolCommand[];
};

const BREW = "Homebrew";

const INSTALL_COMMANDS: Record<ToolId, PlatformCommands> = {
  node: {
    darwin: [{ label: BREW, command: "brew install node" }],
    win32: [{ label: "winget", command: "winget install -e --id OpenJS.NodeJS.LTS" }],
  },
  git: {
    darwin: [
      { label: "Xcode Command Line Tools", command: "xcode-select --install" },
      { label: BREW, command: "brew install git" },
    ],
    linux: [{ label: "apt", command: "sudo apt install git" }],
    win32: [{ label: "winget", command: "winget install --id Git.Git -e --source winget" }],
  },
  claude: {
    default: [
      {
        label: "Installer",
        command: "curl -fsSL https://claude.ai/install.sh | bash",
      },
      { label: BREW, command: "brew install --cask claude-code" },
    ],
    win32: [
      {
        label: "PowerShell",
        command: "irm https://claude.ai/install.ps1 | iex",
      },
      { label: "winget", command: "winget install Anthropic.ClaudeCode" },
    ],
  },
  codex: {
    default: [
      {
        label: "Installer",
        command: "curl -fsSL https://chatgpt.com/codex/install.sh | sh",
      },
      { label: BREW, command: "brew install --cask codex" },
      { label: "npm", command: "npm install -g @openai/codex" },
    ],
    linux: [
      {
        label: "Installer",
        command: "curl -fsSL https://chatgpt.com/codex/install.sh | sh",
      },
      { label: "npm", command: "npm install -g @openai/codex" },
    ],
    win32: [{ label: "npm", command: "npm install -g @openai/codex" }],
  },
  antigravity: {
    default: [
      {
        label: "Installer",
        command: "curl -fsSL https://antigravity.google/cli/install.sh | bash",
      },
    ],
    win32: [
      {
        label: "PowerShell",
        command: "irm https://antigravity.google/cli/install.ps1 | iex",
      },
    ],
  },
  gh: {
    darwin: [{ label: BREW, command: "brew install gh" }],
    win32: [{ label: "winget", command: "winget install --id GitHub.cli --source winget" }],
  },
  tailscale: {
    darwin: [{ label: BREW, command: "brew install --cask tailscale-app" }],
    linux: [
      {
        label: "Installer",
        command: "curl -fsSL https://tailscale.com/install.sh | sh",
      },
    ],
  },
};

const DOCS_URLS: Record<ToolId, string> = {
  node: "https://nodejs.org/en/download",
  git: "https://git-scm.com/downloads",
  claude: "https://code.claude.com/docs/en/setup",
  codex: "https://github.com/openai/codex",
  antigravity: "https://antigravity.google/docs/getting-started/?tab=cli",
  gh: "https://cli.github.com/",
  tailscale: "https://tailscale.com/download",
};

export function installCommandsFor(
  id: ToolId,
  platform: NodeJS.Platform = process.platform,
): ToolCommand[] {
  const commands = INSTALL_COMMANDS[id];
  return commands[platform] ?? commands.default ?? [];
}

/** `"Run: codex login"` -> `"codex login"`. */
function commandFromRemediation(remediation?: string): string | undefined {
  const match = /^Run:\s*(.+)$/.exec(remediation ?? "");
  return match?.[1].trim();
}

function fromCheck(
  id: ToolId,
  requirement: ToolRequirement,
  check: CheckResult,
  platform: NodeJS.Platform,
): ToolStatus {
  const installed = check.status === "pass" || check.status === "warn";
  // Node is running this code, so a failed check means "too old".
  const nodeTooOld = id === "node" && check.status === "fail";
  // "v2.60.0 (authenticated)" -> "v2.60.0"; "Connected (100.x)" has none.
  const version =
    installed || nodeTooOld
      ? /^v?\d[\w.-]*/.exec(check.message)?.[0]
      : undefined;
  return {
    id,
    name: check.name,
    requirement,
    installed: installed || nodeTooOld,
    ...(version ? { version } : {}),
    ready: check.status === "pass",
    // A passing check whose message is only the version needs no note.
    ...(check.status === "pass" && check.message === version
      ? {}
      : { message: check.message }),
    installCommands: installCommandsFor(id, platform),
    ...(installed && commandFromRemediation(check.remediation)
      ? { setupCommand: commandFromRemediation(check.remediation) }
      : {}),
    docsUrl: DOCS_URLS[id],
  };
}

function fromProvider(
  id: ToolId,
  name: string,
  requirement: ToolRequirement,
  provider: ProviderResult | undefined,
  platform: NodeJS.Platform,
): ToolStatus {
  const installed = provider?.installed ?? false;
  const ready = installed && (provider?.authenticated ?? false);
  return {
    id,
    name,
    requirement,
    installed,
    ...(provider?.version ? { version: provider.version } : {}),
    ready,
    ...(provider?.authMessage ? { message: provider.authMessage } : {}),
    installCommands: installCommandsFor(id, platform),
    ...(installed && !ready && commandFromRemediation(provider?.remediation)
      ? { setupCommand: commandFromRemediation(provider?.remediation) }
      : {}),
    docsUrl: DOCS_URLS[id],
  };
}

export interface ToolChecks {
  node: () => Promise<CheckResult>;
  git: () => Promise<CheckResult>;
  providers: () => Promise<{ providers: ProviderResult[] }>;
  gh: () => Promise<CheckResult>;
  tailscale: () => Promise<CheckResult>;
}

const DEFAULT_CHECKS: ToolChecks = {
  node: () => checkNodeVersion(),
  git: checkGit,
  providers: checkCliProviders,
  gh: checkGitHubCli,
  tailscale: checkTailscale,
};

export async function getToolsReport(
  platform: NodeJS.Platform = process.platform,
  checks: ToolChecks = DEFAULT_CHECKS,
): Promise<ToolsReport> {
  const [node, git, cli, gh, tailscale] = await Promise.all([
    checks.node(),
    checks.git(),
    checks.providers(),
    checks.gh(),
    checks.tailscale(),
  ]);
  const provider = (name: string) =>
    cli.providers.find((p) => p.name === name);

  const tools: ToolStatus[] = [
    fromCheck("node", "required", node, platform),
    fromCheck("git", "required", git, platform),
    fromProvider(
      "claude",
      "Claude Code",
      "agent",
      provider("Claude Code CLI"),
      platform,
    ),
    fromProvider("codex", "Codex", "agent", provider("Codex CLI"), platform),
    fromProvider(
      "antigravity",
      "Antigravity",
      "agent",
      provider("Antigravity CLI"),
      platform,
    ),
    fromCheck("gh", "optional", gh, platform),
    fromCheck("tailscale", "optional", tailscale, platform),
  ];

  const ready =
    tools
      .filter((tool) => tool.requirement === "required")
      .every((tool) => tool.ready) &&
    tools.some((tool) => tool.requirement === "agent" && tool.ready);
  return { platform, tools, ready };
}

const TOOLS_CACHE_MS = 30_000;
let cachedReport: { at: number; report: Promise<ToolsReport> } | undefined;

/**
 * [getToolsReport] with a short cache. The checks run CLIs synchronously and
 * block the Bridge while they do, so screens that merely open reuse a recent
 * result; an explicit "check again" passes [refresh].
 */
export function getCachedToolsReport(
  refresh = false,
  now = Date.now(),
  load: () => Promise<ToolsReport> = () => getToolsReport(),
): Promise<ToolsReport> {
  if (!refresh && cachedReport && now - cachedReport.at < TOOLS_CACHE_MS) {
    return cachedReport.report;
  }
  const report = load();
  cachedReport = { at: now, report };
  report.catch(() => {
    if (cachedReport?.report === report) cachedReport = undefined;
  });
  return report;
}
