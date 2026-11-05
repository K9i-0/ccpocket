import '../../../core/reflex/reflex_node.dart';
import 'session_list_cubit.dart';
import 'session_list_state.dart';

/// Reflex node for the recent-session list ([SessionListCubit]).
class SessionListReflexNode extends ReflexNode {
  SessionListReflexNode(this.cubit);

  final SessionListCubit cubit;

  @override
  String get name => 'session_list';

  @override
  Map<String, Object?> stateJson() {
    final s = cubit.state;
    final pinned = s.pinnedSessionKeys;
    return {
      'isInitialLoading': s.isInitialLoading,
      'isLoadingMore': s.isLoadingMore,
      'hasMore': s.hasMore,
      'providerFilter': s.providerFilter.name,
      'namedOnly': s.namedOnly,
      'searchQuery': s.searchQuery,
      'pinnedOnly': s.filters.pinnedOnly,
      'collapsedProjects': s.collapsedProjectPaths.toList()..sort(),
      'pinnedProjects': s.pinnedProjectPaths.toList()..sort(),
      'sessions': [
        for (final session in s.sessions)
          {
            'id': session.sessionId,
            'provider': session.provider,
            'name': session.name,
            'projectPath': session.projectPath,
            'pinned': pinned.contains(recentSessionPinKey(session)),
          },
      ],
    };
  }

  @override
  List<ReflexAction> get actions => const [
    ReflexAction('refresh', 'Reload running and recent sessions'),
    ReflexAction(
      'setProviderFilter',
      'Show only sessions of one provider',
      params: {'provider': 'enum(all|claude|codex)'},
    ),
    ReflexAction('toggleNamedOnly', 'Show only named sessions (toggle)'),
    ReflexAction(
      'setSearchQuery',
      'Search sessions (sent after a 300 ms debounce)',
      params: {'query': 'string'},
    ),
    ReflexAction('loadMore', 'Load the next page'),
    ReflexAction(
      'togglePinned',
      'Pin or unpin a recent session',
      params: {'sessionId': 'string'},
    ),
    ReflexAction(
      'toggleProjectCollapsed',
      'Collapse or expand a project group',
      params: {'projectPath': 'string'},
    ),
  ];

  @override
  Future<void> dispatch(
    String action, [
    Map<String, Object?> args = const {},
  ]) async {
    switch (action) {
      case 'refresh':
        cubit.refresh();
      case 'setProviderFilter':
        final raw = ReflexNode.stringArg(args, 'provider');
        final provider = ProviderFilter.values.where((p) => p.name == raw);
        if (provider.isEmpty) {
          throw ReflexException('Unknown provider "$raw"');
        }
        cubit.setProviderFilter(provider.first);
      case 'toggleNamedOnly':
        cubit.toggleNamedOnly();
      case 'setSearchQuery':
        cubit.setSearchQuery(ReflexNode.stringArg(args, 'query'));
      case 'loadMore':
        cubit.loadMore();
      case 'togglePinned':
        final id = ReflexNode.stringArg(args, 'sessionId');
        final session = cubit.state.sessions.where((s) => s.sessionId == id);
        if (session.isEmpty) {
          throw ReflexException('No visible session "$id"');
        }
        await cubit.toggleRecentSessionPinned(session.first);
      case 'toggleProjectCollapsed':
        cubit.toggleProjectCollapsed(ReflexNode.stringArg(args, 'projectPath'));
      default:
        throw ReflexException('Unknown action "$action" on $name');
    }
  }
}
