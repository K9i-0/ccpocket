export type PushLocale = "en" | "ja" | "zh" | "ko";

const translations: Record<PushLocale, Record<string, string>> = {
  en: {
    goal_progress: "Intermediate response · Goal in progress",
    goal_complete: "Goal achieved",
    goal_blocked: "Action needed to continue",
    goal_budget_limited: "Stopped: token budget reached",
    goal_usage_limited: "Stopped: usage limit reached",
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
    goal_progress: "中間応答・ゴール進行中",
    goal_complete: "ゴール達成",
    goal_blocked: "続行に対応が必要です",
    goal_budget_limited: "トークン予算に達したため停止しました",
    goal_usage_limited: "利用上限に達したため停止しました",
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
  zh: {
    goal_progress: "中间回复 · 目标进行中",
    goal_complete: "目标已达成",
    goal_blocked: "需要处理才能继续",
    goal_budget_limited: "已停止：达到令牌预算",
    goal_usage_limited: "已停止：达到使用上限",
    approval_title: "需要批准",
    ask_title: "需要回复",
    plan_ready_title: "计划已准备好",
    approval_body: "请批准执行 {toolName}",
    plan_ready_body: "计划已准备好，请查看",
    ask_default_body: "Claude 正在提问",
    task_completed: "任务已完成",
    error_occurred: "发生错误",
    session_completed: "会话已完成",
    session_failed: "会话失败",
    // Privacy mode
    approval_body_private: "请批准工具执行",
    ask_body_private: "请回答一个问题",
    result_success_body_private: "会话已完成",
    result_error_body_private: "会话失败",
  },
  ko: {
    goal_progress: "중간 응답 · 목표 진행 중",
    goal_complete: "목표 달성",
    goal_blocked: "계속하려면 조치가 필요합니다",
    goal_budget_limited: "토큰 예산에 도달하여 중지됨",
    goal_usage_limited: "사용 한도에 도달하여 중지됨",
    approval_title: "승인 필요",
    ask_title: "응답 필요",
    plan_ready_title: "계획 준비 완료",
    approval_body: "{toolName} 실행을 승인하세요",
    plan_ready_body: "계획이 준비되었습니다. 검토해 주세요.",
    ask_default_body: "Claude가 질문하고 있습니다",
    task_completed: "작업 완료",
    error_occurred: "오류 발생",
    session_completed: "세션 완료",
    session_failed: "세션 실패",
    // Privacy mode
    approval_body_private: "도구 실행을 승인하세요",
    ask_body_private: "질문에 응답해 주세요",
    result_success_body_private: "세션 완료",
    result_error_body_private: "세션 실패",
  },
};

const SUPPORTED_LOCALES = new Set<string>(["en", "ja", "zh", "ko"]);

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
