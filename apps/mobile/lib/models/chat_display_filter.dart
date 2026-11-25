import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Preset choices for what appears in the chat transcript (and what the Bridge
/// delivers when connected to a `performance_mode_v2` Bridge).
enum ChatDisplayPreset {
  /// Show every item without filtering.
  all,

  /// Recommended lightweight preset: keep tasks, thinking, and subagent/swarm
  /// progress while omitting code diffs, other tool calls, and tool outputs.
  recommended,

  /// Any combination of toggles that does not match [all] or [recommended].
  custom,
}

/// Per-category visibility and Bridge delivery filter for chat transcripts.
///
/// Essential conversation elements (user messages, assistant prose, plans,
/// approvals/questions, generated images, errors, completion chips, compaction)
/// are always shown and are not controlled by this filter.
@immutable
class ChatDisplayFilter {
  /// Task/TODO checklists (`TodoWrite` / Antigravity `update_steps`,
  /// Codex `UpdatePlan`, Claude `TaskCreate` / `TaskUpdate`).
  final bool tasks;

  /// Thinking blocks and live `thinking_delta` streams.
  final bool thinking;

  /// Subagent calls (`Agent`, `Task`, `SubAgent`, `invoke_subagent`),
  /// `tool_use_summary`, and Antigravity Swarm conversation (`SwarmPost`,
  /// `swarm add`).
  final bool subagents;

  /// Code edit tools (`Edit`, `Write`, `MultiEdit`, `NotebookEdit`,
  /// `FileChange`, `FileEdit`, `apply_patch`) and their inline diffs.
  final bool codeEdits;

  /// Other tool calls (`Bash`, `Read`, `Grep`, `Glob`, Web, MCP, etc.).
  final bool otherTools;

  /// Non-essential `tool_result` bodies and incidental images (such as
  /// simulator screenshots). `ImageGeneration` results and question answers
  /// are always preserved.
  final bool toolResults;

  const ChatDisplayFilter({
    this.tasks = true,
    this.thinking = true,
    this.subagents = true,
    this.codeEdits = true,
    this.otherTools = true,
    this.toolResults = true,
  });

  static const all = ChatDisplayFilter();

  static const recommended = ChatDisplayFilter(
    tasks: true,
    thinking: true,
    subagents: true,
    codeEdits: false,
    otherTools: false,
    toolResults: false,
  );

  /// Whether at least one category is hidden/omitted.
  bool get isFiltered =>
      !tasks ||
      !thinking ||
      !subagents ||
      !codeEdits ||
      !otherTools ||
      !toolResults;

  /// Whether a legacy `performance_mode_v1` Bridge can safely filter this
  /// configuration without dropping categories the user wants to keep.
  bool get canUseLegacyV1Bridge =>
      !tasks && !subagents && !codeEdits && !otherTools && !toolResults;

  /// Number of enabled categories out of 6.
  int get enabledCount =>
      (tasks ? 1 : 0) +
      (thinking ? 1 : 0) +
      (subagents ? 1 : 0) +
      (codeEdits ? 1 : 0) +
      (otherTools ? 1 : 0) +
      (toolResults ? 1 : 0);

  static const totalCategoryCount = 6;

  /// The preset matching this configuration.
  ChatDisplayPreset get preset {
    if (this == all) return ChatDisplayPreset.all;
    if (this == recommended) return ChatDisplayPreset.recommended;
    return ChatDisplayPreset.custom;
  }

  ChatDisplayFilter copyWith({
    bool? tasks,
    bool? thinking,
    bool? subagents,
    bool? codeEdits,
    bool? otherTools,
    bool? toolResults,
  }) {
    return ChatDisplayFilter(
      tasks: tasks ?? this.tasks,
      thinking: thinking ?? this.thinking,
      subagents: subagents ?? this.subagents,
      codeEdits: codeEdits ?? this.codeEdits,
      otherTools: otherTools ?? this.otherTools,
      toolResults: toolResults ?? this.toolResults,
    );
  }

  Map<String, bool> toJson() => <String, bool>{
    'tasks': tasks,
    'thinking': thinking,
    'subagents': subagents,
    'codeEdits': codeEdits,
    'otherTools': otherTools,
    'toolResults': toolResults,
  };

  String toJsonString() => jsonEncode(toJson());

  static ChatDisplayFilter? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final tasks = raw['tasks'];
    final thinking = raw['thinking'];
    final subagents = raw['subagents'];
    final codeEdits = raw['codeEdits'];
    final otherTools = raw['otherTools'];
    final toolResults = raw['toolResults'];
    if (tasks is! bool ||
        thinking is! bool ||
        subagents is! bool ||
        codeEdits is! bool ||
        otherTools is! bool ||
        toolResults is! bool) {
      return null;
    }
    return ChatDisplayFilter(
      tasks: tasks,
      thinking: thinking,
      subagents: subagents,
      codeEdits: codeEdits,
      otherTools: otherTools,
      toolResults: toolResults,
    );
  }

  static ChatDisplayFilter? fromJsonString(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatDisplayFilter &&
        other.tasks == tasks &&
        other.thinking == thinking &&
        other.subagents == subagents &&
        other.codeEdits == codeEdits &&
        other.otherTools == otherTools &&
        other.toolResults == toolResults;
  }

  @override
  int get hashCode => Object.hash(
    tasks,
    thinking,
    subagents,
    codeEdits,
    otherTools,
    toolResults,
  );

  @override
  String toString() =>
      'ChatDisplayFilter(tasks: $tasks, thinking: $thinking, '
      'subagents: $subagents, codeEdits: $codeEdits, '
      'otherTools: $otherTools, toolResults: $toolResults)';
}
