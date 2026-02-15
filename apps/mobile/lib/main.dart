import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/session_list/state/session_list_cubit.dart';
import 'features/settings/state/settings_cubit.dart';
import 'features/settings/state/settings_state.dart';
import 'models/messages.dart';
import 'providers/bridge_cubits.dart';
import 'providers/machine_manager_cubit.dart';
import 'providers/server_discovery_cubit.dart';
import 'router/app_router.dart';
import 'services/bridge_service.dart';
import 'services/connection_url_parser.dart';
import 'services/draft_service.dart';
import 'services/machine_manager_service.dart';
import 'services/notification_service.dart';
import 'services/ssh_startup_service.dart';
import 'theme/app_theme.dart';

void main() async {
  if (kDebugMode && !kIsWeb) {
    MarionetteBinding.ensureInitialized();
  } else {
    WidgetsFlutterBinding.ensureInitialized();
  }
  FlutterError.onError = (details) {
    debugPrint('[FlutterError] ${details.exceptionAsString()}');
    debugPrint('[FlutterError] ${details.stack}');
  };
  // Initialize notifications in background to avoid blocking app startup
  NotificationService.instance.init().catchError((e) {
    debugPrint('[main] NotificationService init failed: $e');
  });

  // Initialize SharedPreferences and services
  final prefs = await SharedPreferences.getInstance();
  const secureStorage = FlutterSecureStorage();
  final machineManagerService = MachineManagerService(prefs, secureStorage);
  // SSH is only supported on native platforms (not web)
  final sshStartupService = kIsWeb
      ? null
      : SshStartupService(machineManagerService);

  final bridge = BridgeService();
  final draftService = DraftService(prefs);
  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<BridgeService>.value(value: bridge),
        RepositoryProvider<DraftService>.value(value: draftService),
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
            create: (_) => SettingsCubit(prefs, bridgeService: bridge),
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

  late final AppRouter _appRouter;
  bool _routerInitialized = false;

  @override
  void initState() {
    super.initState();
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
      if (payload != null && payload.isNotEmpty) {
        _appRouter.push(ClaudeCodeSessionRoute(sessionId: payload));
      }
    };
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
      debugPrint('[deep_link] getInitialLink failed: $e');
    }

    // Handle warm start / incoming links while running
    try {
      _linkSub = _appLinks!.uriLinkStream.listen(
        _handleUri,
        onError: (e) => debugPrint('[deep_link] stream error: $e'),
      );
    } catch (e) {
      debugPrint('[deep_link] uriLinkStream failed: $e');
    }
  }

  void _handleUri(Uri uri) {
    final params = ConnectionUrlParser.parse(uri.toString());
    if (params != null) {
      _deepLinkNotifier.value = params;
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
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
          routerConfig: _appRouter.config(),
        );
      },
    );
  }
}
