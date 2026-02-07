import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_driver/driver_extension.dart';

import 'features/session_list/session_list_screen.dart';
import 'features/session_list/state/session_list_cubit.dart';
import 'models/messages.dart';
import 'providers/bridge_cubits.dart';
import 'providers/server_discovery_cubit.dart';
import 'services/bridge_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

void main() async {
  enableFlutterDriverExtension();
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  final bridge = BridgeService();
  runApp(
    RepositoryProvider<BridgeService>.value(
      value: bridge,
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
        ],
        child: const CcpocketApp(),
      ),
    ),
  );
}

class CcpocketApp extends StatelessWidget {
  const CcpocketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ccpocket',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const SessionListScreen(),
    );
  }
}
