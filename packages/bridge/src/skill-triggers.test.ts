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

  it("returns the input untouched for empty text or an empty catalog", () => {
    expect(convertSkillTriggers("", codex)).toEqual({ text: "", skills: [] });
    expect(
      convertSkillTriggers("/review-pr now", { provider: "codex", skills: new Map() }),
    ).toEqual({ text: "/review-pr now", skills: [] });
  });

  it("rewrites a skill at the very end of the text", () => {
    expect(convertSkillTriggers("please run /review-pr", codex).text).toBe(
      "please run $review-pr",
    );
    expect(convertSkillTriggers("please run $review-pr", claude).text).toBe(
      "please run /review-pr",
    );
  });

  it.each([")", "]", "}", ",", ";", "!", "?", '"', "'"])(
    "accepts closing punctuation %s right after a skill",
    (punctuation) => {
      expect(convertSkillTriggers(`/review-pr${punctuation} next`, codex).text).toBe(
        `$review-pr${punctuation} next`,
      );
    },
  );

  it.each([
    ["/review-pr. Next", "$review-pr. Next"],
    ["/review-pr.です", "$review-pr.です"],
    ["/review-pr.", "$review-pr."],
    ["/review-pr: go", "$review-pr: go"],
    ["/review-pr:", "$review-pr:"],
    ["/plugin:deploy: go", "$plugin:deploy: go"],
    ["(/review-pr)", "($review-pr)"],
    ["[/review-pr]", "[$review-pr]"],
    ["a,/review-pr;b", "a,$review-pr;b"],
  ])("rewrites %s", (input, expected) => {
    expect(convertSkillTriggers(input, codex).text).toBe(expected);
  });

  it.each([
    "/review-pr# x",
    "/review-pr.x",
    "/review-pr:x",
    "/review-pr- x",
    "/review-pr=1",
    "/: x",
    "/ review-pr",
  ])("leaves %s alone", (input) => {
    expect(convertSkillTriggers(input, codex)).toEqual({ text: input, skills: [] });
  });

  it("recognises every character of the skill name charset", () => {
    const catalog: SkillTriggerCatalog = {
      provider: "codex",
      skills: new Map([["aAzZ_09-x:y", "/s/all/SKILL.md"]]),
    };
    expect(convertSkillTriggers("/aAzZ_09-x:y go", catalog)).toEqual({
      text: "$aAzZ_09-x:y go",
      skills: [{ name: "aAzZ_09-x:y", path: "/s/all/SKILL.md" }],
    });
  });

  it("attaches a repeated Codex skill only once", () => {
    expect(
      convertSkillTriggers("/review-pr then $review-pr and /review-pr", codex),
    ).toEqual({
      text: "$review-pr then $review-pr and $review-pr",
      skills: [{ name: "review-pr", path: "/s/review-pr/SKILL.md" }],
    });
  });

  it("rewrites a Codex skill without a path but does not attach it", () => {
    const catalog: SkillTriggerCatalog = {
      provider: "codex",
      skills: new Map([["nopath", ""]]),
    };
    expect(convertSkillTriggers("/nopath go", catalog)).toEqual({
      text: "$nopath go",
      skills: [],
    });
  });

  it("ignores skill names that are not typed with a trigger", () => {
    expect(convertSkillTriggers("see (review-pr) and  review-pr", codex)).toEqual({
      text: "see (review-pr) and  review-pr",
      skills: [],
    });
  });

  describe("Markdown code", () => {
    it.each([
      "`run /review-pr now`",
      "first line\n`run /review-pr now` and more",
      "`run /review-pr now` and more\nnext line",
      "```\nrun /review-pr now\n```",
      "```sh\nrun /review-pr now",
    ])("leaves skills inside code alone: %j", (input) => {
      expect(convertSkillTriggers(input, codex)).toEqual({ text: input, skills: [] });
    });

    it.each([
      ["`a` /review-pr `b`", "`a` $review-pr `b`"],
      ["/review-pr then `x`", "$review-pr then `x`"],
      ["`x` then /review-pr", "`x` then $review-pr"],
      ["```\ncode\n``` /review-pr", "```\ncode\n``` $review-pr"],
      ["```\n/plugin:deploy\n```\n/review-pr", "```\n/plugin:deploy\n```\n$review-pr"],
    ])("still rewrites skills outside code: %j", (input, expected) => {
      expect(convertSkillTriggers(input, codex).text).toBe(expected);
    });

    it("does not treat an unpaired backtick as a code span", () => {
      // No closing backtick at all.
      expect(convertSkillTriggers("it's ` /review-pr now", codex).text).toBe(
        "it's ` $review-pr now",
      );
      // The next backtick is on a later line, so it does not close the span.
      expect(convertSkillTriggers("a ` /review-pr\nnext ` line", codex).text).toBe(
        "a ` $review-pr\nnext ` line",
      );
    });
  });
});

describe("hasForeignSkillTrigger", () => {
  it.each([
    ["see (/review-pr)", "codex", true],
    ["a/b then /review-pr", "codex", true],
    ["これを/review-prして", "codex", true],
    ["a/review-pr", "codex", false],
    ["trailing /", "codex", false],
    ["/ review-pr", "codex", false],
    ["/.hidden", "codex", false],
    ["a$b then $review-pr", "claude", true],
    ["a$review-pr", "claude", false],
    ["/review-pr", "claude", false],
  ] as const)("%j for %s -> %s", (text, provider, expected) => {
    expect(hasForeignSkillTrigger(text, provider)).toBe(expected);
  });

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

  it("returns null without cached commands", () => {
    expect(catalogFromCachedCommands("codex", undefined)).toBeNull();
    expect(catalogFromCachedCommands("claude", undefined)).toBeNull();
  });

  it("maps Codex skill names to their SKILL.md paths", () => {
    const catalog = catalogFromCachedCommands("codex", {
      slashCommands: [],
      skills: [],
      skillMetadata: [
        { name: "review-pr", path: "/s/SKILL.md" },
        { name: "nopath" },
        { name: "badpath", path: 7 },
        { name: 42, path: "/n/SKILL.md" },
        { path: "/anonymous/SKILL.md" },
        { name: "", path: "/empty/SKILL.md" },
      ],
    });
    expect(catalog!.provider).toBe("codex");
    expect([...catalog!.skills]).toEqual([
      ["review-pr", "/s/SKILL.md"],
      ["nopath", ""],
      ["badpath", ""],
    ]);
  });

  it("skips every Codex slash command handled by the app", () => {
    const catalog = catalogFromCachedCommands("codex", {
      slashCommands: [],
      skills: [],
      skillMetadata: ["goal", "plan", "skills", "permissions", "mine"].map((name) => ({
        name,
        path: `/s/${name}/SKILL.md`,
      })),
    });
    expect([...catalog!.skills.keys()]).toEqual(["mine"]);
  });

  it("skips every Claude builtin command", () => {
    const builtins = [
      "compact",
      "plan",
      "goal",
      "clear",
      "help",
      "context",
      "cost",
      "init",
      "review",
      "model",
      "skills",
      "status",
      "memory",
      "config",
      "permissions",
      "pr-comments",
      "release-notes",
      "security-review",
      "resume",
      "rename",
      "doctor",
      "mcp",
      "export",
      "add-dir",
      "rewind",
      "vim",
      "login",
    ];
    const catalog = catalogFromCachedCommands("claude", {
      slashCommands: [...builtins, "", "my-cmd"],
      skills: [],
    });
    expect(catalog!.provider).toBe("claude");
    expect([...catalog!.skills]).toEqual([["my-cmd", ""]]);
  });
});
