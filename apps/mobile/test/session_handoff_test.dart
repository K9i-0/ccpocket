import 'dart:convert';

import 'package:ccpocket/features/chat_session/session_handoff.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/l10n/app_localizations_delegates.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/models/new_session_tab.dart';
import 'package:ccpocket/services/chat_message_handler.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/bubbles/handoff_bubble.dart';
import 'package:ccpocket/widgets/bubbles/user_bubble.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Widget _wrap(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: locale,
    home: Scaffold(body: child),
  );
}

const _prompt =
    '[ccpocket handoff: Claude Code → Codex]\n\n'
    'You are taking over a task from another coding agent (Claude Code).\n\n'
    '## Handoff note from Claude Code\n\nMarkup is done.';

const _noteRequest =
    '[ccpocket handoff] This session is being handed over to Antigravity, '
    'another coding agent. It continues in the same working directory.';

void main() {
  group('protocol', () {
    test('handoff_session carries the target and the instruction', () {
      expect(
        jsonDecode(
          ClientMessage.handoffSession(
            's1',
            target: Provider.antigravity,
            instruction: 'Only write the tests.',
          ).toJson(),
        ),
        {
          'type': 'handoff_session',
          'sessionId': 's1',
          'targetProvider': 'antigravity',
          'instruction': 'Only write the tests.',
        },
      );
      expect(
        jsonDecode(
          ClientMessage.handoffSession(
            's1',
            target: Provider.codex,
            instruction: '',
          ).toJson(),
        ),
        {
          'type': 'handoff_session',
          'sessionId': 's1',
          'targetProvider': 'codex',
        },
      );
    });

    test('session_created reads the handoff flag', () {
      final created = ServerMessage.fromJson({
        'type': 'system',
        'subtype': 'session_created',
        'sessionId': 's2',
        'provider': 'codex',
        'sourceSessionId': 's1',
        'handoff': true,
      }) as SystemMessage;
      expect(created.handoff, isTrue);
      expect(created.sourceSessionId, 's1');

      final plain = ServerMessage.fromJson({
        'type': 'system',
        'subtype': 'session_created',
        'sessionId': 's2',
      }) as SystemMessage;
      expect(plain.handoff, isFalse);
    });

    test('an older Bridge gets the update hint', () {
      final update = ChatMessageHandler().handle(
        const ErrorMessage(
          message: 'handoff_session',
          errorCode: 'unsupported_message',
        ),
        isBackground: false,
      );
      final entry = update.entriesToAdd.single as ServerChatEntry;
      expect(
        (entry.message as ErrorMessage).errorCode,
        'bridge_update_required',
      );
    });
  });

  group('handoffTargets', () {
    const all = [
      NewSessionTab.codex,
      NewSessionTab.claude,
      NewSessionTab.antigravity,
    ];

    test('offers the other agents in sheet order', () {
      expect(
        handoffTargets(
          current: Provider.claude,
          supportsHandoff: true,
          visibleTabs: all,
        ),
        [Provider.codex, Provider.antigravity],
      );
      expect(
        handoffTargets(
          current: Provider.antigravity,
          supportsHandoff: true,
          visibleTabs: all,
        ),
        [Provider.codex, Provider.claude],
      );
    });

    test('leaves out agents that are switched off or unavailable', () {
      expect(
        handoffTargets(
          current: Provider.codex,
          supportsHandoff: true,
          visibleTabs: const [NewSessionTab.codex, NewSessionTab.claude],
        ),
        [Provider.claude],
      );
    });

    test('is empty for a Bridge without handoff', () {
      expect(
        handoffTargets(
          current: Provider.codex,
          supportsHandoff: false,
          visibleTabs: all,
        ),
        isEmpty,
      );
    });
  });

  group('menu values', () {
    test('round-trip through handoffTargetFromMenuValue', () {
      expect(handoffTargetFromMenuValue('handoff:codex'), Provider.codex);
      expect(
        handoffTargetFromMenuValue('handoff:antigravity'),
        Provider.antigravity,
      );
      expect(handoffTargetFromMenuValue('gallery'), isNull);
      expect(handoffTargetFromMenuValue('handoff:unknown'), isNull);
    });
  });

  group('HandoffMessage.parse', () {
    test('reads the first prompt of the continuing session', () {
      final handoff = HandoffMessage.parse(_prompt)!;
      expect(handoff.source, 'Claude Code');
      expect(handoff.target, 'Codex');
    });

    test('reads the note request', () {
      final handoff = HandoffMessage.parse(_noteRequest)!;
      expect(handoff.source, isNull);
      expect(handoff.target, 'Antigravity');
    });

    test('ignores ordinary messages', () {
      expect(HandoffMessage.parse('Please hand off to Codex'), isNull);
      expect(HandoffMessage.parse('See [ccpocket handoff: A → B]'), isNull);
      expect(HandoffMessage.parse('[ccpocket handoff something else'), isNull);
    });
  });

  group('UserBubble', () {
    testWidgets('shows a handoff prompt as a card that expands', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const UserBubble(text: _prompt)));

      expect(find.text('Handed off from Claude Code'), findsOneWidget);
      expect(find.textContaining('Markup is done.'), findsNothing);

      await tester.tap(find.text('Handed off from Claude Code'));
      await tester.pump();
      expect(find.textContaining('Markup is done.'), findsOneWidget);
    });

    testWidgets('labels the note request with its target', (tester) async {
      await tester.pumpWidget(
        _wrap(const UserBubble(text: _noteRequest), locale: const Locale('ja')),
      );
      expect(find.text('Antigravityへの引き継ぎメモを依頼'), findsOneWidget);
    });

    testWidgets('keeps ordinary messages as they are', (tester) async {
      await tester.pumpWidget(_wrap(const UserBubble(text: 'hello')));
      expect(find.byKey(const ValueKey('handoff_bubble')), findsNothing);
      expect(find.text('hello'), findsOneWidget);
    });
  });

  group('showHandoffDialog', () {
    late String? result;

    Future<void> open(WidgetTester tester) async {
      result = 'unset';
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showHandoffDialog(
                  context,
                  source: Provider.claude,
                  target: Provider.codex,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('explains the handoff and returns the instruction', (
      tester,
    ) async {
      await open(tester);
      expect(find.text('Hand off to Codex'), findsOneWidget);
      expect(
        find.textContaining('Claude writes a handoff note'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey('handoff_instruction_field')),
        'Only the tests',
      );
      await tester.tap(find.byKey(const ValueKey('handoff_confirm_button')));
      await tester.pumpAndSettle();
      expect(result, 'Only the tests');
    });

    testWidgets('returns an empty instruction when none is typed', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.byKey(const ValueKey('handoff_confirm_button')));
      await tester.pumpAndSettle();
      expect(result, '');
    });

    testWidgets('returns null when cancelled', (tester) async {
      await open(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
    });
  });
}
