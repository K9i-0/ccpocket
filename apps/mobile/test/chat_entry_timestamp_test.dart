import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/message_bubble.dart';

void main() {
  final timestamp = DateTime(2026, 10, 31, 18, 27);

  Future<void> pumpEntry(
    WidgetTester tester,
    ChatEntry entry, {
    Set<String> hiddenToolUseIds = const {},
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ChatEntryWidget(
            entry: entry,
            hiddenToolUseIds: hiddenToolUseIds,
          ),
        ),
      ),
    );
  }

  testWidgets('does not show a timestamp above an invisible status entry', (
    tester,
  ) async {
    await pumpEntry(
      tester,
      ServerChatEntry(
        const StatusMessage(status: ProcessStatus.running),
        timestamp: timestamp,
      ),
    );

    expect(find.text('18:27'), findsNothing);
  });

  testWidgets('does not show a timestamp above a resolved permission', (
    tester,
  ) async {
    await pumpEntry(
      tester,
      ServerChatEntry(
        const PermissionResolvedMessage(toolUseId: 'toolu_1'),
        timestamp: timestamp,
      ),
    );

    expect(find.text('18:27'), findsNothing);
  });

  testWidgets('does not show a timestamp above a summarized tool result', (
    tester,
  ) async {
    await pumpEntry(
      tester,
      ServerChatEntry(
        const ToolResultMessage(toolUseId: 'toolu_sub', content: 'ok'),
        timestamp: timestamp,
      ),
      hiddenToolUseIds: const {'toolu_sub'},
    );

    expect(find.text('18:27'), findsNothing);
  });

  testWidgets('still shows a timestamp above a visible entry', (tester) async {
    await pumpEntry(
      tester,
      ServerChatEntry(
        const ErrorMessage(message: 'boom'),
        timestamp: timestamp,
      ),
    );

    expect(find.text('18:27'), findsOneWidget);
  });
}
