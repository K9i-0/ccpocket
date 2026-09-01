import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ccpocket/features/session_list/state/session_list_cubit.dart';
import 'package:ccpocket/features/settings/state/settings_cubit.dart';
import 'package:ccpocket/main.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/providers/bridge_cubits.dart';
import 'package:ccpocket/providers/server_discovery_cubit.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:ccpocket/services/fcm_service.dart';

void main() {
  testWidgets('Initial screen shows connect UI', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final bridge = BridgeService();
    final fcmService = FcmService();

    await tester.pumpWidget(
      RepositoryProvider<BridgeService>.value(
        value: bridge,
        child: MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => SettingsCubit(prefs)),
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
            BlocProvider(
              create: (_) => FileListCubit(const [], bridge.fileList),
            ),
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
            BlocProvider(create: (_) => ServerDiscoveryCubit()),
            BlocProvider(
              create: (ctx) =>
                  SessionListCubit(bridge: ctx.read<BridgeService>()),
            ),
          ],
          child: CcpocketApp(fcmService: fcmService),
        ),
      ),
    );

    // Advance past the deep-link timeout timer (3 seconds)
    await tester.pump(const Duration(seconds: 4));

    // Connect screen should be visible when disconnected.
    expect(find.text('Connect to Bridge Server'), findsOneWidget);
    expect(find.text('Setup Guide'), findsOneWidget);
  });
}
