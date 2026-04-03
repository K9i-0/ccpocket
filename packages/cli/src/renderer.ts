import chalk from "chalk";

type ServerMsg = Record<string, unknown>;

export function renderMessage(msg: ServerMsg): string {
  switch (msg.type) {
    case "assistant":
      return renderAssistant(msg);
    case "tool_result":
      return renderToolResult(msg);
    case "permission_request":
      return renderPermissionRequest(msg);
    case "status":
      return chalk.dim(`  ─ ${msg.status} ─`);
    case "error":
      return chalk.red(`✗ Error: ${msg.message}`);
    case "result":
      return renderResult(msg);
    case "user_input":
      return chalk.bold.blue(`\n> ${msg.text}\n`);
    case "stream_delta":
    case "thinking_delta":
      return "";
    default:
      return "";
  }
}

function renderAssistant(msg: ServerMsg): string {
  const message = msg.message as {
    content: Array<{ type: string; text?: string; name?: string; input?: Record<string, unknown>; thinking?: string }>;
  };
  const parts: string[] = [];

  for (const block of message.content) {
    switch (block.type) {
      case "text":
        parts.push(`\n${chalk.bold("⏺")} ${block.text}\n`);
        break;
      case "tool_use":
        parts.push(renderToolUse(block.name!, block.input!));
        break;
      case "thinking":
        if (block.thinking) {
          const preview = block.thinking.slice(0, 100).replace(/\n/g, " ");
          parts.push(chalk.dim(`  💭 ${preview}${block.thinking.length > 100 ? "..." : ""}`));
        }
        break;
    }
  }
  return parts.join("\n");
}

function renderToolUse(name: string, input: Record<string, unknown>): string {
  const header = chalk.cyan(`  ⎿ ${name}`);

  if (name === "Read" || name === "Write" || name === "Edit") {
    const path = input.file_path ?? input.path ?? "";
    return `${header} ${chalk.dim(String(path))}`;
  }
  if (name === "Bash") {
    const cmd = input.command ?? "";
    return `${header}\n    ${chalk.dim(String(cmd))}`;
  }
  if (name === "Grep") {
    return `${header} ${chalk.dim(`pattern="${input.pattern}"`)}`;
  }

  const entries = Object.entries(input).slice(0, 2);
  const summary = entries.map(([k, v]) => `${k}=${JSON.stringify(v)}`).join(" ");
  return `${header} ${chalk.dim(summary.slice(0, 120))}`;
}

function renderToolResult(msg: ServerMsg): string {
  const content = String(msg.content ?? "");
  const toolName = msg.toolName ? chalk.dim(` (${msg.toolName})`) : "";
  if (!content.trim()) return "";

  const maxLines = 20;
  const lines = content.split("\n");
  const truncated = lines.length > maxLines;
  const shown = lines.slice(0, maxLines).join("\n");

  return `${chalk.dim("  ⎿")}${toolName}\n${indent(shown, 4)}${truncated ? chalk.dim(`\n    ... (${lines.length - maxLines} more lines)`) : ""}`;
}

function renderPermissionRequest(msg: ServerMsg): string {
  const tool = String(msg.toolName ?? "unknown");
  const input = msg.input as Record<string, unknown> | undefined;
  const path = input?.file_path ?? input?.command ?? "";
  return `\n${chalk.yellow.bold("⚠ Permission required:")} ${chalk.bold(tool)}${path ? ` ${chalk.dim(String(path))}` : ""}`;
}

function renderResult(msg: ServerMsg): string {
  const parts: string[] = [];
  if (msg.cost != null) {
    parts.push(`Cost: $${(msg.cost as number).toFixed(4)}`);
  }
  if (msg.duration != null) {
    const secs = ((msg.duration as number) / 1000).toFixed(1);
    parts.push(`Duration: ${secs}s`);
  }
  if (parts.length === 0) return "";
  return chalk.dim(`\n  ─ ${parts.join(" · ")} ─\n`);
}

function indent(text: string, spaces: number): string {
  const pad = " ".repeat(spaces);
  return text.split("\n").map((line) => pad + line).join("\n");
}

export function renderDiff(oldStr: string, newStr: string): string {
  const lines: string[] = [];
  for (const line of oldStr.split("\n")) {
    lines.push(chalk.red(`- ${line}`));
  }
  for (const line of newStr.split("\n")) {
    lines.push(chalk.green(`+ ${line}`));
  }
  return lines.join("\n");
}
