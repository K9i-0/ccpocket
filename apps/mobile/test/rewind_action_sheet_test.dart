import 'package:ccpocket/features/claude_session/widgets/rewind_action_sheet.dart';
import 'package:ccpocket/features/codex_session/widgets/codex_rewind_dialog.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('rewind action sheet can be limited to conversation mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: RewindActionSheet(
            userMessage: UserChatEntry(
              'first codex turn',
              messageUuid: 'codex:user-turn:1',
            ),
            availableModes: const [RewindMode.conversation],
            showPreview: false,
            onRewind: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Restore conversation only'), findsOneWidget);
    expect(find.text('Restore code only'), findsNothing);
    expect(find.text('Restore conversation & code'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('file'), findsNothing);
  });

  testWidgets('codex rewind uses a confirmation dialog', (tester) async {
    var confirmed = false;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: CodexRewindDialog(
            messageText: 'first codex turn',
            onConfirm: () {
              confirmed = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('Rewind conversation?'), findsOneWidget);
    expect(find.text('first codex turn'), findsOneWidget);
    expect(find.text('Restore conversation only'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('codex_rewind_confirm_button')));
    expect(confirmed, isTrue);
  });
}
