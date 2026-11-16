import '../../../services/bridge_service.dart';
import 'github_list_cubit.dart';

/// Keeps one [GitHubListCubit] per project so reopening the screen shows the
/// last lists immediately (like `GitViewCacheService`).
///
/// The same path can exist on several Bridge hosts, so the Bridge URL is part
/// of the key. Cubits stay alive across reconnects because a visible screen
/// may still be using them.
class GitHubViewCacheService {
  final BridgeService _bridge;
  final _cubits = <String, GitHubListCubit>{};

  GitHubViewCacheService({required BridgeService bridge}) : _bridge = bridge;

  /// Whether this cache serves [bridge]. Screens running against another
  /// instance (mock previews) keep their own state.
  bool serves(BridgeService bridge) => identical(bridge, _bridge);

  ({GitHubListCubit cubit, bool created}) getOrCreate(String projectPath) {
    final key = '${_bridge.lastUrl ?? ''}\n$projectPath';
    final existing = _cubits[key];
    if (existing != null && !existing.isClosed) {
      return (cubit: existing, created: false);
    }
    final cubit = GitHubListCubit(bridge: _bridge, projectPath: projectPath);
    _cubits[key] = cubit;
    return (cubit: cubit, created: true);
  }

  Future<void> dispose() async {
    final cubits = List.of(_cubits.values);
    _cubits.clear();
    for (final cubit in cubits) {
      await cubit.close();
    }
  }
}
