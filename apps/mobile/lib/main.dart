/// ccpocket - Claude Code Mobile Client
///
/// This is the main entry point for the ccpocket Flutter application.
///
/// Key responsibilities:
/// - Initializes Marionette binding for E2E testing in debug mode
/// - Sets up global error handling
/// - Initializes core services (BridgeService, DatabaseService, NotificationService, etc.)
/// - Configures repository and Bloc providers for state management
/// - Handles deep links for connection URLs and session navigation
///
/// Note: This file has been verified for Plan Mode workflow testing.
library;

import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:talker_bloc_logger/talker_bloc_logger.dart';

import 'core/logger.dart';
import 'l10n/app_localizations.dart';
import 'features/session_list/state/session_list_cubit.dart';
import 'features/settings/state/settings_cubit.dart';
import 'features/settings/state/settings_state.dart';
import 'models/messages.dart';
import 'providers/bridge_cubits.dart';
import 'providers/machine_manager_cubit.dart';
import 'providers/server_discovery_cubit.dart';
import 'router/app_router.dart';
import 'router/session_route_observer.dart';
import 'services/bridge_service.dart';
import 'services/connection_url_parser.dart';
import 'services/database_service.dart';
import 'services/draft_service.dart';
import 'services/machine_manager_service.dart';
import 'services/notification_service.dart';
import 'services/prompt_history_service.dart';
import 'services/ssh_startup_service.dart';
import 'theme/app_theme.dart';
import 'theme/markdown_style.dart';

/// Top-level handler for FCM background messages.
/// Required by firebase_messaging to process messages when app is in background.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // No-op: FCM notification messages are automatically displayed by the OS.
  // This handler is registered to prevent the "no onBackgroundMessage handler"
  // warning on Android.
}

/// Checks for Shorebird patches using the user-selected update track.
Future<void> _checkShorebirdUpdate(SharedPreferences prefs) async {
  try {
    final updater = ShorebirdUpdater();
    final trackName =
        prefs.getString(SettingsCubit.keyShorebirdTrack) ?? 'stable';
    final track = UpdateTrack(trackName);
    final status = await updater.checkForUpdate(track: track);
    if (status == UpdateStatus.outdated) {
      await updater.update(track: track);
      logger.info('[shorebird] Patch downloaded (track: $trackName)');
    }
  } catch (e) {
    logger.warning('[shorebird] Update check failed: $e');
  }
}

void main() async {
  if (kDebugMode && !kIsWeb) {
    MarionetteBinding.ensureInitialized();
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }
  Bloc.observer = TalkerBlocObserver(talker: logger);

  FlutterError.onError = (details) {
    logger.error(
      '[FlutterError] ${details.exceptionAsString()}',
      details.exception,
      details.stack,
    );
  };
  // Register FCM background message handler (must be before any FCM usage)
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  // Initialize notifications eagerly so the Android notification channel is
  // created before any FCM message arrives. Without this, FCM falls back to
  // the low-importance fcm_fallback_notification_channel and notifications
  // appear only in the history drawer instead of as heads-up popups.
  try {
    await NotificationService.instance.init();
  } catch (e) {
    logger.error('[main] NotificationService init failed', e);
  }
  try {
    await initializeMarkdownSyntaxHighlight();
  } catch (e) {
    logger.error('[main] syntax_highlight init failed', e);
  }

  // Initialize SharedPreferences and services
  final prefs = await SharedPreferences.getInstance();
  const secureStorage = FlutterSecureStorage();
  final machineManagerService = MachineManagerService(prefs, secureStorage);
  // SSH is only supported on native platforms (not web)
  final sshStartupService = kIsWeb
      ? null
      : SshStartupService(machineManagerService);

  // Shorebird manual update check (auto_update is disabled in shorebird.yaml).
  // Reads the user-selected track from SharedPreferences and checks for patches
  // in the background. The patch is applied on next app restart.
  unawaited(_checkShorebirdUpdate(prefs));

  final bridge = BridgeService();
  final draftService = DraftService(prefs);
  final dbService = DatabaseService();
  final promptHistoryService = PromptHistoryService(dbService);
  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: logger),
        RepositoryProvider<BridgeService>.value(value: bridge),
        RepositoryProvider<DatabaseService>.value(value: dbService),
        RepositoryProvider<DraftService>.value(value: draftService),
        RepositoryProvider<PromptHistoryService>.value(
          value: promptHistoryService,
        ),
        RepositoryProvider<MachineManagerService>.value(
          value: machineManagerService,
        ),
        if (sshStartupService != null)
          RepositoryProvider<SshStartupService>.value(value: sshStartupService),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => ConnectionCubit(
              BridgeConnectionState.disconnected,
              bridge.connectionStatus,
            ),
          ),
          BlocProvider(
            create: (_) => ActiveSessionsCubit(const [], bridge.sessionList),
          ),
          BlocProvider(
            create: (_) =>
                RecentSessionsCubit(const [], bridge.recentSessionsStream),
          ),
          BlocProvider(
            create: (_) => GalleryCubit(const [], bridge.galleryStream),
          ),
          BlocProvider(create: (_) => FileListCubit(const [], bridge.fileList)),
          BlocProvider(
            create: (_) =>
                ProjectHistoryCubit(const [], bridge.projectHistoryStream),
          ),
          BlocProvider(create: (_) => ServerDiscoveryCubit()),
          BlocProvider(
            create: (ctx) =>
                SessionListCubit(bridge: ctx.read<BridgeService>()),
          ),
          BlocProvider(
            create: (_) =>
                MachineManagerCubit(machineManagerService, sshStartupService),
          ),
          BlocProvider(
            create: (_) => SettingsCubit(
              prefs,
              bridgeService: bridge,
              machineManager: machineManagerService,
            ),
          ),
        ],
        child: const CcpocketApp(),
      ),
    ),
  );
}

class CcpocketApp extends StatefulWidget {
  const CcpocketApp({super.key});

  @override
  State<CcpocketApp> createState() => _CcpocketAppState();
}

class _CcpocketAppState extends State<CcpocketApp> {
  AppLinks? _appLinks;
  final _deepLinkNotifier = ValueNotifier<ConnectionParams?>(null);
  StreamSubscription<Uri>? _linkSub;
  StreamSubscription<RemoteMessage>? _fcmOnMessageSub;
  StreamSubscription<RemoteMessage>? _fcmOnMessageOpenedAppSub;

  late final AppRouter _appRouter;
  final _sessionRouteObserver = SessionRouteObserver();
  bool _routerInitialized = false;
  bool _fcmHandlersInitialized = false;
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();

    // Clear stale notifications on launch and whenever the app is resumed.
    _lifecycleListener = AppLifecycleListener(
      onStateChange: (state) {
        if (state == AppLifecycleState.resumed) {
          NotificationService.instance.cancelAll();
        }
      },
    );
    NotificationService.instance.cancelAll();

    if (!kIsWeb) {
      _appLinks = AppLinks();
      _initDeepLinks();
    }
  }

  void _initRouter() {
    if (_routerInitialized) return;
    _routerInitialized = true;
    _appRouter = AppRouter();
    // Navigate to session screen when user taps a notification
    NotificationService.instance.onNotificationTap = (payload) {
      _openSessionFromPayload(payload);
    };
    _initFcmHandlers();
  }

  void _initFcmHandlers() {
    if (kIsWeb || _fcmHandlersInitialized) return;
    try {
      // Firebase may be unavailable in widget tests or non-FCM setups.
      FirebaseMessaging.instance;
    } catch (e) {
      logger.warning('[fcm] handlers skipped: Firebase not initialized ($e)');
      return;
    }
    _fcmHandlersInitialized = true;

    _fcmOnMessageSub = FirebaseMessaging.onMessage.listen((message) {
      _handleForegroundFcmMessage(message);
    });
    _fcmOnMessageOpenedAppSub = FirebaseMessaging.onMessageOpenedApp.listen((
      message,
    ) {
      _openSessionFromData(message.data);
    });

    FirebaseMessaging.instance
        .getInitialMessage()
        .then((message) {
          if (message != null) {
            _openSessionFromData(message.data);
          }
        })
        .catchError((e) {
          logger.error('[fcm] getInitialMessage failed', e);
        });
  }

  Future<void> _handleForegroundFcmMessage(RemoteMessage message) async {
    final data = Map<String, dynamic>.from(message.data);
    final sessionId = data['sessionId']?.toString();
    final provider = _normalizeProvider(data['provider']?.toString());
    if (sessionId == null || sessionId.isEmpty) return;
    if (NotificationService.instance.isActiveSession(
      sessionId: sessionId,
      provider: provider,
    )) {
      return;
    }

    final notification = message.notification;
    final title =
        notification?.title ?? data['title']?.toString() ?? 'CC Pocket';
    final body =
        notification?.body ??
        data['body']?.toString() ??
        'New update available';
    final eventType = data['eventType']?.toString() ?? '';
    final payload = jsonEncode({'sessionId': sessionId, 'provider': provider});

    await NotificationService.instance.show(
      title: title,
      body: body,
      payload: payload,
      id: _notificationId(sessionId, provider, eventType),
    );
  }

  void _openSessionFromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        _openSessionFromData(decoded);
        return;
      }
    } catch (_) {
      // Backward compatibility: payload may be plain sessionId text.
    }
    _openSessionFromData({'sessionId': payload, 'provider': 'claude'});
  }

  void _openSessionFromData(Map<String, dynamic> data) {
    final sessionId = data['sessionId']?.toString();
    if (sessionId == null || sessionId.isEmpty) return;
    final provider = _normalizeProvider(data['provider']?.toString());
    if (provider == 'codex') {
      _appRouter.navigate(CodexSessionRoute(sessionId: sessionId));
      return;
    }
    _appRouter.navigate(ClaudeSessionRoute(sessionId: sessionId));
  }

  String _normalizeProvider(String? provider) {
    return provider == 'codex' ? 'codex' : 'claude';
  }

  int _notificationId(String sessionId, String provider, String eventType) {
    final raw = '$provider:$sessionId:$eventType';
    var hash = 0;
    for (final code in raw.codeUnits) {
      hash = ((hash * 31) + code) & 0x7fffffff;
    }
    return hash;
  }

  Future<void> _initDeepLinks() async {
    // Handle cold start
    try {
      final initialUri = await _appLinks!.getInitialLink().timeout(
        const Duration(seconds: 3),
        onTimeout: () => null,
      );
      if (initialUri != null) {
        _handleUri(initialUri);
      }
    } catch (e) {
      logger.error('[deep_link] getInitialLink failed', e);
    }

    // Handle warm start / incoming links while running
    try {
      _linkSub = _appLinks!.uriLinkStream.listen(
        _handleUri,
        onError: (e) => logger.error('[deep_link] stream error', e),
      );
    } catch (e) {
      logger.error('[deep_link] uriLinkStream failed', e);
    }
  }

  void _handleUri(Uri uri) {
    final params = ConnectionUrlParser.parse(uri.toString());
    if (params == null) return;

    switch (params) {
      case ConnectionParams():
        _deepLinkNotifier.value = params;
      case SessionLinkParams(:final sessionId):
        _appRouter.push(ClaudeSessionRoute(sessionId: sessionId));
    }
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    _linkSub?.cancel();
    _fcmOnMessageSub?.cancel();
    _fcmOnMessageOpenedAppSub?.cancel();
    _deepLinkNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Initialize router on first build (needs BlocProvider context)
    _initRouter();

    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, settings) {
        return MaterialApp.router(
          title: 'CC Pocket',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: settings.themeMode,
          locale: settings.appLocaleId.isEmpty
              ? null
              : Locale(settings.appLocaleId),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: _appRouter.config(
            navigatorObservers: () => [_sessionRouteObserver],
          ),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
