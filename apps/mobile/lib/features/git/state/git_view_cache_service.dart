import 'dart:async';

import '../../../services/bridge_service.dart';
import 'git_status_cubit.dart';
import 'git_view_cubit.dart';

class GitViewCacheLookup {
  final GitViewCubit cubit;
  final bool created;

  const GitViewCacheLookup({required this.cubit, required this.created});
}

class GitViewCacheService {
  final BridgeService _bridge;
  final GitStatusCubit _gitStatusCubit;
  final _cubitsBySession = <String, GitViewCubit>{};
  late final StreamSubscription<String> _stoppedSub;

  GitViewCacheService({
    required BridgeService bridge,
    required GitStatusCubit gitStatusCubit,
  }) : _bridge = bridge,
       _gitStatusCubit = gitStatusCubit {
    _stoppedSub = _bridge.stoppedSessions.listen(clearSession);
  }

  GitViewCacheLookup getOrCreate({
    required String sessionId,
    required String projectPath,
    String? worktreePath,
  }) {
    final existing = _cubitsBySession[sessionId];
    if (existing != null) {
      return GitViewCacheLookup(cubit: existing, created: false);
    }

    final cubit = GitViewCubit(
      bridge: _bridge,
      projectPath: projectPath,
      worktreePath: worktreePath,
      sessionId: sessionId,
      onStatusRefreshRequested: ({forceRemote = false}) =>
          _gitStatusCubit.refresh(
            sessionId: sessionId,
            projectPath: projectPath,
            forceRemote: forceRemote,
          ),
    );
    _cubitsBySession[sessionId] = cubit;
    _gitStatusCubit.refresh(sessionId: sessionId, projectPath: projectPath);
    return GitViewCacheLookup(cubit: cubit, created: true);
  }

  bool hasSession(String sessionId) => _cubitsBySession.containsKey(sessionId);

  void refreshIfPresent(String sessionId) {
    _cubitsBySession[sessionId]?.refreshAfterExternalChange();
  }

  Future<void> clearSession(String sessionId) async {
    final cubit = _cubitsBySession.remove(sessionId);
    await cubit?.close();
  }

  Future<void> dispose() async {
    await _stoppedSub.cancel();
    final cubits = List.of(_cubitsBySession.values);
    _cubitsBySession.clear();
    for (final cubit in cubits) {
      await cubit.close();
    }
  }
}
