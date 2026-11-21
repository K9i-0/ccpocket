import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/messages.dart';
import '../utils/codex_plan_update.dart';
import '../utils/network_endpoint.dart';

String bridgeTargetKey(Uri uri) {
  final scheme = uri.scheme.toLowerCase();
  final host = canonicalHostIdentity(uri.host);
  final port = uri.hasPort ? uri.port : (scheme == 'wss' ? 443 : 80);
  final path = uri.path.isEmpty ? '/' : uri.path;
  return '${formatUriOrigin(scheme: scheme, host: host, port: port)}$path';
}

int? readHistorySeq(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

bool isPersistableOfflineMessage(ClientMessage message) {
  return switch (message.type) {
    'input' ||
    'start' ||
    'resume_session' ||
    'rename_session' ||
    'update_queued_input' ||
    'cancel_queued_input' => true,
    _ => false,
  };
}

String? offlineMessageDedupeKey(ClientMessage message) {
  final json = jsonDecode(message.toJson()) as Map<String, dynamic>;
  return switch (message.type) {
    'input' when json['clientMessageId'] is String =>
      'input:${json['sessionId'] ?? ''}:${json['clientMessageId']}',
    'resume_session' =>
      'resume:${json['provider'] ?? 'claude'}:${json['sessionId']}',
    'start' => 'start:${canonicalJson(json)}',
    _ => null,
  };
}

String offlinePendingActionId(ClientMessage message) {
  final key =
      offlineMessageDedupeKey(message) ??
      canonicalJson(jsonDecode(message.toJson()) as Map<String, dynamic>);
  return base64Url.encode(utf8.encode(key)).replaceAll('=', '');
}

String canonicalJson(Object? value) {
  if (value is Map) {
    final normalized = <String, Object?>{};
    for (final key in value.keys.map((k) => k.toString()).toList()..sort()) {
      normalized[key] = canonicalValue(value[key]);
    }
    return jsonEncode(normalized);
  }
  return jsonEncode(canonicalValue(value));
}

Object? canonicalValue(Object? value) {
  if (value is Map) {
    return {
      for (final key in value.keys.map((k) => k.toString()).toList()..sort())
        key: canonicalValue(value[key]),
    };
  }
  if (value is List) {
    return value.map(canonicalValue).toList();
  }
  return value;
}

bool samePendingProjectPath(String a, String b) {
  String normalize(String value) {
    final trimmed = value.trim();
    if (trimmed == '/') return trimmed;
    return trimmed.replaceAll(RegExp(r'/+$'), '');
  }

  return normalize(a) == normalize(b);
}

bool compatiblePendingProjectPath(String a, String b) {
  if (samePendingProjectPath(a, b)) return true;

  String basename(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'/+$'), '');
    final parts = normalized.split('/').where((part) => part.isNotEmpty);
    return parts.isEmpty ? normalized : parts.last;
  }

  final left = basename(a);
  final right = basename(b);
  return left.isNotEmpty && left == right;
}

bool isSharedPreferencesUnavailable(Object error) {
  if (error is MissingPluginException) return true;
  final message = error.toString();
  return message.contains('Binding has not yet been initialized');
}

String recentSessionsScopeKey({
  required String requestScope,
  String? projectPath,
}) => requestScope == 'project' ? 'project:${projectPath ?? ''}' : 'list';

({String? projectPath, String? projectId, String? workspaceKind})
decodeWorkspaceFilter(String? filterKey) {
  if (filterKey == null) {
    return (projectPath: null, projectId: null, workspaceKind: null);
  }
  const projectPrefix = 'project:';
  if (filterKey.startsWith(projectPrefix) &&
      filterKey.length > projectPrefix.length) {
    return (
      projectPath: null,
      projectId: filterKey.substring(projectPrefix.length),
      workspaceKind: 'project',
    );
  }
  return (projectPath: filterKey, projectId: null, workspaceKind: null);
}

String? recentSessionsFilterKey({
  String? projectPath,
  String? projectId,
  String? workspaceKind,
}) {
  if (projectId != null && projectId.isNotEmpty) return 'project:$projectId';
  return projectPath;
}

String galleryScopeKey({
  required String? projectPath,
  required String? sessionId,
}) => jsonEncode([projectPath, sessionId]);

List<GalleryImage> prependGalleryImage(
  List<GalleryImage> images,
  GalleryImage image,
) => [image, ...images.where((existing) => existing.id != image.id)];

({String projectPath, String requestId})? resolvePendingProjectResponse({
  required String? responseProjectPath,
  required String? responseRequestId,
  required Map<String, String> pendingProjectsByRequestId,
  required Map<String, String> latestRequestIdsByProject,
}) {
  String? projectPath = responseProjectPath;
  String? acceptedRequestId = responseRequestId;
  if (responseRequestId != null) {
    final pendingProject = pendingProjectsByRequestId[responseRequestId];
    if (pendingProject == null ||
        (projectPath != null && projectPath != pendingProject) ||
        latestRequestIdsByProject[pendingProject] != responseRequestId) {
      return null;
    }
    projectPath = pendingProject;
  } else if (projectPath != null) {
    acceptedRequestId = latestRequestIdsByProject[projectPath];
    if (acceptedRequestId == null) return null;
  } else {
    if (pendingProjectsByRequestId.length != 1) return null;
    final pending = pendingProjectsByRequestId.entries.single;
    acceptedRequestId = pending.key;
    projectPath = pending.value;
  }
  final resolvedProjectPath = projectPath;
  final resolvedRequestId = acceptedRequestId;
  if (resolvedRequestId == null) return null;
  pendingProjectsByRequestId.remove(resolvedRequestId);
  if (latestRequestIdsByProject[resolvedProjectPath] == resolvedRequestId) {
    latestRequestIdsByProject.remove(resolvedProjectPath);
  }
  return (projectPath: resolvedProjectPath, requestId: resolvedRequestId);
}

String assistantContentPreviewText(AssistantContent content) {
  return switch (content) {
    TextContent(:final text) => text,
    ToolUseContent(:final name, :final input)
        when isCodexUpdatePlanTool(name) =>
      codexPlanUpdateTextFromInput(input) ?? '',
    _ => '',
  };
}

List<RecentSession> mergeRecentSessions(
  List<RecentSession> current,
  List<RecentSession> incoming,
) {
  if (current.isEmpty) return incoming;
  if (incoming.isEmpty) return current;
  final seen = current.map((session) => session.sessionId).toSet();
  final merged = List<RecentSession>.of(current);
  for (final session in incoming) {
    if (seen.add(session.sessionId)) {
      merged.add(session);
    }
  }
  return merged;
}

String diffImageCacheKey(String projectPath, String filePath) =>
    '$projectPath\n$filePath';
