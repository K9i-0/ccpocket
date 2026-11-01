import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/question_draft_store.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/bubbles/ask_user_question_widget.dart';
import 'package:ccpocket/widgets/session_card.dart';

const _cardKey = ValueKey('card_side');
const _chatKey = ValueKey('chat_side');

Finder _inCard(Finder finder) =>
    find.descendant(of: find.byKey(_cardKey), matching: finder);

Finder _inChat(Finder finder) =>
    find.descendant(of: find.byKey(_chatKey), matching: finder);

/// Card and chat bar for the same pending question, side by side as on
/// tablet / desktop layouts.
Widget _sideBySide({
  required PermissionRequestMessage permission,
  required void Function(String toolUseId, String result) onCardAnswer,
  required void Function(String toolUseId, String result) onChatAnswer,
  bool showChat = true,
}) {
  final session = SessionInfo(
    id: 'sync-session',
    projectPath: '/home/user/my-app',
    status: 'waiting_approval',
    createdAt: DateTime.now().toIso8601String(),
    lastActivityAt: DateTime.now().toIso8601String(),
    pendingPermission: permission,
  );
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    theme: AppTheme.darkTheme,
    home: Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              key: _cardKey,
              child: RunningSessionCard(
                session: session,
                onTap: () {},
                onAnswer: onCardAnswer,
              ),
            ),
          ),
          Expanded(
            child: showChat
                ? SingleChildScrollView(
                    key: _chatKey,
                    child: AskUserQuestionWidget(
                      toolUseId: permission.toolUseId,
                      input: permission.input,
                      onAnswer: onChatAnswer,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    ),
  );
}

const _multiQuestionPermission = PermissionRequestMessage(
  toolUseId: 'sync-multi',
  toolName: 'AskUserQuestion',
  input: {
    'questions': [
      {
        'question': 'First question?',
        'header': 'First',
        'options': [
          {'label': 'Alpha', 'description': ''},
          {'label': 'Beta', 'description': ''},
        ],
        'multiSelect': false,
      },
      {
        'question': 'Second question?',
        'header': 'Second',
        'options': [
          {'label': 'Gamma', 'description': ''},
          {'label': 'Delta', 'description': ''},
        ],
        'multiSelect': false,
      },
    ],
  },
);

/// The card's status dot animates forever, so pumpAndSettle never settles.
Future<void> _settle(WidgetTester tester) async {
  // Page sync jumps after the frame that changed the page, then
  // ExpandablePageView animates to the new page height.
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  testWidgets('card and chat share answers, page and answered state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final cardAnswers = <String>[];
    final chatAnswers = <String>[];
    await tester.pumpWidget(
      _sideBySide(
        permission: _multiQuestionPermission,
        onCardAnswer: (_, r) => cardAnswers.add(r),
        onChatAnswer: (_, r) => chatAnswers.add(r),
      ),
    );
    await _settle(tester);
    expect(_inCard(find.text('1 of 3')), findsOneWidget);
    expect(_inChat(find.text('1/3')), findsOneWidget);

    // Answer the first question on the card → chat follows to page 2.
    await tester.tap(_inCard(find.text('Alpha')));
    await _settle(tester);
    expect(_inCard(find.text('2 of 3')), findsOneWidget);
    expect(_inChat(find.text('2/3')), findsOneWidget);

    // Answer the second question in chat → card follows to the summary.
    await tester.tap(_inChat(find.byKey(const ValueKey('ask_option_1_Delta'))));
    await _settle(tester);
    expect(_inCard(find.text('3 of 3')), findsOneWidget);
    expect(_inChat(find.text('3/3')), findsOneWidget);
    expect(_inCard(find.text('Alpha')).hitTestable(), findsOneWidget);
    expect(_inCard(find.text('Delta')).hitTestable(), findsOneWidget);
    expect(_inChat(find.text('Alpha')).hitTestable(), findsOneWidget);
    expect(_inChat(find.text('Delta')).hitTestable(), findsOneWidget);

    // Submit from chat → card shows answered and never sends twice.
    await tester.tap(
      _inChat(find.byKey(const ValueKey('ask_submit_summary_button'))),
    );
    await _settle(tester);
    expect(chatAnswers, hasLength(1));
    final payload = jsonDecode(chatAnswers.single) as Map<String, dynamic>;
    expect(payload['answers'], {
      'First question?': 'Alpha',
      'Second question?': 'Delta',
    });
    expect(
      find.byKey(const ValueKey('session_card_question_answered')),
      findsOneWidget,
    );
    expect(cardAnswers, isEmpty);
  });

  testWidgets('custom text typed on the card appears in chat', (tester) async {
    tester.view.physicalSize = const Size(1800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _sideBySide(
        permission: _multiQuestionPermission,
        onCardAnswer: (_, _) {},
        onChatAnswer: (_, _) {},
      ),
    );
    await _settle(tester);

    await tester.tap(_inCard(find.text('Other answer...')));
    await _settle(tester);
    await tester.enterText(_inCard(find.byType(TextField)), 'My own idea');
    await _settle(tester);

    expect(_inChat(find.text('My own idea')), findsOneWidget);
  });

  testWidgets('draft is discarded once no surface shows it', (tester) async {
    tester.view.physicalSize = const Size(1800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _sideBySide(
        permission: _multiQuestionPermission,
        onCardAnswer: (_, _) {},
        onChatAnswer: (_, _) {},
      ),
    );
    await _settle(tester);
    await tester.tap(_inCard(find.text('Alpha')));
    await _settle(tester);

    // Chat closes: the card still holds the draft.
    await tester.pumpWidget(
      _sideBySide(
        permission: _multiQuestionPermission,
        onCardAnswer: (_, _) {},
        onChatAnswer: (_, _) {},
        showChat: false,
      ),
    );
    await _settle(tester);
    expect(QuestionDraftStore.instance.contains('sync-multi'), isTrue);
    expect(_inCard(find.text('2 of 3')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await _settle(tester);
    expect(QuestionDraftStore.instance.contains('sync-multi'), isFalse);
  });
}
