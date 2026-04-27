import 'dart:async';

import 'package:ccpocket/features/session_list/state/session_list_cubit.dart';
import 'package:ccpocket/features/session_list/state/session_list_state.dart';
import 'package:ccpocket/features/session_list/widgets/home_content.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:ccpocket/services/draft_service.dart';
import 'package:ccpocket/services/in_app_review_service.dart';
import 'package:ccpocket/services/revenuecat_service.dart';
import 'package:ccpocket/services/support_banner_service.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class _FakeRevenueCatService extends RevenueCatService {
  _FakeRevenueCatService({required SupportCatalogState catalog})
    : super(publicApiKey: '', platform: TargetPlatform.iOS) {
    catalogState.value = catalog;
  }
}

RecentSession _session({required String id}) {
  return RecentSession(
    sessionId: id,
    firstPrompt: 'test prompt for $id',
    created: '2025-01-01T00:00:00Z',
    modified: '2025-01-01T00:00:00Z',
    gitBranch: 'main',
    projectPath: '/home/user/project-a',
    isSidechain: false,
  );
}

Widget _buildHomeContent({
  required SessionListCubit cubit,
  required DraftService draftService,
  required RevenueCatService revenueCatService,
  required SupportBannerService supportBannerService,
  String? bridgeVersion,
}) {
  return MultiRepositoryProvider(
    providers: [
      RepositoryProvider<DraftService>.value(value: draftService),
      RepositoryProvider<RevenueCatService>.value(value: revenueCatService),
      ChangeNotifierProvider<SupportBannerService>.value(
        value: supportBannerService,
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ja'),
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: BlocProvider<SessionListCubit>.value(
          value: cubit,
          child: HomeContent(
            connectionState: BridgeConnectionState.connected,
            bridgeVersion: bridgeVersion,
            sessions: const [],
            recentSessions: [_session(id: 's1')],
            accumulatedProjectPaths: const {},
            searchQuery: '',
            isLoadingMore: false,
            isInitialLoading: false,
            hasMoreSessions: false,
            currentProjectFilter: null,
            onNewSession: () {},
            onTapRunning:
                (
                  id, {
                  projectPath,
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
            onSelectProject: (_) {},
            onLoadMore: () {},
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

void main() {
  late _MockBridgeService mockBridge;
  late SessionListCubit cubit;
  late DraftService draftService;
  late SharedPreferences prefs;

  setUp(() async {
    final now = DateTime(2026, 4, 15, 12);
    SharedPreferences.setMockInitialValues({
      'review.first_seen_at_ms': now
          .subtract(const Duration(days: 5))
          .millisecondsSinceEpoch,
      'review.successful_connections': 3,
      'review.created_sessions': 3,
      'review.approval_actions': 5,
      'review.usage_days': const ['2026-04-13', '2026-04-15'],
    });
    prefs = await SharedPreferences.getInstance();
    draftService = DraftService(prefs);
    mockBridge = _MockBridgeService();
    cubit = SessionListCubit(bridge: mockBridge);
  });

  tearDown(() {
    cubit.close();
    mockBridge.dispose();
  });

  testWidgets('shows support banner when eligible and no bridge update', (
    tester,
  ) async {
    final reviewService = InAppReviewService(
      prefs: prefs,
      now: () => DateTime(2026, 4, 15, 12),
      appVersionLoader: () async => '1.50.0',
    );
    final supportBannerService = SupportBannerService(
      prefs: prefs,
      reviewService: reviewService,
    );

    await tester.pumpWidget(
      _buildHomeContent(
        cubit: cubit,
        draftService: draftService,
        revenueCatService: _FakeRevenueCatService(catalog: _inactiveCatalog),
        supportBannerService: supportBannerService,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('support_banner')), findsOneWidget);
    expect(find.text('CC Pocketが役に立っていたら'), findsOneWidget);
  });

  testWidgets('hides support banner when bridge update banner is visible', (
    tester,
  ) async {
    final reviewService = InAppReviewService(
      prefs: prefs,
      now: () => DateTime(2026, 4, 15, 12),
      appVersionLoader: () async => '1.50.0',
    );
    final supportBannerService = SupportBannerService(
      prefs: prefs,
      reviewService: reviewService,
    );

    await tester.pumpWidget(
      _buildHomeContent(
        cubit: cubit,
        draftService: draftService,
        revenueCatService: _FakeRevenueCatService(catalog: _inactiveCatalog),
        supportBannerService: supportBannerService,
        bridgeVersion: '0.1.0',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('support_banner')), findsNothing);
    expect(find.textContaining('Bridge Server v0.1.0'), findsOneWidget);
  });
}

const _inactiveCatalog = SupportCatalogState(
  isAvailable: true,
  isLoading: false,
  isSupporter: false,
  packages: [
    SupportPackage(
      id: r'$rc_monthly',
      productId: 'supporter_monthly_10',
      title: 'Supporter',
      priceLabel: '\$9.99',
      kind: SupportPackageKind.monthly,
    ),
  ],
);
