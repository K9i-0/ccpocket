import 'dart:async';

import '../models/messages.dart';

const pinnedSessionKeysPreferenceKey = 'session_list_pinned_session_keys_v1';
const pinnedProjectPathsPreferenceKey = 'session_list_pinned_project_paths_v1';

final _sessionOrderingChanges = StreamController<void>.broadcast(sync: true);

/// Emits after mobile pin preferences are persisted so companion surfaces can
/// immediately publish the same ordering.
Stream<void> get sessionOrderingChanges => _sessionOrderingChanges.stream;

void notifySessionOrderingChanged() => _sessionOrderingChanges.add(null);

String sessionPinKey({
  required String? provider,
  required String projectPath,
  required String sessionId,
}) => '${provider ?? Provider.claude.value}\n$projectPath\n$sessionId';

String recentSessionPinKey(RecentSession session) => sessionPinKey(
  provider: session.provider,
  projectPath: session.projectPath,
  sessionId: session.sessionId,
);

String? runningSessionPinKey(SessionInfo session) {
  final providerSessionId = session.claudeSessionId;
  if (providerSessionId == null || providerSessionId.isEmpty) return null;
  return sessionPinKey(
    provider: session.provider,
    projectPath: session.projectPath,
    sessionId: providerSessionId,
  );
}

/// Applies the stable priority buckets used by the mobile and Watch lists.
List<T> prioritizePinned<T>(
  Iterable<T> items, {
  required bool Function(T item) isPinned,
  bool Function(T item)? isProjectPinned,
}) {
  final pinned = <T>[];
  final pinnedProjects = <T>[];
  final others = <T>[];
  for (final item in items) {
    if (isPinned(item)) {
      pinned.add(item);
    } else if (isProjectPinned?.call(item) ?? false) {
      pinnedProjects.add(item);
    } else {
      others.add(item);
    }
  }
  return [...pinned, ...pinnedProjects, ...others];
}
