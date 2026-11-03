import 'package:ccpocket/features/session_list/state/recent_session_filters.dart';
import 'package:ccpocket/features/session_list/state/session_list_state.dart';
import 'package:ccpocket/features/session_list/widgets/recent_session_filter_sheets.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<RecentAdvancedSearchResult?> openSheet(
    WidgetTester tester, {
    bool supported = true,
  }) async {
    RecentAdvancedSearchResult? result;
    tester.view.physicalSize = const Size(800, 2400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showRecentAdvancedSearch(
                  context: context,
                  searchQuery: '',
                  filters: const RecentSessionFilters(),
                  providerFilter: ProviderFilter.all,
                  providerOptions: ProviderFilter.values,
                  namedOnly: false,
                  supportsAdvancedFilters: supported,
                  projects: const [(key: '/w/a', name: 'a')],
                  favoriteProjects: const {},
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('advanced_search_query')),
      'needle',
    );
    final contentSwitch = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('advanced_search_content')),
    );
    if (supported) {
      expect(contentSwitch.onChanged, isNotNull);
      await tester.tap(find.byKey(const ValueKey('advanced_search_content')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('advanced_period_yesterday')));
      await tester.pumpAndSettle();
    } else {
      expect(contentSwitch.onChanged, isNull);
      expect(
        find.byKey(const ValueKey('advanced_period_yesterday')),
        findsNothing,
      );
    }
    await tester.tap(find.byKey(const ValueKey('advanced_search_apply')));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('advanced search returns the edited conditions', (tester) async {
    final result = await openSheet(tester);
    expect(result?.searchQuery, 'needle');
    expect(result?.filters.searchContent, isTrue);
    expect(
      result?.filters.dateFilter,
      const RecentDateFilter(RecentDatePreset.yesterday),
    );
  });

  testWidgets('keeps basic search available for older Bridges', (tester) async {
    final result = await openSheet(tester, supported: false);
    expect(result?.searchQuery, 'needle');
    expect(result?.filters.searchContent, isFalse);
    expect(result?.filters.dateFilter, isNull);
  });

  testWidgets('keyboard opens on tap only and closes on scroll', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showRecentAdvancedSearch(
                context: context,
                searchQuery: '',
                filters: const RecentSessionFilters(),
                providerFilter: ProviderFilter.all,
                providerOptions: ProviderFilter.values,
                namedOnly: false,
                supportsAdvancedFilters: true,
                projects: const [(key: '/w/a', name: 'a')],
                favoriteProjects: const {},
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    EditableText field() => tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey('advanced_search_query')),
        matching: find.byType(EditableText),
      ),
    );
    expect(field().focusNode.hasFocus, isFalse);

    await tester.tap(find.byKey(const ValueKey('advanced_search_query')));
    await tester.pumpAndSettle();
    expect(field().focusNode.hasFocus, isTrue);

    await tester.drag(
      find.byKey(const ValueKey('advanced_search_content')),
      const Offset(0, -100),
    );
    await tester.pumpAndSettle();
    expect(field().focusNode.hasFocus, isFalse);
  });
}
