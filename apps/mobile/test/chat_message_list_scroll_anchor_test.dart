import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

import 'package:ccpocket/features/chat_session/state/chat_session_cubit.dart';
import 'package:ccpocket/features/chat_session/state/streaming_state_cubit.dart';
import 'package:ccpocket/features/chat_session/widgets/anchor_maintaining_auto_scroll_controller.dart';
import 'package:ccpocket/features/chat_session/widgets/chat_message_list.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/message_bubble.dart';

void main() {
  testWidgets('streaming keeps the visible message fixed in the first frame', (
    tester,
  ) async {
    addTearDown(tester.view.resetViewInsets);
    final bridge = _ScrollTestBridge();
    final streamingCubit = StreamingStateCubit();
    final chatCubit = ChatSessionCubit(
      sessionId: 'scroll-anchor',
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
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: Scaffold(
              body: ChatMessageList(
                sessionId: 'scroll-anchor',
                scrollController: controller,
                httpBaseUrl: null,
                onRetryMessage: null,
                collapseToolResults: null,
                isReadingHistory: true,
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
          40,
          (index) => PastMessage(
            role: 'user',
            content: [TextContent(text: 'message $index')],
          ),
        ),
      ),
    );
    bridge.emit(const StatusMessage(status: ProcessStatus.idle));
    await tester.pumpAndSettle();

    final scrollFuture = controller.scrollToIndex(
      35,
      preferPosition: AutoScrollPosition.middle,
      duration: const Duration(milliseconds: 1),
    );
    await tester.pumpAndSettle();
    await scrollFuture;
    final target = find.text('message 35');
    expect(target, findsOneWidget);

    final beforeStreamingStart = tester.getTopLeft(target).dy;
    streamingCubit.appendText('short');
    await tester.pump();
    expect(tester.getTopLeft(target).dy, closeTo(beforeStreamingStart, 1));
    await tester.pump();
    expect(tester.getTopLeft(target).dy, closeTo(beforeStreamingStart, 1));
    final streamingEntry = find.byWidgetPredicate(
      (widget) =>
          widget is ChatEntryWidget && widget.entry is StreamingChatEntry,
    );
    expect(streamingEntry, findsOneWidget);
    final before = tester.getTopLeft(target).dy;
    final offsetBefore = controller.offset;
    final streamingHeightBefore = tester.getSize(streamingEntry).height;

    streamingCubit.appendText(
      List.generate(8, (index) => '\n\nstreaming line $index').join(),
    );
    await tester.pump();

    expect(
      tester.getSize(streamingEntry).height,
      greaterThan(streamingHeightBefore),
    );
    expect(tester.getTopLeft(target).dy, closeTo(before, 1));
    expect(controller.offset, greaterThanOrEqualTo(offsetBefore));
    expect(controller.offset, lessThan(controller.position.maxScrollExtent));
    await tester.pump();
    expect(tester.getTopLeft(target).dy, closeTo(before, 1));

    final beforeDelayedUpdate = tester.getTopLeft(target).dy;
    final heightBeforeDelayedUpdate = tester.getSize(streamingEntry).height;
    streamingCubit.appendText('\n\nsmall line one\n\nsmall line two');
    await tester.pump();
    expect(
      tester.getSize(streamingEntry).height,
      closeTo(heightBeforeDelayedUpdate, 0.1),
    );
    await tester.pump(const Duration(milliseconds: 32));
    expect(
      tester.getSize(streamingEntry).height,
      greaterThan(heightBeforeDelayedUpdate),
    );
    expect(tester.getTopLeft(target).dy, closeTo(beforeDelayedUpdate, 1));

    final beforeCombinedResize = tester.getTopLeft(target).dy;
    streamingCubit.appendText('\n\nmore content during keyboard resize');
    tester.view.viewInsets = const FakeViewPadding(bottom: 120);
    await tester.pump();
    expect(tester.getTopLeft(target).dy, closeTo(beforeCombinedResize, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('streaming keeps text fixed while reading inside its own row', (
    tester,
  ) async {
    addTearDown(tester.view.resetViewInsets);
    final bridge = _ScrollTestBridge();
    final streamingCubit = StreamingStateCubit();
    final chatCubit = ChatSessionCubit(
      sessionId: 'scroll-anchor',
      bridge: bridge,
      streamingCubit: streamingCubit,
    );
    final controller = AnchorMaintainingAutoScrollController();
    addTearDown(controller.dispose);
    addTearDown(chatCubit.close);
    addTearDown(streamingCubit.close);
    addTearDown(bridge.dispose);

    streamingCubit.appendText(
      List.generate(100, (index) => 'streaming line $index').join('\n\n'),
    );
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [RepositoryProvider<BridgeService>.value(value: bridge)],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<ChatSessionCubit>.value(value: chatCubit),
            BlocProvider<StreamingStateCubit>.value(value: streamingCubit),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: Scaffold(
              body: ChatMessageList(
                sessionId: 'scroll-anchor',
                scrollController: controller,
                httpBaseUrl: null,
                onRetryMessage: null,
                collapseToolResults: null,
                isReadingHistory: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    bridge.emit(const StatusMessage(status: ProcessStatus.idle));
    await tester.pump(const Duration(milliseconds: 100));

    expect(controller.position.maxScrollExtent, greaterThan(500));
    controller.jumpTo(400);
    await tester.pump();
    final streamingEntry = find.byWidgetPredicate(
      (widget) =>
          widget is ChatEntryWidget && widget.entry is StreamingChatEntry,
    );

    final topBefore = tester.getTopLeft(streamingEntry).dy;
    final offsetBefore = controller.offset;
    streamingCubit.appendText(
      List.generate(12, (index) => '\n\nnew line $index').join(),
    );
    await tester.pump();

    expect(tester.getTopLeft(streamingEntry).dy, closeTo(topBefore, 1));
    expect(controller.offset, greaterThan(offsetBefore));

    final heightBeforeInlineDelta = tester.getSize(streamingEntry).height;
    final offsetBeforeInlineDelta = controller.offset;
    streamingCubit.appendText('x');
    await tester.pump();

    expect(
      tester.getSize(streamingEntry).height,
      closeTo(heightBeforeInlineDelta, 0.1),
    );
    expect(controller.offset, closeTo(offsetBeforeInlineDelta, 0.1));

    final gesture = await tester.startGesture(const Offset(200, 300));
    await gesture.moveBy(const Offset(0, -24));
    await tester.pump();
    final topDuringDrag = tester.getTopLeft(streamingEntry).dy;
    tester.view.viewInsets = const FakeViewPadding(bottom: 120);
    streamingCubit.appendText(
      List.generate(8, (index) => '\n\nmore line $index').join(),
    );
    await tester.pump();

    expect(tester.getTopLeft(streamingEntry).dy, closeTo(topDuringDrag, 1));
    expect(tester.takeException(), isNull);
    await gesture.up();
  });

  testWidgets('offers older history without building it into the first page', (
    tester,
  ) async {
    final bridge = _ScrollTestBridge()..hasOlder = true;
    final streamingCubit = StreamingStateCubit();
    final chatCubit = ChatSessionCubit(
      sessionId: 'scroll-anchor',
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
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: Scaffold(
              body: ChatMessageList(
                sessionId: 'scroll-anchor',
                scrollController: controller,
                httpBaseUrl: null,
                onRetryMessage: null,
                collapseToolResults: null,
              ),
            ),
          ),
        ),
      ),
    );
    bridge.emit(const StatusMessage(status: ProcessStatus.idle));
    await tester.pump();

    expect(find.text('Load earlier messages'), findsOneWidget);
    await tester.tap(find.text('Load earlier messages'));
    expect(bridge.olderHistoryRequests, 1);
  });
}

class _ScrollTestBridge extends BridgeService {
  final _messages = StreamController<(ServerMessage, String?)>.broadcast();
  bool hasOlder = false;
  int olderHistoryRequests = 0;

  void emit(ServerMessage message) => _messages.add((message, 'scroll-anchor'));

  @override
  Stream<ServerMessage> messagesForSession(String sessionId) => _messages.stream
      .where((event) => event.$2 == sessionId)
      .map((event) => event.$1);

  @override
  void requestSessionHistory(String sessionId) {}

  @override
  bool hasOlderSessionHistory(String sessionId) => hasOlder;

  @override
  void requestOlderSessionHistory(String sessionId) {
    olderHistoryRequests++;
  }

  @override
  void send(ClientMessage message) {}

  @override
  void dispose() {
    _messages.close();
    super.dispose();
  }
}
