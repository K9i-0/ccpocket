import { describe, expect, it } from "vitest";
import {
  catalogFromCachedCommands,
  convertSkillTriggers,
  hasForeignSkillTrigger,
  type SkillTriggerCatalog,
} from "./skill-triggers.js";

const codex: SkillTriggerCatalog = {
  provider: "codex",
  skills: new Map([
    ["review-pr", "/s/review-pr/SKILL.md"],
    ["plugin:deploy", "/s/deploy/SKILL.md"],
  ]),
};
const claude: SkillTriggerCatalog = {
  provider: "claude",
  skills: new Map([
    ["review-pr", ""],
    ["plugin:deploy", ""],
  ]),
};

describe("convertSkillTriggers", () => {
  it("rewrites slash skills for Codex and attaches structured skills", () => {
    expect(convertSkillTriggers("/review-pr 1 then /plugin:deploy.", codex)).toEqual({
      text: "$review-pr 1 then $plugin:deploy.",
      skills: [
        { name: "review-pr", path: "/s/review-pr/SKILL.md" },
        { name: "plugin:deploy", path: "/s/deploy/SKILL.md" },
      ],
    });
    expect(convertSkillTriggers("これを/review-prして", codex).text).toBe(
      "これを$review-prして",
    );
  });

  it("keeps native Codex tokens but still attaches them", () => {
    expect(convertSkillTriggers("$review-pr now", codex)).toEqual({
      text: "$review-pr now",
      skills: [{ name: "review-pr", path: "/s/review-pr/SKILL.md" }],
    });
  });

  it("rewrites dollar skills for Claude without structured skills", () => {
    expect(convertSkillTriggers("$review-pr 42", claude)).toEqual({
      text: "/review-pr 42",
      skills: [],
    });
  });

  it("leaves unknown names, paths, prices and code alone", () => {
    for (const input of [
      "/unknown",
      "see /usr/bin and /review-pr/sub",
      "open /review-pr.txt",
      "a/review-pr b",
      "run `/review-pr`",
      "```\n/review-pr\n```",
    ]) {
      expect(convertSkillTriggers(input, codex).text).toBe(input);
    }
    for (const input of ["costs $5", "echo $HOME", "a$review-pr"]) {
      expect(convertSkillTriggers(input, claude).text).toBe(input);
    }
  });
});

describe("hasForeignSkillTrigger", () => {
  it("detects candidates only for the other agent's trigger", () => {
    expect(hasForeignSkillTrigger("/review-pr", "codex")).toBe(true);
    expect(hasForeignSkillTrigger("$review-pr", "codex")).toBe(false);
    expect(hasForeignSkillTrigger("$review-pr", "claude")).toBe(true);
    expect(hasForeignSkillTrigger("price is $ 5 and a/b", "claude")).toBe(false);
    expect(hasForeignSkillTrigger("plain text", "codex")).toBe(false);
  });
});

describe("catalogFromCachedCommands", () => {
  it("waits for Codex skill metadata and skips reserved or disabled skills", () => {
    expect(
      catalogFromCachedCommands("codex", { slashCommands: [], skills: [] }),
    ).toBeNull();
    const catalog = catalogFromCachedCommands("codex", {
      slashCommands: [],
      skills: ["review-pr", "goal", "off"],
      skillMetadata: [
        { name: "review-pr", path: "/s/SKILL.md", enabled: true },
        { name: "goal", path: "/g/SKILL.md", enabled: true },
        { name: "off", path: "/o/SKILL.md", enabled: false },
      ],
    });
    expect([...catalog!.skills.keys()]).toEqual(["review-pr"]);
  });

  it("uses Claude slash commands except builtins", () => {
    expect(
      catalogFromCachedCommands("claude", { slashCommands: [], skills: [] }),
    ).toBeNull();
    const catalog = catalogFromCachedCommands("claude", {
      slashCommands: ["review-pr", "compact", "my-cmd"],
      skills: ["review-pr", "compact"],
    });
    expect([...catalog!.skills.keys()]).toEqual(["review-pr", "my-cmd"]);
  });
});
