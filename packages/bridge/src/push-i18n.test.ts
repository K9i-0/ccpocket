import { describe, expect, it } from "vitest";

import { normalizePushLocale, t } from "./push-i18n.js";

describe("push i18n", () => {
  it("returns zh for simplified Chinese locale tags", () => {
    expect(normalizePushLocale("zh-CN")).toBe("zh");
    expect(normalizePushLocale("zh_Hans")).toBe("zh");
  });

  it("returns ko for Korean locale tags", () => {
    expect(normalizePushLocale("ko")).toBe("ko");
    expect(normalizePushLocale("ko-KR")).toBe("ko");
  });

  it("falls back to en for unsupported locales", () => {
    expect(normalizePushLocale("fr")).toBe("en");
  });

  it("returns Chinese translations with placeholders resolved", () => {
    expect(t("zh", "approval_body", { toolName: "apply_patch" })).toBe(
      "请批准执行 apply_patch",
    );
  });

  it("returns Korean translations with placeholders resolved", () => {
    expect(t("ko", "approval_body", { toolName: "apply_patch" })).toBe(
      "apply_patch 실행을 승인하세요",
    );
  });

  it("defaults to en without a locale and ignores tag casing", () => {
    expect(normalizePushLocale(undefined)).toBe("en");
    expect(normalizePushLocale("")).toBe("en");
    expect(normalizePushLocale("JA-jp")).toBe("ja");
    expect(normalizePushLocale("en_US")).toBe("en");
  });

  const KEYS = [
    "goal_progress", "goal_complete", "goal_blocked", "goal_budget_limited",
    "goal_usage_limited", "approval_title", "ask_title", "plan_ready_title",
    "approval_body", "plan_ready_body", "ask_default_body", "task_completed",
    "error_occurred", "session_completed", "session_failed",
    "approval_body_private", "ask_body_private", "result_success_body_private",
    "result_error_body_private",
  ];

  it.each(KEYS)("has an English string for %s", (key) => {
    const text = t("en", key);
    expect(text).not.toBe(key);
    expect(text.trim()).not.toBe("");
    expect(text).toMatch(/^[\x20-\x7e·]+$/);
  });

  it.each(
    (["ja", "zh", "ko"] as const).flatMap((locale) => KEYS.map((key) => [locale, key] as const)),
  )("has a localized %s string for %s", (locale, key) => {
    const text = t(locale, key);
    expect(text).not.toBe(key);
    expect(text).not.toBe(t("en", key));
    // Localized text, not an untranslated English leftover.
    expect(text).toMatch(/[^\x00-\x7f]/);
  });

  it("keeps the tool name placeholder in every approval body", () => {
    for (const locale of ["en", "ja", "zh", "ko"] as const) {
      expect(t(locale, "approval_body")).toContain("{toolName}");
      expect(t(locale, "approval_body", { toolName: "Bash" })).toContain("Bash");
      expect(t(locale, "approval_body", { toolName: "Bash" })).not.toContain("{");
    }
  });

  it("resolves English and Japanese entries", () => {
    expect(t("en", "approval_body", { toolName: "Bash" })).toBe("Approve execution of Bash");
    expect(t("en", "session_failed")).toBe("Session failed");
    expect(t("ja", "approval_body", { toolName: "Bash" })).toBe("Bash の実行を承認してください");
    expect(t("ja", "ask_title")).toBe("回答待ち");
  });

  it("falls back to English for an unknown locale and to the key for an unknown entry", () => {
    expect(t("fr" as unknown as "en", "task_completed")).toBe("Task completed");
    expect(t("ja", "no_such_key")).toBe("no_such_key");
    expect(t("ja", "no_such_{x}", { x: "key" })).toBe("no_such_key");
  });

  it("replaces every occurrence of a placeholder and leaves unknown ones", () => {
    expect(t("en", "{a}-{a}-{b}", { a: "1" })).toBe("1-1-{b}");
  });
});
