import '../fixture_bridge.dart';

JsonMap recentSession(
  String id, {
  String provider = 'claude',
  String? name,
  String projectPath = '/work/app',
  String firstPrompt = '',
}) => {
  'sessionId': id,
  'provider': provider,
  'name': ?name,
  'firstPrompt': firstPrompt,
  'created': '2026-11-01T00:00:00Z',
  'modified': '2026-11-01T00:00:00Z',
  'gitBranch': 'main',
  'projectPath': projectPath,
};

/// Answers `list_recent_sessions` like the Bridge: filters by provider,
/// namedOnly and searchQuery, then pages with limit/offset.
FixtureHandler recentSessionsHandler(List<JsonMap> all) => (request) {
  final provider = request['provider'] as String?;
  final namedOnly = request['namedOnly'] == true;
  final query = (request['searchQuery'] as String?)?.toLowerCase();
  final matched = all.where((s) {
    if (provider != null && s['provider'] != provider) return false;
    if (namedOnly && s['name'] == null) return false;
    if (query != null) {
      final text = '${s['name'] ?? ''} ${s['firstPrompt']}'.toLowerCase();
      if (!text.contains(query)) return false;
    }
    return true;
  }).toList();
  final offset = request['offset'] as int? ?? 0;
  final limit = request['limit'] as int? ?? 20;
  final page = matched.skip(offset).take(limit).toList();
  return [
    {
      'type': 'recent_sessions',
      'sessions': page,
      'hasMore': offset + page.length < matched.length,
      'limit': limit,
      'offset': offset,
      'requestScope': request['requestScope'],
      'requestId': request['requestId'],
    },
  ];
};

/// Handlers for the requests [SessionListCubit.refresh] sends.
Map<String, FixtureHandler> sessionListFixture(List<JsonMap> recent) => {
  'list_sessions': (_) => [FixtureBridge.sessionListMessage()],
  'list_recent_sessions': recentSessionsHandler(recent),
  'list_project_history': (_) => [
    {'type': 'project_history', 'projects': <String>[]},
  ],
  'list_projects': (_) => [
    {'type': 'projects', 'projects': <Object>[]},
  ],
};
