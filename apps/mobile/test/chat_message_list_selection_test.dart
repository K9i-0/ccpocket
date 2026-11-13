import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/features/chat_session/state/chat_session_cubit.dart';
import 'package:ccpocket/features/chat_session/state/streaming_state_cubit.dart';
import 'package:ccpocket/features/chat_session/widgets/anchor_maintaining_auto_scroll_controller.dart';
import 'package:ccpocket/features/chat_session/widgets/chat_message_list.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/l10n/app_localizations_delegates.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/providers/bridge_cubits.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:ccpocket/theme/app_theme.dart';

void main() {
  Future<void> pumpList(
    WidgetTester tester, {
    Widget? footer,
    String role = 'user',
  }) async {
    // SelectableRegion only clears its selection on focus loss while resumed.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final bridge = _SelectionTestBridge();
    final streamingCubit = StreamingStateCubit();
    final chatCubit = ChatSessionCubit(
      sessionId: 'selection',
      bridge: bridge,
      streamingCubit: streamingCubit,
    );
    final controller = AnchorMaintainingAutoScrollController();
    addTearDown(controller.dispose);
    addTearDown(chatCubit.close);
    addTearDown(streamingCubit.close);
    addTearDown(bridge.dispose);

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [RepositoryProvider<BridgeService>.value(value: bridge)],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<ChatSessionCubit>.value(value: chatCubit),
            BlocProvider<StreamingStateCubit>.value(value: streamingCubit),
            BlocProvider<FileListCubit>(
              create: (_) => FileListCubit(const [], const Stream.empty()),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: Scaffold(
              body: Column(
                children: [
                  Expanded(
                    child: ChatMessageList(
                      sessionId: 'selection',
                      scrollController: controller,
                      httpBaseUrl: null,
                      onRetryMessage: null,
                      collapseToolResults: null,
                    ),
                  ),
                  ?footer,
                ],
              ),
            ),
          ),
        ),
      ),
    );

    bridge.emit(
      PastHistoryMessage(
        claudeSessionId: 'past',
        messages: List.generate(
          30,
          (index) => PastMessage(
            role: role,
            content: [TextContent(text: 'message $index selectable words')],
          ),
        ),
      ),
    );
    bridge.emit(const StatusMessage(status: ProcessStatus.idle));
    await tester.pumpAndSettle();
  }

  List<TextSelection> selectionsOf(WidgetTester tester, Finder text) {
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: text, matching: find.byType(RichText)),
    );
    return paragraph.selections;
  }

  testWidgets('dragging the list keeps a user message text selection', (
    tester,
  ) async {
    await pumpList(tester);

    final target = find.text('message 29 selectable words');
    expect(target, findsOneWidget);
    await tester.longPress(target);
    await tester.pumpAndSettle();

    expect(selectionsOf(tester, target), isNotEmpty);
    expect(isEditableTextFocused(), isFalse);
    final listTopBefore = tester.getTopLeft(target).dy;

    // A user drag on the list must not steal focus from the selection.
    await tester.drag(
      find.byType(ListView),
      const Offset(0, 40),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(target, findsOneWidget);
    // The list actually scrolled, so a UserScrollNotification was sent.
    expect(tester.getTopLeft(target).dy, isNot(listTopBefore));
    expect(selectionsOf(tester, target), isNotEmpty);
  });

  testWidgets('dragging the list keeps an assistant markdown selection', (
    tester,
  ) async {
    await pumpList(tester, role: 'assistant');

    final target = find.text('message 29 selectable words');
    expect(target, findsOneWidget);
    // Assistant markdown is selected through a SelectionArea, not an
    // EditableText per paragraph.
    expect(
      find.ancestor(of: target, matching: find.byType(SelectionArea)),
      findsOneWidget,
    );
    expect(
      find.ancestor(of: target, matching: find.byType(EditableText)),
      findsNothing,
    );
    await tester.longPress(target);
    await tester.pumpAndSettle();

    expect(selectionsOf(tester, target), isNotEmpty);
    expect(isEditableTextFocused(), isFalse);
    final listTopBefore = tester.getTopLeft(target).dy;

    await tester.drag(
      find.byType(ListView),
      const Offset(0, 40),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(target, findsOneWidget);
    expect(tester.getTopLeft(target).dy, isNot(listTopBefore));
    expect(selectionsOf(tester, target), isNotEmpty);
  });

  testWidgets('dragging the list still dismisses the text input focus', (
    tester,
  ) async {
    final inputFocus = FocusNode();
    addTearDown(inputFocus.dispose);
    await pumpList(tester, footer: TextField(focusNode: inputFocus));

    inputFocus.requestFocus();
    await tester.pump();
    expect(inputFocus.hasFocus, isTrue);
    expect(isEditableTextFocused(), isTrue);

    await tester.drag(
      find.byType(ListView),
      const Offset(0, 40),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(inputFocus.hasFocus, isFalse);
  });
}

class _SelectionTestBridge extends BridgeService {
  final _messages = StreamController<(ServerMessage, String?)>.broadcast();

  void emit(ServerMessage message) => _messages.add((message, 'selection'));

  @override
  Stream<ServerMessage> messagesForSession(String sessionId) => _messages.stream
      .where((event) => event.$2 == sessionId)
      .map((event) => event.$1);

  @override
  void requestSessionHistory(String sessionId) {}

  @override
  void send(ClientMessage message) {}

  @override
  void dispose() {
    _messages.close();
    super.dispose();
  }
}
