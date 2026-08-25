import 'dart:async';

import 'package:ccpocket/features/chat_session/widgets/codex_weekly_usage_badge.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBridgeService extends BridgeService {
  final _connectionController =
      StreamController<BridgeConnectionState>.broadcast();
  final _usageController = StreamController<UsageResultMessage>.broadcast();
  final _messageController = StreamController<ServerMessage>.broadcast();
  UsageResultMessage? cachedUsage;
  int requestCount = 0;
  bool connected = true;

  _FakeBridgeService({this.cachedUsage});

  @override
  bool get isConnected => connected;

  @override
  Stream<BridgeConnectionState> get connectionStatus =>
      _connectionController.stream;

  @override
  Stream<UsageResultMessage> get usageResults => _usageController.stream;

  @override
  Stream<ServerMessage> messagesForSession(String sessionId) =>
      _messageController.stream;

  @override
  UsageResultMessage? get lastUsageResult => cachedUsage;

  @override
  String requestUsage({String? requestId}) {
    requestCount++;
    return requestId ?? 'usage-test-$requestCount';
  }

  void emitUsage(UsageResultMessage message) {
    cachedUsage = message;
    _usageController.add(message);
  }

  void emitConnection(BridgeConnectionState state) {
    connected = state == BridgeConnectionState.connected;
    _connectionController.add(state);
  }

  void emitResult() {
    _messageController.add(const ResultMessage(subtype: 'success'));
  }

  @override
  void dispose() {
    _connectionController.close();
    _usageController.close();
    _messageController.close();
    super.dispose();
  }
}

Widget _buildApp(_FakeBridgeService bridge) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(
      appBar: AppBar(
        title: const Text(
          'A deliberately long chat title for a compact phone',
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          CodexWeeklyUsageBadge(bridgeService: bridge, sessionId: 'session-1'),
          const IconButton(onPressed: null, icon: Icon(Icons.folder_outlined)),
          const IconButton(onPressed: null, icon: Icon(Icons.more_horiz)),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('waits for fresh usage before showing the badge', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final bridge = _FakeBridgeService(
      cachedUsage: const UsageResultMessage(
        providers: [
          UsageInfo(
            provider: 'codex',
            sevenDay: UsageWindow(
              utilization: 60,
              resetsAt: '2026-08-30T00:00:00Z',
            ),
          ),
        ],
      ),
    );

    await tester.pumpWidget(_buildApp(bridge));
    await tester.pumpAndSettle();

    expect(find.text('40%'), findsNothing);
    expect(
      find.byKey(const ValueKey('codex_weekly_usage_badge')),
      findsNothing,
    );
    expect(bridge.requestCount, 1);

    bridge.emitUsage(
      const UsageResultMessage(
        providers: [
          UsageInfo(
            provider: 'codex',
            sevenDay: UsageWindow(
              utilization: 71,
              resetsAt: '2026-08-30T00:00:00Z',
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final badge = find.byKey(const ValueKey('codex_weekly_usage_badge'));
    expect(find.text('29%'), findsOneWidget);
    expect(tester.getSize(badge).width, lessThanOrEqualTo(44));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    bridge.dispose();
  });

  testWidgets('updates from Bridge results and hides without weekly data', (
    tester,
  ) async {
    final bridge = _FakeBridgeService();

    await tester.pumpWidget(_buildApp(bridge));
    expect(
      find.byKey(const ValueKey('codex_weekly_usage_badge')),
      findsNothing,
    );

    bridge.emitUsage(
      const UsageResultMessage(
        providers: [
          UsageInfo(
            provider: 'codex',
            sevenDay: UsageWindow(
              utilization: 9,
              resetsAt: '2026-08-30T00:00:00Z',
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('91%'), findsOneWidget);

    bridge.emitUsage(
      const UsageResultMessage(
        providers: [
          UsageInfo(
            provider: 'codex',
            fiveHour: UsageWindow(
              utilization: 10,
              resetsAt: '2026-08-23T05:00:00Z',
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('codex_weekly_usage_badge')),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    bridge.dispose();
  });

  testWidgets('bounds automatic refreshes after Codex turns', (tester) async {
    final bridge = _FakeBridgeService();

    await tester.pumpWidget(_buildApp(bridge));
    expect(bridge.requestCount, 1);

    // A completed turn cannot start another scan while one is already active.
    bridge.emitResult();
    await tester.pump();
    expect(bridge.requestCount, 1);

    bridge.emitUsage(
      const UsageResultMessage(
        providers: [
          UsageInfo(
            provider: 'codex',
            sevenDay: UsageWindow(
              utilization: 22,
              resetsAt: '2026-08-30T00:00:00Z',
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('78%'), findsOneWidget);

    // Repeated turns inside the cooldown keep using the fresh result.
    bridge.emitResult();
    await tester.pump();
    expect(bridge.requestCount, 1);

    await tester.pump(const Duration(minutes: 2));
    bridge.emitResult();
    await tester.pump();
    expect(bridge.requestCount, 2);

    await tester.pumpWidget(const SizedBox.shrink());
    bridge.dispose();
  });

  testWidgets('clears stale usage across Bridge reconnections', (tester) async {
    final bridge = _FakeBridgeService(
      cachedUsage: const UsageResultMessage(
        providers: [
          UsageInfo(
            provider: 'codex',
            sevenDay: UsageWindow(
              utilization: 40,
              resetsAt: '2026-08-30T00:00:00Z',
            ),
          ),
        ],
      ),
    );

    await tester.pumpWidget(_buildApp(bridge));
    expect(find.text('60%'), findsNothing);

    bridge.emitUsage(
      const UsageResultMessage(
        providers: [
          UsageInfo(
            provider: 'codex',
            sevenDay: UsageWindow(
              utilization: 40,
              resetsAt: '2026-08-30T00:00:00Z',
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('60%'), findsOneWidget);

    bridge.emitConnection(BridgeConnectionState.connected);
    await tester.pump();
    expect(bridge.requestCount, 1);

    bridge.emitConnection(BridgeConnectionState.disconnected);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('codex_weekly_usage_badge')),
      findsNothing,
    );

    bridge.emitConnection(BridgeConnectionState.connected);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('codex_weekly_usage_badge')),
      findsNothing,
    );
    expect(bridge.requestCount, 2);

    bridge.emitUsage(
      const UsageResultMessage(
        providers: [
          UsageInfo(
            provider: 'codex',
            sevenDay: UsageWindow(
              utilization: 55,
              resetsAt: '2026-08-30T00:00:00Z',
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('45%'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    bridge.dispose();
  });
}
