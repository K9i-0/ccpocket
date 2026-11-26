import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_kit/markdown_kit.dart';

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
import 'package:ccpocket/widgets/bubbles/assistant_bubble.dart';
import 'package:ccpocket/widgets/bubbles/streaming_bubble.dart';
import 'package:ccpocket/widgets/bubbles/swarm_post_card.dart';
import 'package:ccpocket/widgets/bubbles/user_bubble.dart';
import 'package:ccpocket/widgets/markdown/ccpocket_markdown.dart';

void main() {
  Future<
    ({
      AnchorMaintainingAutoScrollController controller,
      _SelectionTestBridge bridge,
      StreamingStateCubit streamingCubit,
    })
  >
  pumpListHarness(
    WidgetTester tester, {
    Widget? footer,
    String role = 'user',
    List<PastMessage>? customMessages,
    bool seedHistory = true,
    void Function(UserChatEntry, String)? onEditMessage,
    void Function(UserChatEntry)? onRewindMessage,
  }) async {
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
                      onEditMessage: onEditMessage,
                      onRewindMessage: onRewindMessage,
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

    if (seedHistory) {
      bridge.emit(
        PastHistoryMessage(
          claudeSessionId: 'past',
          messages:
              customMessages ??
              List.generate(
                30,
                (index) => PastMessage(
                  role: role,
                  content: [
                    TextContent(text: 'message $index selectable words'),
                  ],
                ),
              ),
        ),
      );
      bridge.emit(const StatusMessage(status: ProcessStatus.idle));
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
    return (
      controller: controller,
      bridge: bridge,
      streamingCubit: streamingCubit,
    );
  }

  Future<AnchorMaintainingAutoScrollController> pumpList(
    WidgetTester tester, {
    Widget? footer,
    String role = 'user',
    List<PastMessage>? customMessages,
  }) async {
    final harness = await pumpListHarness(
      tester,
      footer: footer,
      role: role,
      customMessages: customMessages,
    );
    return harness.controller;
  }

  MarkdownSelectionScopeState selectionScopeState(WidgetTester tester) {
    return tester.state<MarkdownSelectionScopeState>(
      find.byType(MarkdownSelectionScope),
    );
  }

  testWidgets('dragging the list keeps a user message text selection', (
    tester,
  ) async {
    await pumpList(tester);

    final target = find.text('message 29 selectable words', findRichText: true);
    expect(target, findsOneWidget);
    await tester.longPress(target);
    await tester.pumpAndSettle();

    final scope = selectionScopeState(tester);
    expect(scope.controller.hasSelection, isTrue);
    expect(isEditableTextFocused(), isFalse);
    final listTopBefore = tester.getTopLeft(target).dy;

    // A user drag on the list must not clear the selection.
    await tester.drag(
      find.byType(ListView),
      const Offset(0, 40),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    expect(target, findsOneWidget);
    // The list actually scrolled, so a UserScrollNotification was sent.
    expect(tester.getTopLeft(target).dy, isNot(listTopBefore));
    expect(scope.controller.hasSelection, isTrue);
  });

  testWidgets('dragging the list keeps an assistant markdown selection', (
    tester,
  ) async {
    await pumpList(tester, role: 'assistant');

    final target = find.text('message 29 selectable words', findRichText: true);
    expect(target, findsOneWidget);
    expect(
      find.ancestor(of: target, matching: find.byType(CcpocketSelectionScope)),
      findsOneWidget,
    );
    expect(
      find.ancestor(of: target, matching: find.byType(EditableText)),
      findsNothing,
    );
    await tester.longPress(target);
    await tester.pumpAndSettle();

    final scope = selectionScopeState(tester);
    expect(scope.controller.hasSelection, isTrue);
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
    expect(scope.controller.hasSelection, isTrue);
  });

  testWidgets(
    'touch handle 150ms pause + vertical drag in reverse ListView expands selection without clearing or scrolling',
    (tester) async {
      final scrollController = await pumpList(
        tester,
        customMessages: [
          for (var i = 0; i < 15; i++)
            PastMessage(
              role: 'assistant',
              content: [TextContent(text: 'Earlier message $i for scrolling')],
            ),
          const PastMessage(
            role: 'assistant',
            content: [
              TextContent(
                text:
                    'First paragraph alpha beta gamma.\n\n'
                    'Second paragraph delta epsilon zeta.\n\n'
                    'Third paragraph eta theta iota.',
              ),
            ],
          ),
        ],
      );

      final firstPara = find.text(
        'First paragraph alpha beta gamma.',
        findRichText: true,
      );
      expect(firstPara, findsOneWidget);

      await tester.longPress(firstPara);
      await tester.pumpAndSettle();

      final scope = selectionScopeState(tester);
      expect(scope.controller.hasSelection, isTrue);
      final initialSelection = scope.selectedPlainText;
      final scrollBefore = scrollController.offset;

      final endHandle = find.byKey(MarkdownSelectionHandleOverlay.endHandleKey);
      expect(endHandle, findsOneWidget);

      final handleCenter = tester.getCenter(endHandle);
      final thirdParaCenter = tester.getCenter(
        find.text('Third paragraph eta theta iota.', findRichText: true),
      );

      final gesture = await tester.startGesture(
        handleCenter,
        kind: PointerDeviceKind.touch,
      );
      await tester.pump(const Duration(milliseconds: 150));
      final totalDy = thirdParaCenter.dy - handleCenter.dy;
      for (var step = 1; step <= 4; step++) {
        await gesture.moveTo(
          Offset(handleCenter.dx, handleCenter.dy + totalDy * step / 4),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(scope.controller.hasSelection, isTrue);
      expect(
        scope.selectedPlainText.length,
        greaterThan(initialSelection.length),
      );
      expect(scope.selectedPlainText, contains('Second paragraph'));
      expect(scrollController.offset, closeTo(scrollBefore, 1.0));
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets(
    'non-handle 150ms pause + vertical drag scrolls reverse ListView while keeping selection active',
    (tester) async {
      final scrollController = await pumpList(tester, role: 'assistant');

      final target = find.text(
        'message 29 selectable words',
        findRichText: true,
      );
      await tester.longPress(target);
      await tester.pumpAndSettle();

      final scope = selectionScopeState(tester);
      expect(scope.controller.hasSelection, isTrue);
      final selectedBefore = scope.selectedPlainText;
      final scrollBefore = scrollController.offset;

      // Touch on another message (away from both selection handles), pause 150ms,
      // then drag vertically to scroll the reverse ListView.
      final otherMessage = find.text(
        'message 25 selectable words',
        findRichText: true,
      );
      expect(otherMessage, findsOneWidget);
      final startPoint = tester.getCenter(otherMessage);

      final gesture = await tester.startGesture(
        startPoint,
        kind: PointerDeviceKind.touch,
      );
      await tester.pump(const Duration(milliseconds: 150));
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(scrollController.offset, greaterThan(scrollBefore));
      expect(scope.controller.hasSelection, isTrue);
      expect(scope.selectedPlainText, selectedBefore);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets(
    'Copy plain text preserves separators without bullets/code headers and Copy as Markdown reconstructs syntax',
    (tester) async {
      final copied = <String?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String?);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      const markdown =
          '# Title\n\n'
          '- item one\n'
          '- item two\n\n'
          '| ColA | ColB |\n'
          '| --- | --- |\n'
          '| v1 | v2 |\n\n'
          '```dart\n'
          'final x = 1;\n'
          '```';

      await pumpList(
        tester,
        customMessages: const [
          PastMessage(
            role: 'assistant',
            content: [TextContent(text: markdown)],
          ),
        ],
      );

      final titleFinder = find.text('Title', findRichText: true);
      await tester.longPress(titleFinder);
      await tester.pumpAndSettle();

      final scope = selectionScopeState(tester);
      scope.selectAll();
      await tester.pumpAndSettle();

      // Plain text copy preserves \n\n between blocks, \n in lists/rows, \t in
      // tables, and excludes bullet markers and the 'dart' code block header.
      await scope.copySelection();
      expect(
        copied.last,
        'Title\n\nitem one\nitem two\n\nColA\tColB\nv1\tv2\n\nfinal x = 1;',
      );
      expect(copied.last, isNot(contains('- item')));
      expect(copied.last, isNot(contains('dart')));

      // Copy as Markdown reconstructs headings, lists, tables, and code fences.
      await scope.copySelectionAsMarkdown();
      expect(copied.last, contains('# Title'));
      expect(copied.last, contains('- item one\n- item two'));
      expect(copied.last, contains('| ColA | ColB |'));
      expect(copied.last, contains('```dart\nfinal x = 1;\n```'));
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets(
    'dragging the list still dismisses the text input focus on mobile',
    (tester) async {
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
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets('scrolling the list keeps text input focus on desktop', (
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

    expect(inputFocus.hasFocus, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets(
    'macOS right-click on UserBubble while AssistantBubble has selection selects UserBubble word, focuses scope, and opens toolbar',
    (tester) async {
      await pumpListHarness(
        tester,
        onEditMessage: (_, _) {},
        onRewindMessage: (_) {},
        customMessages: const [
          PastMessage(
            role: 'assistant',
            content: [TextContent(text: 'alpha bravo charlie')],
          ),
          PastMessage(
            role: 'user',
            content: [TextContent(text: 'delta epsilon zeta')],
          ),
        ],
      );

      final assistantFinder = find.text(
        'alpha bravo charlie',
        findRichText: true,
      );
      final userFinder = find.text('delta epsilon zeta', findRichText: true);
      expect(assistantFinder, findsOneWidget);
      expect(userFinder, findsOneWidget);

      // Select a word inside AssistantBubble via mouse double-click.
      final assistantRect = tester.getRect(assistantFinder);
      final assistantPoint = Offset(
        assistantRect.left + 12,
        assistantRect.center.dy,
      );
      final click1 = await tester.startGesture(
        assistantPoint,
        kind: PointerDeviceKind.mouse,
      );
      await click1.up();
      await tester.pump(const Duration(milliseconds: 50));
      final click2 = await tester.startGesture(
        assistantPoint,
        kind: PointerDeviceKind.mouse,
      );
      await click2.up();
      await tester.pumpAndSettle();

      final scope = selectionScopeState(tester);
      expect(scope.controller.hasSelection, isTrue);
      expect(scope.selectedPlainText, 'alpha');

      // Move focus elsewhere to verify secondary tap on UserBubble restores focus.
      scope.focusNode.unfocus();
      await tester.pump();
      expect(scope.focusNode.hasFocus, isFalse);

      // Right-click on 'delta' in UserBubble.
      final userRect = tester.getRect(userFinder);
      final deltaPoint = Offset(userRect.left + 12, userRect.center.dy);
      final rightClick1 = await tester.startGesture(
        deltaPoint,
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await rightClick1.up();
      await tester.pumpAndSettle();

      expect(scope.controller.hasSelection, isTrue);
      expect(scope.selectedPlainText, 'delta');
      expect(scope.controller.selection?.base.documentId, startsWith('user_'));
      expect(scope.focusNode.hasFocus, isTrue);
      expect(scope.toolbarIsVisible, isTrue);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Search with Google'), findsOneWidget);
      expect(find.text('Copy as Markdown'), findsNothing);
      expect(find.text('Copy entire message'), findsNothing);

      // Right-click another unselected word ('zeta') in the same UserBubble.
      final zetaPoint = Offset(userRect.right - 12, userRect.center.dy);
      final rightClick2 = await tester.startGesture(
        zetaPoint,
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await rightClick2.up();
      await tester.pumpAndSettle();

      expect(scope.selectedPlainText, 'zeta');
      expect(scope.toolbarIsVisible, isTrue);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'non-macOS right-click on unselected UserBubble while AssistantBubble has selection opens UserBubble context menu',
    (tester) async {
      await pumpListHarness(
        tester,
        onEditMessage: (_, _) {},
        onRewindMessage: (_) {},
        customMessages: const [
          PastMessage(
            role: 'assistant',
            content: [TextContent(text: 'alpha bravo charlie')],
          ),
          PastMessage(
            role: 'user',
            content: [TextContent(text: 'delta epsilon zeta')],
          ),
        ],
      );

      final assistantFinder = find.text(
        'alpha bravo charlie',
        findRichText: true,
      );
      final userFinder = find.text('delta epsilon zeta', findRichText: true);

      // Select 'alpha' in AssistantBubble.
      final assistantRect = tester.getRect(assistantFinder);
      final assistantPoint = Offset(
        assistantRect.left + 12,
        assistantRect.center.dy,
      );
      final click1 = await tester.startGesture(
        assistantPoint,
        kind: PointerDeviceKind.mouse,
      );
      await click1.up();
      await tester.pump(const Duration(milliseconds: 50));
      final click2 = await tester.startGesture(
        assistantPoint,
        kind: PointerDeviceKind.mouse,
      );
      await click2.up();
      await tester.pumpAndSettle();

      final scope = selectionScopeState(tester);
      expect(scope.controller.hasSelection, isTrue);
      expect(scope.selectedPlainText, 'alpha');

      // Right-click unselected text inside UserBubble on non-macOS desktop.
      final userRect = tester.getRect(userFinder);
      final deltaPoint = Offset(userRect.left + 12, userRect.center.dy);
      final rightClick = await tester.startGesture(
        deltaPoint,
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await rightClick.up();
      await tester.pumpAndSettle();

      expect(scope.toolbarIsVisible, isFalse);
      expect(find.text('Copy entire message'), findsOneWidget);
      expect(find.byType(UserBubble), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'streaming-to-finalized selection handoff preserves selection when ResultMessage trails AssistantServerMessage',
    (tester) async {
      final harness = await pumpListHarness(tester, seedHistory: false);
      const streamedText = 'Streaming paragraph alpha beta gamma';

      harness.bridge.emit(const StatusMessage(status: ProcessStatus.running));
      harness.bridge.emit(const UserInputMessage(text: 'Explain streaming'));
      harness.bridge.emit(const StreamDeltaMessage(text: streamedText));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(StreamingBubble), findsOneWidget);
      final streamedFinder = find.text(streamedText, findRichText: true);
      expect(streamedFinder, findsOneWidget);

      await tester.longPress(streamedFinder);
      await tester.pump();

      final scope = selectionScopeState(tester);
      expect(scope.controller.hasSelection, isTrue);
      final selectedBefore = scope.selectedPlainText;
      final docIdBefore = scope.controller.selection?.base.documentId;
      expect(selectedBefore, isNotEmpty);
      expect(docIdBefore, 'streaming_turn_0:text:0');

      // Finalize with AssistantServerMessage followed by ResultMessage.
      harness.bridge.emit(
        const AssistantServerMessage(
          message: AssistantMessage(
            id: 'final-assistant-1',
            role: 'assistant',
            model: 'claude-sonnet',
            content: [TextContent(text: streamedText)],
          ),
        ),
      );
      harness.bridge.emit(
        const ResultMessage(subtype: 'success', result: 'Done'),
      );
      harness.bridge.emit(const StatusMessage(status: ProcessStatus.idle));
      await tester.pumpAndSettle();

      expect(find.byType(StreamingBubble), findsNothing);
      expect(find.byType(AssistantBubble), findsOneWidget);
      expect(scope.controller.hasSelection, isTrue);
      expect(scope.selectedPlainText, selectedBefore);
      expect(scope.controller.selection?.base.documentId, docIdBefore);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets(
    'SwarmPostCard inside AssistantBubble receives stable documentId and documentOrder',
    (tester) async {
      final harness = await pumpListHarness(tester, seedHistory: false);

      harness.bridge.emit(
        const AssistantServerMessage(
          message: AssistantMessage(
            id: 'swarm-msg-1',
            role: 'assistant',
            model: 'antigravity',
            content: [
              ToolUseContent(
                id: 'tu-swarm-1',
                name: swarmPostToolName,
                input: {
                  'agent': 'verifier',
                  'seq': 7,
                  'text': 'Swarm markdown body content',
                },
              ),
            ],
          ),
        ),
      );
      harness.bridge.emit(const StatusMessage(status: ProcessStatus.idle));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('swarm_post_toggle_7')));
      await tester.pumpAndSettle();

      final swarmMarkdown = tester.widget<CcpocketMarkdown>(
        find.descendant(
          of: find.byType(SwarmPostCard),
          matching: find.byType(CcpocketMarkdown),
        ),
      );
      expect(swarmMarkdown.documentId, isNotNull);
      expect(swarmMarkdown.documentId, endsWith(':swarm:tu-swarm-1'));
      expect(swarmMarkdown.documentOrder, 0);
    },
  );
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
