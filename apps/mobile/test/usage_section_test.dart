import 'dart:async';

import 'package:ccpocket/features/settings/state/settings_cubit.dart';
import 'package:ccpocket/features/settings/widgets/usage_section.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeBridgeService extends BridgeService {
  final _messagesController = StreamController<ServerMessage>.broadcast();
  final _connectionController =
      StreamController<BridgeConnectionState>.broadcast();
  final _usageController = StreamController<UsageResultMessage>.broadcast();
  bool connected = true;
  int requestCount = 0;

  @override
  bool get isConnected => connected;

  @override
  Stream<ServerMessage> get messages => _messagesController.stream;

  @override
  Stream<BridgeConnectionState> get connectionStatus =>
      _connectionController.stream;

  @override
  Stream<UsageResultMessage> get usageResults => _usageController.stream;

  @override
  String requestUsage({String? requestId}) {
    requestCount++;
    return requestId ?? 'usage-test-$requestCount';
  }

  void emitError(ErrorMessage message) => _messagesController.add(message);

  void emitConnection(BridgeConnectionState state) {
    connected = state == BridgeConnectionState.connected;
    _connectionController.add(state);
  }

  @override
  void dispose() {
    _messagesController.close();
    _connectionController.close();
    _usageController.close();
    super.dispose();
  }
}

void main() {
  Future<(SettingsCubit, _FakeBridgeService)> pumpUsageSection(
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settingsCubit = SettingsCubit(prefs);
    final bridge = _FakeBridgeService();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: BlocProvider.value(
          value: settingsCubit,
          child: Scaffold(body: UsageSection(bridgeService: bridge)),
        ),
      ),
    );
    await tester.pump();
    expect(bridge.requestCount, 1);
    expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
    return (settingsCubit, bridge);
  }

  Future<void> disposeHarness(
    WidgetTester tester,
    SettingsCubit settingsCubit,
    _FakeBridgeService bridge,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await settingsCubit.close();
    bridge.dispose();
  }

  testWidgets('shows a retry state when the Bridge reports a usage error', (
    tester,
  ) async {
    final (settingsCubit, bridge) = await pumpUsageSection(tester);
    final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));

    bridge.emitError(
      const ErrorMessage(message: 'Failed to fetch usage: unavailable'),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text(l.usageFetchFailed), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('usage_refresh_button')));
    await tester.pump();

    expect(bridge.requestCount, 2);
    expect(find.byType(CircularProgressIndicator), findsNWidgets(2));

    await disposeHarness(tester, settingsCubit, bridge);
  });

  testWidgets('ignores an error for a different usage request', (tester) async {
    final (settingsCubit, bridge) = await pumpUsageSection(tester);
    final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));

    bridge.emitError(
      const ErrorMessage(
        message: 'Failed to fetch usage: stale request',
        errorCode: 'usage_fetch_failed',
        requestId: 'usage-test-stale',
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
    expect(find.text(l.usageFetchFailed), findsNothing);

    bridge.emitError(
      const ErrorMessage(
        message: 'Failed to fetch usage: unavailable',
        errorCode: 'usage_fetch_failed',
        requestId: 'usage-test-1',
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text(l.usageFetchFailed), findsOneWidget);

    await disposeHarness(tester, settingsCubit, bridge);
  });

  testWidgets('shows a retry state when the Bridge disconnects mid-request', (
    tester,
  ) async {
    final (settingsCubit, bridge) = await pumpUsageSection(tester);
    final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));

    bridge.emitConnection(BridgeConnectionState.disconnected);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text(l.usageFetchFailed), findsOneWidget);

    await disposeHarness(tester, settingsCubit, bridge);
  });

  testWidgets('shows a retry state when a usage request times out', (
    tester,
  ) async {
    final (settingsCubit, bridge) = await pumpUsageSection(tester);
    final l = AppLocalizations.of(tester.element(find.byType(Scaffold)));

    await tester.pump(const Duration(seconds: 15));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text(l.usageFetchFailed), findsOneWidget);

    await disposeHarness(tester, settingsCubit, bridge);
  });
}
