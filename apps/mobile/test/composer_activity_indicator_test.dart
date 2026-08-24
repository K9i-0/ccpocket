import 'package:ccpocket/features/chat_session/widgets/session_composer_activity_indicator.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/widgets/composer_activity_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  var now = DateTime(2026, 8, 23, 12);
  DateTime clock() => now;

  Widget buildSubject(
    ProcessStatus status, {
    DateTime? startedAt,
    DateTime? lastActivityAt,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: ComposerActivityIndicator(
          status: status,
          startedAt: startedAt,
          lastActivityAt: lastActivityAt,
          now: clock,
        ),
      ),
    );
  }

  setUp(() => now = DateTime(2026, 8, 23, 12));

  testWidgets('shows a compact elapsed indicator while working', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject(ProcessStatus.running));

    expect(
      find.byKey(const ValueKey('composer_activity_indicator')),
      findsOneWidget,
    );
    expect(find.text('Working'), findsOneWidget);
    expect(find.text(' · 0s'), findsOneWidget);

    now = now.add(const Duration(seconds: 65));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text(' · 1:05'), findsOneWidget);
  });

  testWidgets('keeps elapsed time across active status transitions', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject(ProcessStatus.starting));
    now = now.add(const Duration(seconds: 30));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(buildSubject(ProcessStatus.compacting));
    now = now.add(const Duration(seconds: 31));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text(' · 1:01'), findsOneWidget);
  });

  testWidgets('is absent when idle or waiting for approval', (tester) async {
    await tester.pumpWidget(buildSubject(ProcessStatus.idle));
    expect(
      find.byKey(const ValueKey('composer_activity_indicator')),
      findsNothing,
    );

    await tester.pumpWidget(buildSubject(ProcessStatus.waitingApproval));
    expect(
      find.byKey(const ValueKey('composer_activity_indicator')),
      findsNothing,
    );
  });

  testWidgets('shows resumed elapsed time and a quiet-activity hint', (
    tester,
  ) async {
    now = DateTime(2026, 8, 23, 12, 6, 12);
    await tester.pumpWidget(
      buildSubject(
        ProcessStatus.running,
        startedAt: DateTime(2026, 8, 23, 12),
        lastActivityAt: DateTime(2026, 8, 23, 12, 4),
      ),
    );

    expect(find.text(' · 6:12'), findsOneWidget);
    expect(find.byIcon(Icons.history_rounded), findsOneWidget);
    expect(find.text('2m ago'), findsOneWidget);
    final semantics = tester.widget<Semantics>(
      find.byKey(const ValueKey('composer_activity_indicator')),
    );
    expect(semantics.properties.liveRegion, isNot(true));
  });

  test('active turn starts at the latest user prompt', () {
    final first = DateTime(2026, 8, 23, 11);
    final latest = DateTime(2026, 8, 23, 12);
    final entries = <ChatEntry>[
      UserChatEntry('first', timestamp: first),
      StreamingChatEntry(text: 'response', timestamp: first),
      UserChatEntry('latest', timestamp: latest),
    ];

    expect(activeTurnStartedAt(entries), latest);
  });
}
