import 'dart:convert';

import 'package:ccpocket/features/codex_session/widgets/codex_recovery_panel.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('stays off until the Bridge acknowledges enabling', (
    tester,
  ) async {
    bool? requested;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CodexRecoveryPanel(
            recovery: const CodexRecoveryInfo(),
            onChanged: (value) => requested = value,
            onCancel: () {},
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('codex_recovery_toggle')));
    await tester.pump();
    expect(requested, true);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      false,
    );
    expect(find.textContaining('phone is disconnected'), findsOneWidget);
  });

  testWidgets(
    'shows scheduled state and supports cancellation at narrow large-text sizes',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var cancelled = false;
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.6)),
            child: child!,
          ),
          home: Scaffold(
            body: CodexRecoveryPanel(
              recovery: CodexRecoveryInfo(
                enabled: true,
                phase: 'waiting',
                attempts: 2,
                retryAt: DateTime(2026, 10, 1, 12, 30),
                reason: 'Usage limit reached',
              ),
              onChanged: (_) {},
              onCancel: () => cancelled = true,
            ),
          ),
        ),
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('codex_recovery_cancel_button')),
      );
      await tester.tap(
        find.byKey(const ValueKey('codex_recovery_cancel_button')),
      );
      expect(cancelled, true);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('2/5 attempts used'), findsOneWidget);
    },
  );

  testWidgets(
    'shows exhaustion without offering another automatic submission',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodexRecoveryPanel(
              recovery: const CodexRecoveryInfo(
                enabled: true,
                phase: 'exhausted',
                attempts: 5,
              ),
              onChanged: (_) {},
              onCancel: () {},
            ),
          ),
        ),
      );
      expect(find.textContaining('limit reached'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('codex_recovery_cancel_button')),
        findsNothing,
      );
    },
  );

  test('parses acknowledged recovery state and capability declarations', () {
    final message = ServerMessage.fromJson({
      'type': 'codex_recovery_state',
      'sessionId': 's1',
      'recovery': {
        'enabled': true,
        'phase': 'waiting',
        'attempts': 1,
        'maxAttempts': 5,
        'retryAt': 1790726400000,
        'reason': 'Usage limit',
      },
    }) as CodexRecoveryStateMessage;
    expect(message.recovery.retryAt?.millisecondsSinceEpoch, 1790726400000);
    expect(message.sessionId, 's1');
    expect(
      jsonDecode(
        ClientMessage.clientCapabilities().toJson(),
      )['supportedServerMessages'],
      contains('codex_recovery_state'),
    );
    expect(jsonDecode(ClientMessage.setCodexRecovery('s1', true).toJson()), {
      'type': 'set_codex_recovery',
      'sessionId': 's1',
      'enabled': true,
    });
  });
}
