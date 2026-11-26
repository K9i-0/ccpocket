import 'dart:async';

import 'package:ccpocket/features/session_list/state/session_list_cubit.dart';
import 'package:ccpocket/features/session_list/state/session_list_state.dart';
import 'package:ccpocket/features/session_list/widgets/home_content.dart';
import 'package:ccpocket/features/session_list/widgets/machine_card.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/l10n/app_localizations_delegates.dart';
import 'package:ccpocket/models/machine.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:ccpocket/services/draft_service.dart';
import 'package:ccpocket/services/in_app_review_service.dart';
import 'package:ccpocket/services/revenuecat_service.dart';
import 'package:ccpocket/services/support_banner_service.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/bridge_version_test_values.dart';

class _MockBridgeService extends BridgeService {
  final _recentSessionsController =
      StreamController<List<RecentSession>>.broadcast();
  final _projectHistoryController = StreamController<List<String>>.broadcast();

  @override
  Stream<List<RecentSession>> get recentSessionsStream =>
      _recentSessionsController.stream;

  @override
  Stream<List<String>> get projectHistoryStream =>
      _projectHistoryController.stream;

  @override
  bool get recentSessionsHasMore => false;

  @override
  String? get currentProjectFilter => null;

  @override
  void switchProjectFilter(String? projectPath, {int pageSize = 20}) {}

  @override
  void requestSessionList() {}

  @override
  void requestRecentSessions({int? limit, int? offset, String? projectPath}) {}

  @override
  void requestProjectHistory() {}

  @override
  void send(ClientMessage message) {}

  @override
  void dispose() {
    _recentSessionsController.close();
    _projectHistoryController.close();
  }
}

Widget _wrapApp(Widget child, {ThemeData? theme}) {
  return MaterialApp(
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    theme: theme ?? AppTheme.lightTheme,
    home: Scaffold(body: child),
  );
}

Machine _sampleMachine({
  bool sshEnabled = true,
  String? sshUsername = 'dev',
  bool isFavorite = false,
}) {
  return Machine(
    id: 'm1',
    name: 'Studio Mac',
    host: '100.64.0.10',
    sshEnabled: sshEnabled,
    sshUsername: sshUsername,
    hasCredentials: sshEnabled && sshUsername != null,
    isFavorite: isFavorite,
  );
}

RecentSession _sampleSession({
  required String id,
  String projectPath = '/Users/dev/workspace/ccpocket',
}) {
  return RecentSession(
    sessionId: id,
    firstPrompt: 'Implement desktop polish $id',
    created: '2026-01-01T00:00:00Z',
    modified: '2026-01-01T00:00:00Z',
    gitBranch: 'main',
    projectPath: projectPath,
    isSidechain: false,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppTheme desktop scrollbar and tooltip styling', () {
    for (final entry in <(String, ThemeData Function())>[
      ('lightTheme', () => AppTheme.lightTheme),
      ('darkTheme', () => AppTheme.darkTheme),
    ]) {
      final name = entry.$1;
      final buildTheme = entry.$2;

      test('$name configures macOS-friendly ScrollbarThemeData', () {
        final theme = buildTheme();
        final scrollbar = theme.scrollbarTheme;
        expect(scrollbar.interactive, isTrue);
        expect(scrollbar.radius, const Radius.circular(4));
        expect(scrollbar.crossAxisMargin, 2);
        expect(scrollbar.mainAxisMargin, 4);
        expect(scrollbar.minThumbLength, 32);

        // Thin width at rest (~6px), slightly wider on hover/drag.
        expect(scrollbar.thickness?.resolve(const <WidgetState>{}), 6.0);
        expect(scrollbar.thickness?.resolve(const {WidgetState.hovered}), 8.0);
        expect(scrollbar.thickness?.resolve(const {WidgetState.dragged}), 8.0);

        // Subtle translucency at rest that brightens on hover and drag.
        final idleColor = scrollbar.thumbColor?.resolve(const <WidgetState>{});
        final hoveredColor = scrollbar.thumbColor?.resolve(const {
          WidgetState.hovered,
        });
        final draggedColor = scrollbar.thumbColor?.resolve(const {
          WidgetState.dragged,
        });
        expect(idleColor, isNotNull);
        expect(hoveredColor, isNotNull);
        expect(draggedColor, isNotNull);
        expect(idleColor!.a, lessThan(hoveredColor!.a));
        expect(hoveredColor.a, lessThan(draggedColor!.a));

        expect(
          scrollbar.trackBorderColor?.resolve(const <WidgetState>{}),
          Colors.transparent,
        );
        expect(
          scrollbar.trackColor?.resolve(const <WidgetState>{}),
          Colors.transparent,
        );
      });

      test('$name configures crisp TooltipThemeData', () {
        final theme = buildTheme();
        final tooltip = theme.tooltipTheme;
        expect(tooltip.waitDuration, const Duration(milliseconds: 450));
        expect(tooltip.decoration, isA<BoxDecoration>());
        final decoration = tooltip.decoration! as BoxDecoration;
        expect(decoration.borderRadius, BorderRadius.circular(8));
        expect(tooltip.textStyle?.color, Colors.white);
      });
    }
  });

  group('MachineCard right-click context menu', () {
    testWidgets(
      'right-click opens context menu and triggers online machine callbacks',
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
      (tester) async {
        var connectCount = 0;
        var favoriteCount = 0;
        var editCount = 0;
        var updateCount = 0;
        var stopCount = 0;
        var deleteCount = 0;

        await tester.pumpWidget(
          _wrapApp(
            MachineCard(
              machineWithStatus: MachineWithStatus(
                machine: _sampleMachine(),
                status: MachineStatus.online,
                versionInfo: BridgeVersionInfo(
                  version: olderThanRecommendedBridgeVersion,
                ),
              ),
              onConnect: () => connectCount++,
              onStart: () {},
              onToggleFavorite: () => favoriteCount++,
              onEdit: () => editCount++,
              onUpdate: () => updateCount++,
              onStop: () => stopCount++,
              onDelete: () => deleteCount++,
            ),
          ),
        );
        await tester.pumpAndSettle();

        Future<void> rightClickAndTap(Key itemKey) async {
          await tester.tapAt(
            tester.getCenter(find.text('Studio Mac')),
            buttons: kSecondaryMouseButton,
          );
          await tester.pumpAndSettle();
          expect(find.byKey(itemKey), findsOneWidget);
          await tester.tap(find.byKey(itemKey));
          await tester.pumpAndSettle();
        }

        await rightClickAndTap(const ValueKey('machine_context_connect'));
        expect(connectCount, 1);

        await rightClickAndTap(const ValueKey('machine_context_favorite'));
        expect(favoriteCount, 1);

        await rightClickAndTap(const ValueKey('machine_context_edit'));
        expect(editCount, 1);

        await rightClickAndTap(const ValueKey('machine_context_update'));
        expect(updateCount, 1);

        await rightClickAndTap(const ValueKey('machine_context_stop'));
        expect(stopCount, 1);

        await rightClickAndTap(const ValueKey('machine_context_delete'));
        expect(deleteCount, 1);
      },
    );

    testWidgets(
      'right-click on offline SSH machine shows Start and hides online-only items',
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
      (tester) async {
        var startCount = 0;

        await tester.pumpWidget(
          _wrapApp(
            MachineCard(
              machineWithStatus: MachineWithStatus(
                machine: _sampleMachine(isFavorite: true),
                status: MachineStatus.offline,
              ),
              onConnect: () {},
              onStart: () => startCount++,
              onToggleFavorite: () {},
              onEdit: () {},
              onUpdate: () {},
              onStop: () {},
              onDelete: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tapAt(
          tester.getCenter(find.text('Studio Mac')),
          buttons: kSecondaryMouseButton,
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('machine_context_connect')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('machine_context_update')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('machine_context_stop')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('machine_context_start')),
          findsOneWidget,
        );
        expect(find.text('Unfavorite'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('machine_context_start')));
        await tester.pumpAndSettle();
        expect(startCount, 1);
      },
    );
  });

  group('HomeContent project header context menu and desktop tooltips', () {
    late _MockBridgeService mockBridge;
    late SessionListCubit cubit;
    late DraftService draftService;
    late RevenueCatService revenueCatService;
    late SupportBannerService supportBannerService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      draftService = DraftService(prefs);
      revenueCatService = RevenueCatService(
        publicApiKey: '',
        platform: TargetPlatform.macOS,
      );
      supportBannerService = SupportBannerService(
        prefs: prefs,
        reviewService: InAppReviewService(
          prefs: prefs,
          appVersionLoader: () async => '1.0.0',
        ),
      );
      mockBridge = _MockBridgeService();
      cubit = SessionListCubit(bridge: mockBridge);
    });

    tearDown(() async {
      await cubit.close();
      mockBridge.dispose();
      await revenueCatService.dispose();
    });

    Widget buildHome({
      Set<String> collapsedProjectPaths = const {},
      Set<String> pinnedProjectPaths = const {},
      VoidCallback? onNewSession,
      ValueChanged<String?>? onSelectProject,
      ValueChanged<String>? onToggleProjectCollapsed,
      ValueChanged<String>? onToggleProjectPinned,
      ValueChanged<RecentSession>? onOpenProjectGitHub,
    }) {
      return MultiRepositoryProvider(
        providers: [
          RepositoryProvider<DraftService>.value(value: draftService),
          RepositoryProvider<RevenueCatService>.value(value: revenueCatService),
          RepositoryProvider<SupportBannerService>.value(
            value: supportBannerService,
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: BlocProvider<SessionListCubit>.value(
              value: cubit,
              child: HomeContent(
                connectionState: BridgeConnectionState.connected,
                sessions: const [],
                recentSessions: [_sampleSession(id: 's1')],
                accumulatedProjectPaths: const {
                  '/Users/dev/workspace/ccpocket',
                },
                collapsedProjectPaths: collapsedProjectPaths,
                pinnedProjectPaths: pinnedProjectPaths,
                searchQuery: '',
                isLoadingMore: false,
                isInitialLoading: false,
                hasMoreSessions: false,
                currentProjectFilter: null,
                onNewSession: onNewSession ?? () {},
                onTapRunning: (
                  id, {
                  projectPath,
                  workspace,
                  gitBranch,
                  worktreePath,
                  provider,
                  permissionMode,
                  sandboxMode,
                  approvalPolicy,
                  approvalsReviewer,
                }) {},
                onStopSession: (_) {},
                onResumeSession: (_) {},
                onLongPressRecentSession: (_, _) {},
                onArchiveSession: (_) {},
                onLongPressRunningSession: (_, _) {},
                onSelectProject: onSelectProject ?? (_) {},
                onLoadMore: () {},
                onToggleProjectCollapsed: onToggleProjectCollapsed,
                onToggleProjectPinned: onToggleProjectPinned,
                onOpenProjectGitHub: onOpenProjectGitHub,
                providerFilter: ProviderFilter.all,
                namedOnly: false,
                onToggleProvider: () {},
                onToggleNamed: () {},
              ),
            ),
          ),
        ),
      );
    }

    testWidgets(
      'right-clicking project header triggers contextual actions and copies path',
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
      (tester) async {
        const projectPath = '/Users/dev/workspace/ccpocket';
        var newSessionCount = 0;
        String? toggledCollapsedKey;
        String? toggledPinnedKey;
        String? filteredProjectKey;
        RecentSession? openedGitHubSession;
        String? copiedClipboardText;

        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              final args = call.arguments as Map<dynamic, dynamic>;
              copiedClipboardText = args['text'] as String?;
            }
            return null;
          },
        );
        addTearDown(() {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          );
        });

        await tester.pumpWidget(
          buildHome(
            onNewSession: () => newSessionCount++,
            onSelectProject: (key) => filteredProjectKey = key,
            onToggleProjectCollapsed: (key) => toggledCollapsedKey = key,
            onToggleProjectPinned: (key) => toggledPinnedKey = key,
            onOpenProjectGitHub: (session) => openedGitHubSession = session,
          ),
        );
        await tester.pumpAndSettle();

        final headerFinder = find.byKey(
          const ValueKey('project_header_$projectPath'),
        );
        expect(headerFinder, findsOneWidget);

        Future<void> rightClickHeaderAndTap(Key itemKey) async {
          await tester.tapAt(
            tester.getCenter(headerFinder),
            buttons: kSecondaryMouseButton,
          );
          await tester.pumpAndSettle();
          expect(find.byKey(itemKey), findsOneWidget);
          await tester.tap(find.byKey(itemKey));
          await tester.pumpAndSettle();
        }

        await rightClickHeaderAndTap(
          const ValueKey('project_context_new_session'),
        );
        expect(newSessionCount, 1);

        await rightClickHeaderAndTap(
          const ValueKey('project_context_toggle_collapse'),
        );
        expect(toggledCollapsedKey, projectPath);

        await rightClickHeaderAndTap(const ValueKey('project_context_filter'));
        expect(filteredProjectKey, projectPath);

        await rightClickHeaderAndTap(
          const ValueKey('project_context_toggle_pin'),
        );
        expect(toggledPinnedKey, projectPath);

        await rightClickHeaderAndTap(const ValueKey('project_context_github'));
        expect(openedGitHubSession?.sessionId, 's1');

        await rightClickHeaderAndTap(
          const ValueKey('project_context_copy_path'),
        );
        expect(copiedClipboardText, projectPath);
      },
    );

    testWidgets(
      'shows desktop shortcut hint tooltips and full project path tooltip on desktop',
      (tester) async {
        const projectPath = '/Users/dev/workspace/ccpocket';

        try {
          debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
          await tester.pumpWidget(buildHome());
          await tester.pumpAndSettle();

          final macSearchButton = tester.widget<IconButton>(
            find.byKey(const ValueKey('search_button')),
          );
          expect(macSearchButton.tooltip, 'Search (⌘K)');

          final pathTooltip = find.byWidgetPredicate(
            (widget) => widget is Tooltip && widget.message == projectPath,
          );
          expect(pathTooltip, findsOneWidget);

          final headerMouseRegion = find.ancestor(
            of: find.byKey(const ValueKey('project_header_$projectPath')),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is MouseRegion &&
                  widget.cursor == SystemMouseCursors.click,
            ),
          );
          expect(headerMouseRegion, findsWidgets);

          // Verify non-macOS desktop uses Ctrl+K.
          debugDefaultTargetPlatformOverride = TargetPlatform.linux;
          await tester.pumpWidget(buildHome());
          await tester.pumpAndSettle();
          final linuxSearchButton = tester.widget<IconButton>(
            find.byKey(const ValueKey('search_button')),
          );
          expect(linuxSearchButton.tooltip, 'Search (Ctrl+K)');

          // Verify mobile omits desktop shortcut hint.
          debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
          await tester.pumpWidget(buildHome());
          await tester.pumpAndSettle();
          final mobileSearchButton = tester.widget<IconButton>(
            find.byKey(const ValueKey('search_button')),
          );
          expect(mobileSearchButton.tooltip, 'Search');
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  });
}
