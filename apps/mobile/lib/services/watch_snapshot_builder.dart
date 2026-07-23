import 'dart:convert';

import '../models/messages.dart';
import '../utils/request_user_input.dart';

/// Builds the property-list-safe payload shared with the Apple Watch app.
///
/// Keep this class free of platform channels so the mapping and stale-action
/// safeguards can be covered by regular Flutter tests.
class WatchSnapshotBuilder {
  const WatchSnapshotBuilder._();

  static const _maxSessions = 6;
  static const _maxQuestions = 3;
  static const _maxOptions = 6;
  static const _knownStatuses = {
    'waiting_approval',
    'running',
    'starting',
    'compacting',
    'idle',
    'stopped',
  };

  static Map<String, Object?> build({
    required bool connected,
    required List<SessionInfo> sessions,
    String? bridgeUrl,
    UsageResultMessage? usage,
    DateTime? generatedAt,
  }) {
    final bridgeUri = bridgeUrl == null ? null : Uri.tryParse(bridgeUrl);
    final statusCounts = <String, int>{};
    for (final session in sessions) {
      final status = _normalizedStatus(session.status);
      statusCounts.update(status, (count) => count + 1, ifAbsent: () => 1);
    }
    return <String, Object?>{
      'schemaVersion': 1,
      'generatedAt': (generatedAt ?? DateTime.now()).toUtc().toIso8601String(),
      'connected': connected,
      if (bridgeUri != null && bridgeUri.host.isNotEmpty)
        'bridgeHost': _truncate(bridgeUri.host, 120),
      if (bridgeUri != null) 'bridgePort': _bridgePort(bridgeUri),
      'activeSessionCount': sessions.length,
      'statusCounts': statusCounts,
      // The caller supplies the same stable, pin-aware order as mobile.
      'sessions': sessions
          .take(_maxSessions)
          .map(_sessionPayload)
          .toList(growable: false),
      'usage':
          usage?.providers.map(_usagePayload).toList(growable: false) ??
          const <Object?>[],
    };
  }

  static int _bridgePort(Uri uri) {
    if (uri.hasPort) return uri.port;
    return switch (uri.scheme) {
      'wss' || 'https' => 443,
      _ => 80,
    };
  }

  /// Converts structured Watch answers into the Bridge protocol format.
  ///
  /// A single-select, single-question response remains a plain string for
  /// compatibility. Multi-question and multi-select responses use the same
  /// JSON envelope as the mobile AskUserQuestion UI.
  static String? buildAnswerResult({
    required PermissionRequestMessage permission,
    required Map<String, List<String>> answers,
  }) {
    final questions = requestUserInputQuestions(permission.input);
    if (questions.isEmpty) return null;

    final normalized = <String, dynamic>{};
    for (final (index, question) in questions.indexed) {
      final key = _questionKey(question);
      final values =
          (answers[_watchQuestionKey(index)] ?? answers[key])
              ?.map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .map((value) => _resolveWatchOption(question, value))
              .toList(growable: false) ??
          const <String>[];
      if (values.isEmpty) {
        if (question['required'] as bool? ?? true) return null;
        continue;
      }
      normalized[key] = question['multiSelect'] as bool? ?? false
          ? values
          : values.first;
    }

    if (questions.length == 1 &&
        !(questions.first['multiSelect'] as bool? ?? false) &&
        normalized.containsKey(_questionKey(questions.first))) {
      return normalized[_questionKey(questions.first)] as String?;
    }
    return jsonEncode({'questions': questions, 'answers': normalized});
  }

  static Map<String, Object?> _sessionPayload(SessionInfo session) {
    final permission = session.pendingPermission;
    final status = _normalizedStatus(session.status);
    return <String, Object?>{
      'id': session.id,
      'title': _truncate(_sessionTitle(session), 60),
      'hasCustomName': session.name?.trim().isNotEmpty ?? false,
      'project': _truncate(_basename(session.projectPath), 60),
      'branch': _truncate(session.gitBranch, 80),
      'provider': session.provider ?? 'claude',
      'status': status,
      'statusLabel': _statusLabel(status),
      'lastMessage': _truncate(session.lastMessage, 180),
      if (permission != null) 'permission': _permissionPayload(permission),
    };
  }

  static Map<String, Object?> _permissionPayload(
    PermissionRequestMessage permission,
  ) {
    final questions = requestUserInputQuestions(permission.input);
    final requiresPhone =
        questions.length > _maxQuestions ||
        questions.any((question) {
          final options = question['options'];
          return options is List && options.length > _maxOptions;
        });
    return <String, Object?>{
      'toolUseId': permission.toolUseId,
      'kind': permission.usesAskUserUi ? 'question' : 'approval',
      'title': _truncate(permission.presentation.title, 80),
      'summary': _truncate(permission.presentation.summary, 240),
      'canApprove': permission.canApprove,
      'canReject': permission.canDecline,
      'allowsCustomInput':
          permission.usesAskUserUi && !permission.isQuestionApproval,
      'requiresPhone': requiresPhone,
      'questions': questions
          .take(_maxQuestions)
          .indexed
          .map((entry) => _questionPayload(entry.$2, entry.$1))
          .toList(growable: false),
    };
  }

  static Map<String, Object?> _questionPayload(
    Map<String, dynamic> question,
    int questionIndex,
  ) {
    final options =
        question['options'] as List<Map<String, dynamic>>? ??
        const <Map<String, dynamic>>[];
    return <String, Object?>{
      'key': _watchQuestionKey(questionIndex),
      'header': _truncate(question['header'] as String? ?? '', 40),
      'text': _truncate(question['question'] as String? ?? '', 180),
      'multiSelect': question['multiSelect'] as bool? ?? false,
      'required': question['required'] as bool? ?? true,
      'options': options
          .take(_maxOptions)
          .indexed
          .map(
            (entry) => <String, Object?>{
              'value': _watchOptionValue(entry.$1),
              'label': _truncate(entry.$2['label'] as String? ?? '', 80),
              'description': _truncate(
                entry.$2['description'] as String? ?? '',
                120,
              ),
            },
          )
          .toList(growable: false),
    };
  }

  static String _questionKey(Map<String, dynamic> question) =>
      question['id'] as String? ?? question['question'] as String? ?? '';

  static String _watchQuestionKey(int index) => 'q:$index';

  static String _watchOptionValue(int index) => 'option:$index';

  static String _resolveWatchOption(
    Map<String, dynamic> question,
    String value,
  ) {
    if (!value.startsWith('option:')) return value;
    final index = int.tryParse(value.substring('option:'.length));
    final options = question['options'];
    if (index == null ||
        options is! List ||
        index < 0 ||
        index >= options.length) {
      return value;
    }
    final option = options[index];
    return option is Map && option['label'] is String
        ? option['label'] as String
        : value;
  }

  static String _truncate(String value, int maxBytes) {
    if (utf8.encode(value).length <= maxBytes) return value;
    final buffer = StringBuffer();
    var byteCount = utf8.encode('…').length;
    for (final rune in value.runes) {
      final character = String.fromCharCode(rune);
      final characterBytes = utf8.encode(character).length;
      if (byteCount + characterBytes > maxBytes) break;
      buffer.write(character);
      byteCount += characterBytes;
    }
    return '$buffer…';
  }

  static Map<String, Object?> _usagePayload(
    UsageInfo info,
  ) => <String, Object?>{
    'provider': _truncate(info.provider, 20),
    if (info.error != null) 'error': _truncate(info.error!, 160),
    if (info.fiveHour != null) 'fiveHour': _usageWindowPayload(info.fiveHour!),
    if (info.sevenDay != null) 'sevenDay': _usageWindowPayload(info.sevenDay!),
  };

  static Map<String, Object?> _usageWindowPayload(UsageWindow window) =>
      <String, Object?>{
        'remaining': (100 - window.utilization.clamp(0, 100)) / 100,
        'resetsAt': _truncate(window.resetsAt, 64),
      };

  static String _sessionTitle(SessionInfo session) {
    final name = session.name?.trim();
    if (name != null && name.isNotEmpty) return name;
    final project = _basename(session.projectPath);
    return project.isEmpty ? 'Session' : project;
  }

  static String _basename(String path) {
    final parts = path.split(RegExp(r'[/\\]'));
    return parts.where((part) => part.isNotEmpty).lastOrNull ?? path;
  }

  static String _normalizedStatus(String status) =>
      _knownStatuses.contains(status) ? status : 'other';

  static String _statusLabel(String status) => switch (status) {
    'waiting_approval' => 'Needs You',
    'running' || 'starting' || 'compacting' => 'Working',
    'idle' || 'stopped' || 'other' => 'Ready',
    _ => status.replaceAll('_', ' '),
  };
}
