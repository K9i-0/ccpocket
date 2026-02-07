import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/features/session_list/state/session_list_cubit.dart';
import 'package:ccpocket/main.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/providers/bridge_cubits.dart';
import 'package:ccpocket/providers/server_discovery_cubit.dart';
import 'package:ccpocket/services/bridge_service.dart';

void main() {
  testWidgets('Initial screen shows connect UI', (WidgetTester tester) async {
    final bridge = BridgeService();

    await tester.pumpWidget(
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
            BlocProvider(
              create: (_) => FileListCubit(const [], bridge.fileList),
            ),
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

    // Advance past the deep-link timeout timer (3 seconds)
    await tester.pump(const Duration(seconds: 4));

    // App title
    expect(find.text('ccpocket'), findsOneWidget);
  });
}
