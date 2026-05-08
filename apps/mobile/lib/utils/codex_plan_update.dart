const codexUpdatePlanToolName = 'UpdatePlan';

bool isCodexUpdatePlanTool(String name) => name == codexUpdatePlanToolName;

Map<String, dynamic>? codexPlanUpdateInputFromText(String text) {
  final lines = text.trim().split('\n');
  if (lines.isEmpty) return null;

  final header = lines.first.trim();
  if (!header.startsWith('Plan update:')) return null;

  final explanation = header.substring('Plan update:'.length).trim();
  final todos = <Map<String, dynamic>>[];
  final itemPattern = RegExp(
    r'^\s*\d+\.\s+\[(completed|in progress|pending)\]\s+(.+?)\s*$',
  );

  for (final line in lines.skip(1)) {
    final match = itemPattern.firstMatch(line);
    if (match == null) continue;
    todos.add({
      'content': match.group(2) ?? '',
      'status': _inputStatus(match.group(1) ?? 'pending'),
      'activeForm': '',
    });
  }

  if (todos.isEmpty) return null;
  return {
    'title': 'Plan update',
    if (explanation.isNotEmpty) 'explanation': explanation,
    'todos': todos,
  };
}

String? codexPlanUpdateTextFromInput(Map<String, dynamic> input) {
  final todosRaw = input['todos'];
  if (todosRaw is! List || todosRaw.isEmpty) return null;

  final explanation = input['explanation'];
  final header = explanation is String && explanation.trim().isNotEmpty
      ? 'Plan update: ${explanation.trim()}'
      : 'Plan update:';

  final lines = <String>[];
  for (final (index, todo) in todosRaw.indexed) {
    if (todo is! Map) continue;
    final content = todo['content'];
    if (content is! String || content.trim().isEmpty) continue;
    lines.add(
      '${index + 1}. [${_displayStatus(todo['status'])}] ${content.trim()}',
    );
  }

  if (lines.isEmpty) return null;
  return '$header\n${lines.join('\n')}';
}

String _inputStatus(String status) {
  return switch (status) {
    'in progress' => 'in_progress',
    'completed' => 'completed',
    _ => 'pending',
  };
}

String _displayStatus(Object? status) {
  return switch (status) {
    'in_progress' || 'inProgress' => 'in progress',
    'completed' => 'completed',
    _ => 'pending',
  };
}
