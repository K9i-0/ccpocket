/// ccpocket - Claude Code Mobile Client
///
/// This is the main entry point for the ccpocket Flutter application.
///
/// Key responsibilities:
/// - Initializes Marionette binding for E2E testing in debug and profile modes
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
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_bloc_observer.dart';
import 'core/logger.dart';
import 'core/reflex/reflex_registry.dart';
import 'l10n/app_localizations.dart';
import 'l10n/app_localizations_delegates.dart';
import 'features/file_peek/playback/background_media_handler.dart';
import 'features/session_list/state/session_list_cubit.dart';
import 'features/session_list/state/session_list_reflex.dart';
import 'features/session_list/workspace_shell_screen.dart';
import 'features/git/state/git_status_cubit.dart';
import 'features/git/state/git_view_cache_service.dart';
import 'features/github/state/github_view_cache_service.dart';
import 'features/settings/state/settings_cubit.dart';
import 'features/settings/state/settings_state.dart';
import 'features/settings/widgets/keyboard_shortcuts_dialog.dart';
import 'models/messages.dart';
import 'providers/bridge_cubits.dart';
import 'providers/machine_manager_cubit.dart';
import 'router/app_router.dart';
import 'router/session_route_observer.dart';
import 'router/session_stack_navigation.dart';
import 'services/app_icon_service.dart';
import 'services/bridge_service.dart';
import 'services/connect_deep_link_scope.dart';
import 'services/connection_url_parser.dart';
import 'services/database_service.dart';
import 'services/deep_link_dispatcher.dart';
import 'services/desktop_menu_service.dart';
import 'services/draft_service.dart';
import 'services/floating_keyboard_service.dart';
import 'services/fcm_service.dart';
import 'services/in_app_review_service.dart';
import 'services/machine_manager_service.dart';
import 'services/mock_preview_extension.dart';
import 'services/notification_service.dart';
import 'services/performance_probe_extension.dart';
import 'services/prompt_history_service.dart';
import 'services/reflex_extension.dart';
import 'services/revenuecat_service.dart';
import 'services/ssh_bridge_tunnel_service.dart';
import 'services/shared_state_adapters.dart';
import 'services/shared_state_sync.dart';
import 'services/ssh_startup_service.dart';
import 'services/support_banner_service.dart';
import 'theme/app_theme.dart';
import 'services/store_screenshot_extension.dart';
import 'theme/legacy_material_bridge.dart';
import 'theme/markdown_style.dart';
import 'theme/provider_style.dart';
import 'utils/platform_helper.dart';
import 'widgets/duo/duo_control_strip.dart';
import 'widgets/release_error_widget.dart';

/// Top-level handler for FCM background messages.
/// Required by firebase_messaging to process messages when app is in background.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // No-op: FCM notification messages are automatically displayed by the OS.
  // This handler is registered to prevent the "no onBackgroundMessage handler"
  // warning on Android.
}

void main() async {
  if (!kReleaseMode && !kIsWeb) {
    MarionetteBinding.ensureInitialized();
    registerCcpocketDebugExtensions();
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }
  final bootstrap = await bootstrapCcpocket();
  runApp(bootstrap.wrap(CcpocketApp(fcmService: bootstrap.fcmService)));
}

/// Registers the debug-only Marionette extensions (store screenshots, mock
/// previews, performance probes). Call once, after the Marionette binding.
void registerCcpocketDebugExtensions() {
  registerStoreScreenshotExtensions();
  registerMockPreviewExtensions();
  registerPerformanceProbeExtensions();
  registerReflexExtensions();
}

/// Services created once per process by [bootstrapCcpocket].
class CcpocketBootstrap {
  const CcpocketBootstrap({required this.fcmService, required this.wrap});

  final FcmService fcmService;

  /// Places the app-wide repository and bloc providers above [child].
  ///
  /// Call it once: the providers own the services and dispose them.
  /// `multi_device_preview` uses it as its wrapper, so every previewed
  /// [CcpocketApp] shares the same services.
  final Widget Function(Widget child) wrap;
}

/// Initializes the services shared by the whole app. The binding must be
/// initialized first.
Future<CcpocketBootstrap> bootstrapCcpocket() async {
  MediaKit.ensureInitialized();
  try {
    await BackgroundMediaHandler.initialize();
  } catch (error) {
    logger.error('[main] Media service init failed', error);
  }
  Bloc.observer = AppBlocObserver(logger: logger);

  FlutterError.onError = (details) {
    logger.error(
      '[FlutterError] ${details.exceptionAsString()}',
      details.exception,
      details.stack,
    );
  };
  installReleaseErrorWidget();
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
  final sshBridgeTunnelService = kIsWeb
      ? null
      : SshBridgeTunnelService(machineManagerService);
  if (sshBridgeTunnelService != null) {
    machineManagerService.configureBridgeTunnelResolvers(
      wsUrlResolver: sshBridgeTunnelService.buildWsUrl,
      httpBaseUrlResolver: sshBridgeTunnelService.buildHttpBaseUrl,
      machineIdForLocalPort: sshBridgeTunnelService.machineIdForLocalPort,
    );
  }

  final bridge = BridgeService();
  bridge.onDisconnect = sshBridgeTunnelService?.closeAll;
  final fcmService = FcmService();
  final draftService = DraftService(prefs);
  final inAppReviewService = InAppReviewService(prefs: prefs);
  await inAppReviewService.attachToBridge(bridge);
  final supportBannerService = SupportBannerService(
    prefs: prefs,
    reviewService: inAppReviewService,
  );
  StoreScreenshotState.draftService = draftService;
  final dbService = DatabaseService();
  final promptHistoryService = PromptHistoryService(dbService);
  final promptHistorySyncSub = bridge.connectionStatus.listen((state) {
    if (state == BridgeConnectionState.connected) {
      unawaited(
        promptHistoryService.syncAll(
          machineManager: machineManagerService,
          bridgeService: bridge,
        ),
      );
    }
  });
  final appIconService = AppIconService();
  final revenueCatService = RevenueCatService();
  final settingsCubit = SettingsCubit(
    prefs,
    bridgeService: bridge,
    machineManager: machineManagerService,
    fcmService: fcmService,
    revenueCatService: revenueCatService,
    appIconService: appIconService,
  );
  // Created before any screen so that stores and cubits can share through it.
  final sharedStateSync = SharedStateSync(bridge: bridge, prefs: prefs);
  SharedStateSync.instance = sharedStateSync;
  registerPrefsSharedStateAdapters(
    sharedStateSync,
    prefs: prefs,
    bridge: bridge,
  );
  sharedStateSync.register(settingsCubit.sharedStateAdapter);
  final gitStatusCubit = GitStatusCubit(
    bridge: bridge,
    remoteStatusBadgeEnabled: () =>
        settingsCubit.state.showRemoteGitStatusBadge,
  );
  final gitViewCacheService = GitViewCacheService(
    bridge: bridge,
    gitStatusCubit: gitStatusCubit,
  );
  unawaited(revenueCatService.initialize());
  return CcpocketBootstrap(
    fcmService: fcmService,
    wrap: (child) => MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: logger),
        RepositoryProvider<BridgeService>(
          create: (_) => bridge,
          lazy: false,
          dispose: (service) {
            unawaited(promptHistorySyncSub.cancel());
            service.dispose();
          },
        ),
        RepositoryProvider<GitViewCacheService>(
          create: (_) => gitViewCacheService,
          lazy: false,
          dispose: (service) => unawaited(service.dispose()),
        ),
        RepositoryProvider<GitHubViewCacheService>(
          create: (_) => GitHubViewCacheService(bridge: bridge),
          dispose: (service) => unawaited(service.dispose()),
        ),
        RepositoryProvider<DatabaseService>(
          create: (_) => dbService,
          lazy: false,
          dispose: (service) => unawaited(service.close()),
        ),
        RepositoryProvider<DraftService>.value(value: draftService),
        RepositoryProvider<FloatingKeyboardService>(
          create: (_) => FloatingKeyboardService()..start(),
          dispose: (service) => service.dispose(),
        ),
        RepositoryProvider<InAppReviewService>(
          create: (_) => inAppReviewService,
          lazy: false,
          dispose: (service) => service.dispose(),
        ),
        ChangeNotifierProvider<SupportBannerService>(
          create: (_) => supportBannerService,
          lazy: false,
        ),
        RepositoryProvider<PromptHistoryService>.value(
          value: promptHistoryService,
        ),
        RepositoryProvider<AppIconService>.value(value: appIconService),
        RepositoryProvider<RevenueCatService>(
          create: (_) => revenueCatService,
          lazy: false,
          dispose: (service) => unawaited(service.dispose()),
        ),
        RepositoryProvider<MachineManagerService>(
          create: (_) => machineManagerService,
          lazy: false,
          dispose: (service) => service.dispose(),
        ),
        if (sshStartupService != null)
          RepositoryProvider<SshStartupService>.value(value: sshStartupService),
        if (sshBridgeTunnelService != null)
          RepositoryProvider<SshBridgeTunnelService>(
            create: (_) => sshBridgeTunnelService,
            lazy: false,
            dispose: (service) => unawaited(service.closeAll()),
          ),
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
            create: (_) => BridgeAuthRejectionCubit(
              bridge.authRejection,
              bridge.authRejectionStream,
            ),
          ),
          BlocProvider<GitStatusCubit>(
            create: (_) => gitStatusCubit,
            lazy: false,
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
          BlocProvider(
            create: (_) => WorkspaceProjectsCubit(
              bridge.projectsState,
              bridge.projectsStream,
            ),
          ),
          BlocProvider(
            create: (ctx) {
              final cubit = SessionListCubit(bridge: ctx.read<BridgeService>());
              if (!kReleaseMode) {
                ReflexRegistry.register(SessionListReflexNode(cubit));
              }
              return cubit;
            },
          ),
          BlocProvider(
            create: (_) => MachineManagerCubit(
              machineManagerService,
              sshStartupService,
              refreshLatestBridgeVersionOnInit: true,
            ),
          ),
          BlocProvider<SettingsCubit>(
            create: (_) => settingsCubit,
            lazy: false,
          ),
        ],
        child: child,
      ),
    ),
  );
}

class CcpocketApp extends StatefulWidget {
  const CcpocketApp({required this.fcmService, super.key});

  final FcmService fcmService;

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
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  late final DeepLinkDispatcher _deepLinkDispatcher;
  bool _routerInitialized = false;
  bool _fcmHandlersInitialized = false;
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _deepLinkDispatcher = DeepLinkDispatcher(_handleUri);

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
    StoreScreenshotState.navigatorKeys.add(_appRouter.navigatorKey);
    // Navigate to session screen when user taps a notification
    NotificationService.instance.onNotificationTap = (payload) {
      _openSessionFromPayload(payload);
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _deepLinkDispatcher.markReady();
      }
    });
  }

  void _initFcmHandlers() {
    if (kIsWeb || _fcmHandlersInitialized || !widget.fcmService.isAvailable) {
      return;
    }
    _fcmHandlersInitialized = true;

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

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
    if (SessionStackNavigation.revealStackedSession(
      _appRouter,
      sessionId: sessionId,
      provider: provider,
    )) {
      return;
    }
    if (NotificationService.instance.isActiveSession(
      sessionId: sessionId,
      provider: provider,
    )) {
      return;
    }
    final route = SessionLinkRoute(
      key: UniqueKey(),
      sessionId: sessionId,
      provider: provider,
    );
    // A snackbar left on screen would be caught in the route transition, where
    // every Scaffold involved draws it.
    _scaffoldMessengerKey.currentState?.removeCurrentSnackBar();
    if (_appRouter.current.name == SessionLinkRoute.name) {
      _appRouter.replace(route);
      return;
    }
    _appRouter.push(route);
  }

  /// Provider of a notification payload. Payloads without one predate the
  /// field and belong to Claude.
  String _normalizeProvider(String? provider) {
    return providerFromRaw(provider).value;
  }

  int _notificationId(String sessionId, String provider, String eventType) {
    final raw = '$provider:$sessionId:$eventType';
    var hash = 0;
    for (final code in raw.codeUnits) {
      hash = ((hash * 31) + code) & 0x7fffffff;
    }
    return hash;
  }

  void _initDeepLinks() {
    // app_links includes the cold-start URI as the first stream event.
    try {
      _linkSub = _appLinks!.uriLinkStream.listen(
        _deepLinkDispatcher.add,
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
      case SessionLinkParams(:final sessionId, :final provider):
        _openSessionFromData({'sessionId': sessionId, 'provider': provider});
    }
  }

  @override
  void dispose() {
    if (_routerInitialized) {
      StoreScreenshotState.navigatorKeys.remove(_appRouter.navigatorKey);
    }
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
        if (settings.fcmEnabledMachines.isNotEmpty && settings.fcmAvailable) {
          _initFcmHandlers();
        }
        final appLocale = settings.appLocaleId.isEmpty
            ? null
            : Locale(settings.appLocaleId);
        final themeLocale =
            appLocale ?? WidgetsBinding.instance.platformDispatcher.locale;
        updateReleaseErrorWidgetLocale(appLocale);
        return ConnectDeepLinkScope(
          notifier: _deepLinkNotifier,
          child: MaterialApp.router(
            scaffoldMessengerKey: _scaffoldMessengerKey,
            title: 'CC Pocket',
            theme: AppTheme.lightThemeForLocale(themeLocale),
            darkTheme: AppTheme.darkThemeForLocale(themeLocale),
            themeMode: settings.themeMode,
            locale: appLocale,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: _appRouter.config(
              navigatorObservers: () => [SessionRouteObserver()],
            ),
            builder: (context, child) {
              final mediaQuery = MediaQuery.maybeOf(context);
              final bridged = LegacyMaterialBridge(
                child: child ?? const SizedBox.shrink(),
              );
              final app = _AppDesktopShortcutsHost(
                appRouter: _appRouter,
                child: bridged,
              );
              if (mediaQuery == null) return app;
              return MediaQuery(
                data: mediaQuery.copyWith(
                  textScaler: _AppTextScaler(
                    base: mediaQuery.textScaler,
                    multiplier: settings.textScale,
                  ),
                ),
                child: DuoStripHost(child: app),
              );
            },
            debugShowCheckedModeBanner: false,
          ),
        );
      },
    );
  }
}

class _AppDesktopShortcutsHost extends StatelessWidget {
  const _AppDesktopShortcutsHost({
    required this.appRouter,
    required this.child,
  });

  final AppRouter appRouter;
  final Widget child;

  void _dispatch(BuildContext context, DesktopMenuAction action) {
    final shell = WorkspaceShellScreen.activeShell;
    if (shell != null && shell.mounted) {
      shell.handleDesktopMenuAction(action);
      return;
    }
    switch (action) {
      case DesktopMenuAction.openSettings:
        appRouter.navigate(SettingsRoute());
      case DesktopMenuAction.closeActive:
        final nav = appRouter.navigatorKey.currentState;
        if (nav != null && nav.canPop()) {
          unawaited(nav.maybePop());
        }
      case DesktopMenuAction.zoomIn:
        context.read<SettingsCubit>().zoomIn();
      case DesktopMenuAction.zoomOut:
        context.read<SettingsCubit>().zoomOut();
      case DesktopMenuAction.actualSize:
        context.read<SettingsCubit>().resetZoom();
      case DesktopMenuAction.showShortcuts:
        final navContext = appRouter.navigatorKey.currentContext;
        if (navContext != null) {
          unawaited(KeyboardShortcutsDialog.show(navContext));
        }
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // macOS handles menu key equivalents natively via AppMenuBridge.swift
    // (avoiding double-firing), and WorkspaceShellScreen handles Cmd+1..9.
    // On non-macOS desktop platforms, handle global app shortcuts even when
    // focus is inside a modal dialog or a pushed root route.
    if (!isDesktopPlatform || isMacOSPlatform) {
      return child;
    }
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(
          LogicalKeyboardKey.comma,
          control: true,
          includeRepeats: false,
        ): () =>
            _dispatch(context, DesktopMenuAction.openSettings),
        const SingleActivator(
          LogicalKeyboardKey.keyW,
          control: true,
          includeRepeats: false,
        ): () =>
            _dispatch(context, DesktopMenuAction.closeActive),
        const SingleActivator(
          LogicalKeyboardKey.digit0,
          control: true,
          includeRepeats: false,
        ): () =>
            _dispatch(context, DesktopMenuAction.actualSize),
        const SingleActivator(
          LogicalKeyboardKey.numpad0,
          control: true,
          includeRepeats: false,
        ): () =>
            _dispatch(context, DesktopMenuAction.actualSize),
        const SingleActivator(LogicalKeyboardKey.equal, control: true): () =>
            _dispatch(context, DesktopMenuAction.zoomIn),
        const SingleActivator(LogicalKeyboardKey.add, control: true): () =>
            _dispatch(context, DesktopMenuAction.zoomIn),
        const SingleActivator(
          LogicalKeyboardKey.numpadAdd,
          control: true,
        ): () =>
            _dispatch(context, DesktopMenuAction.zoomIn),
        const SingleActivator(LogicalKeyboardKey.minus, control: true): () =>
            _dispatch(context, DesktopMenuAction.zoomOut),
        const SingleActivator(
          LogicalKeyboardKey.numpadSubtract,
          control: true,
        ): () =>
            _dispatch(context, DesktopMenuAction.zoomOut),
        const SingleActivator(
          LogicalKeyboardKey.slash,
          control: true,
          includeRepeats: false,
        ): () =>
            _dispatch(context, DesktopMenuAction.showShortcuts),
      },
      child: child,
    );
  }
}

class _AppTextScaler extends TextScaler {
  const _AppTextScaler({required this.base, required this.multiplier});

  final TextScaler base;
  final double multiplier;

  @override
  double scale(double fontSize) => base.scale(fontSize) * multiplier;

  @override
  // Required by TextScaler for legacy callers.
  // ignore: deprecated_member_use
  double get textScaleFactor => base.textScaleFactor * multiplier;

  @override
  bool operator ==(Object other) {
    return other is _AppTextScaler &&
        other.base == base &&
        other.multiplier == multiplier;
  }

  @override
  int get hashCode => Object.hash(base, multiplier);
}
