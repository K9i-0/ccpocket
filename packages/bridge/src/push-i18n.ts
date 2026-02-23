export type PushLocale = "en" | "ja";

const translations: Record<PushLocale, Record<string, string>> = {
  en: {
    approval_title: "Approval needed",
    ask_title: "Response needed",
    plan_ready_title: "Plan ready",
    approval_body: "Approve execution of {toolName}",
    plan_ready_body: "Plan is ready for review",
    ask_default_body: "Claude is asking a question",
    task_completed: "Task completed",
    error_occurred: "Error occurred",
    session_completed: "Session completed",
    session_failed: "Session failed",
    // Privacy mode: generic bodies without tool names, question text, or result details
    approval_body_private: "Approve tool execution",
    ask_body_private: "Please respond to a question",
    result_success_body_private: "Session completed",
    result_error_body_private: "Session failed",
  },
  ja: {
    approval_title: "承認待ち",
    ask_title: "回答待ち",
    plan_ready_title: "プラン完成",
    approval_body: "{toolName} の実行を承認してください",
    plan_ready_body: "プランが完成しました。確認してください",
    ask_default_body: "Claude が質問しています",
    task_completed: "タスク完了",
    error_occurred: "エラー発生",
    session_completed: "セッション完了",
    session_failed: "セッションが失敗しました",
    // Privacy mode
    approval_body_private: "ツールの実行を承認してください",
    ask_body_private: "質問に回答してください",
    result_success_body_private: "セッション完了",
    result_error_body_private: "セッションが失敗しました",
  },
};

const SUPPORTED_LOCALES = new Set<string>(["en", "ja"]);

export function normalizePushLocale(locale: string | undefined): PushLocale {
  if (!locale) return "en";
  const lang = locale.split(/[-_]/)[0].toLowerCase();
  return SUPPORTED_LOCALES.has(lang) ? (lang as PushLocale) : "en";
}

/**
 * Look up a translated push notification string.
 * Supports `{param}` placeholders replaced by `params` values.
 */
export function t(
  locale: PushLocale,
  key: string,
  params?: Record<string, string>,
): string {
  const table = translations[locale] ?? translations.en;
  let text = table[key] ?? translations.en[key] ?? key;
  if (params) {
    for (const [k, v] of Object.entries(params)) {
      text = text.replaceAll(`{${k}}`, v);
    }
  }
  return text;
}
