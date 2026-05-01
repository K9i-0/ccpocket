import 'package:ccpocket/features/prompt_history/widgets/prompt_history_sheet.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/services/database_service.dart';
import 'package:ccpocket/services/prompt_history_service.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('does not implicitly filter to the open project', (tester) async {
    final service = _FakePromptHistoryService(
      defaultFilters: const PromptHistoryFilters(),
      entries: [
        _entry(id: 'current', text: 'current prompt', projectPath: '/repo/a'),
        _entry(id: 'other', text: 'other prompt', projectPath: '/repo/b'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PromptHistorySheet(
            service: service,
            currentProjectPath: '/repo/a',
            onSelect: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(service.lastProjectPath, isNull);
    expect(service.projectPathsRequestCount, 0);
    expect(find.text('current prompt'), findsOneWidget);
    expect(find.text('other prompt'), findsOneWidget);
    expect(find.text('All'), findsNothing);
  });

  testWidgets('restores expanded filter controls preference', (tester) async {
    final service = _FakePromptHistoryService(
      defaultFilters: const PromptHistoryFilters(),
      filtersExpanded: true,
      entries: [
        _entry(id: 'current', text: 'current prompt', projectPath: '/repo/a'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PromptHistorySheet(
            service: service,
            currentProjectPath: '/repo/a',
            onSelect: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('prompt_history_self_filter_chip')),
      findsOneWidget,
    );
  });

  testWidgets('persists expanded filter controls preference', (tester) async {
    final service = _FakePromptHistoryService(
      defaultFilters: const PromptHistoryFilters(),
      entries: [
        _entry(id: 'current', text: 'current prompt', projectPath: '/repo/a'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PromptHistorySheet(
            service: service,
            currentProjectPath: '/repo/a',
            onSelect: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('prompt_history_filter_button')),
    );
    await tester.pumpAndSettle();

    expect(service.lastFiltersExpanded, isTrue);
    expect(
      find.byKey(const ValueKey('prompt_history_self_filter_chip')),
      findsOneWidget,
    );
  });

  testWidgets('filters to the open project when persisted filter is on', (
    tester,
  ) async {
    final service = _FakePromptHistoryService(
      defaultFilters: const PromptHistoryFilters(currentProjectOnly: true),
      entries: [
        _entry(id: 'current', text: 'current prompt', projectPath: '/repo/a'),
        _entry(id: 'other', text: 'other prompt', projectPath: '/repo/b'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PromptHistorySheet(
            service: service,
            currentProjectPath: '/repo/a',
            onSelect: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(service.lastProjectPath, isNull);
    expect(find.text('current prompt'), findsOneWidget);
    expect(find.text('other prompt'), findsNothing);
  });

  testWidgets('hides project labels in history rows', (tester) async {
    final service = _FakePromptHistoryService(
      defaultFilters: const PromptHistoryFilters(),
      entries: [
        _entry(
          id: 'current',
          text: 'current prompt',
          projectPath: '/repo/alpha-project',
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PromptHistorySheet(
            service: service,
            currentProjectPath: '/repo/alpha-project',
            onSelect: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('current prompt'), findsOneWidget);
    expect(find.text('alpha-project'), findsNothing);
  });

  testWidgets('shows open project hint when project filter has no results', (
    tester,
  ) async {
    final service = _FakePromptHistoryService(
      defaultFilters: const PromptHistoryFilters(currentProjectOnly: true),
      entries: [_entry(id: 'old', text: 'old prompt', projectPath: '')],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PromptHistorySheet(
            service: service,
            currentProjectPath: '/repo/a',
            onSelect: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('old prompt'), findsNothing);
    expect(
      find.byKey(const ValueKey('prompt_history_open_project_empty_hint')),
      findsOneWidget,
    );
  });
}

class _FakePromptHistoryService extends PromptHistoryService {
  final PromptHistoryFilters defaultFilters;
  final bool filtersExpanded;
  final List<PromptHistoryEntry> entries;

  String? lastProjectPath;
  PromptHistoryFilters? lastFilters;
  bool? lastFiltersExpanded;
  int projectPathsRequestCount = 0;

  _FakePromptHistoryService({
    required this.defaultFilters,
    this.filtersExpanded = false,
    required this.entries,
  }) : super(DatabaseService());

  @override
  Future<PromptHistoryFilters> getDefaultFilters() async => defaultFilters;

  @override
  Future<void> setDefaultFilters(PromptHistoryFilters filters) async {}

  @override
  Future<bool> getFiltersExpanded() async => filtersExpanded;

  @override
  Future<void> setFiltersExpanded(bool value) async {
    lastFiltersExpanded = value;
  }

  @override
  Future<List<String>> getProjectPaths() async {
    projectPathsRequestCount += 1;
    return entries.map((entry) => entry.projectPath).toSet().toList();
  }

  @override
  Future<List<PromptHistoryEntry>> getPrompts({
    PromptSortOrder sort = PromptSortOrder.recency,
    String? projectPath,
    PromptHistoryFilters filters = const PromptHistoryFilters(),
    String? currentSessionId,
    String? currentProjectPath,
    String? currentBridgeId,
    int limit = 30,
    int offset = 0,
  }) async {
    lastProjectPath = projectPath;
    lastFilters = filters;
    return entries
        .where(
          (entry) => PromptHistoryService.matchesFilters(
            entry,
            projectPath: projectPath,
            filters: filters,
            clientId: 'phone',
            currentProjectPath: currentProjectPath,
            currentBridgeId: currentBridgeId,
          ),
        )
        .skip(offset)
        .take(limit)
        .toList();
  }
}

PromptHistoryEntry _entry({
  required String id,
  required String text,
  required String projectPath,
}) {
  return PromptHistoryEntry(
    id: id,
    text: text,
    projectPath: projectPath,
    useCount: 1,
    isFavorite: false,
    createdAt: DateTime.utc(2026),
    lastUsedAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    commandKind: 'none',
    bridgeIds: const ['bridge-a'],
    bridgeNames: const ['Bridge A'],
    clientStats: const {},
    sessionStats: const {},
  );
}
