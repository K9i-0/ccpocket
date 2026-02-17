import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Tool category classification based on CodePilot's approach.
///
/// Each category has a distinct icon, color, and summary extraction rule
/// for compact CLI-like display in chat bubbles.
enum ToolCategory { read, write, bash, search, other }

/// Classify a tool name into a [ToolCategory].
ToolCategory categorizeToolName(String name) {
  // MCP tools have a server prefix (e.g. "mcp__dart-mcp__run_tests")
  if (name.startsWith('mcp__')) return ToolCategory.other;

  return switch (name) {
    'Read' => ToolCategory.read,
    'Write' || 'Edit' || 'NotebookEdit' || 'MultiEdit' => ToolCategory.write,
    'Bash' => ToolCategory.bash,
    'Grep' || 'Glob' || 'WebSearch' || 'WebFetch' => ToolCategory.search,
    _ => ToolCategory.other,
  };
}

/// Extract a compact one-line summary from tool input.
///
/// Rules per category (following CodePilot's `getToolSummary()`):
/// - read/write  → file name only (`main.dart`)
/// - bash        → command, truncated to 60 chars
/// - search      → `"pattern"`, truncated to 50 chars
/// - other       → description or first meaningful key, 50 chars
String getToolSummary(ToolCategory category, Map<String, dynamic> input) {
  return switch (category) {
    ToolCategory.read || ToolCategory.write => _fileSummary(input),
    ToolCategory.bash => _bashSummary(input),
    ToolCategory.search => _searchSummary(input),
    ToolCategory.other => _otherSummary(input),
  };
}

/// Icon for each tool category.
IconData getToolCategoryIcon(ToolCategory category) {
  return switch (category) {
    ToolCategory.read => Icons.description_outlined,
    ToolCategory.write => Icons.edit_note,
    ToolCategory.bash => Icons.terminal,
    ToolCategory.search => Icons.search,
    ToolCategory.other => Icons.build_outlined,
  };
}

/// Category-aware color for the tool dot/icon.
Color getToolCategoryColor(ToolCategory category, AppColors appColors) {
  return switch (category) {
    ToolCategory.read => appColors.toolIcon,
    ToolCategory.write => appColors.toolIcon,
    ToolCategory.bash => appColors.toolIcon,
    ToolCategory.search => appColors.toolIcon,
    ToolCategory.other => appColors.toolIcon,
  };
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

String _fileSummary(Map<String, dynamic> input) {
  final raw = input['file_path'] ?? input['path'] ?? input['notebook_path'];
  if (raw == null) return _fallbackSummary(input);
  final path = raw.toString();
  // Extract file name only (after last '/')
  final idx = path.lastIndexOf('/');
  return idx >= 0 ? path.substring(idx + 1) : path;
}

String _bashSummary(Map<String, dynamic> input) {
  final cmd = input['command']?.toString();
  if (cmd == null || cmd.isEmpty) return _fallbackSummary(input);
  return cmd.length > 60 ? '${cmd.substring(0, 57)}...' : cmd;
}

String _searchSummary(Map<String, dynamic> input) {
  final pattern =
      input['pattern'] ?? input['query'] ?? input['url'] ?? input['prompt'];
  if (pattern == null) return _fallbackSummary(input);
  final s = pattern.toString();
  final truncated = s.length > 50 ? '${s.substring(0, 47)}...' : s;
  return '"$truncated"';
}

String _otherSummary(Map<String, dynamic> input) {
  // Task agent: use description
  final desc = input['description'] ?? input['prompt'] ?? input['skill'];
  if (desc != null) {
    final s = desc.toString();
    return s.length > 50 ? '${s.substring(0, 47)}...' : s;
  }
  return _fallbackSummary(input);
}

String _fallbackSummary(Map<String, dynamic> input) {
  final keys = input.keys.take(3).join(', ');
  return keys.isNotEmpty ? keys : '{}';
}
