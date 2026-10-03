import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ccpocket/features/chat_session/state/chat_session_cubit.dart';
import 'package:ccpocket/features/chat_session/state/streaming_state_cubit.dart';
import 'package:ccpocket/features/chat_session/widgets/chat_message_list.dart';
import 'package:ccpocket/features/chat_session/widgets/lite_mode_controls.dart';
import 'package:ccpocket/features/settings/state/settings_cubit.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/providers/bridge_cubits.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/message_bubble.dart';

import 'chat_session_cubit_test.dart' show MockBridgeService;

void main() {
  test('compact durations cover unit boundaries and multi-day goals', () {
    final ja = lookupAppLocalizations(const Locale('ja'));
    final en = lookupAppLocalizations(const Locale('en'));
    for (final (seconds, expected) in [
      (-1, '0秒'),
      (0, '0秒'),
      (59, '59秒'),
      (60, '1分0秒'),
      (728, '12分8秒'),
      (3599, '59分59秒'),
      (3600, '1時間0分'),
      (11520, '3時間12分'),
      (86399, '23時間59分'),
      (86400, '1日0時間'),
      (97200, '1日3時間'),
      (86400000, '1000日0時間'),
    ]) {
      expect(formatLiteModeDuration(Duration(seconds: seconds), ja), expected);
    }
    expect(formatLiteModeDuration(const Duration(hours: 27), en), '1d 3h');
  });

  testWidgets(
    'session picker applies override and restores default inheritance',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsCubit(await SharedPreferences.getInstance());
      addTearDown(settings.close);
      await tester.pumpWidget(
        BlocProvider.value(
          value: settings,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('ja'),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showChatDisplayModeSheet(context, 'session'),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('パフォーマンスモード'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('display_mode_lite')));
      await tester.pumpAndSettle();
      expect(settings.state.liteModeForSession('session'), true);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('display_mode_default')));
      await tester.pumpAndSettle();
      expect(settings.state.liteModeForSession('session'), false);
      expect(settings.state.sessionLiteModes, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'live mode switching removes tool rows and restores original transcript',
    (tester) async {
      final bridge = MockBridgeService();
      final streaming = StreamingStateCubit();
      final chat = ChatSessionCubit(
        sessionId: 's',
        bridge: bridge,
        streamingCubit: streaming,
      );
      final files = FileListCubit(const [], const Stream.empty());
      addTearDown(files.close);
      final controller = AutoScrollController();
      final lite = ValueNotifier(false);
      addTearDown(bridge.dispose);
      addTearDown(streaming.close);
      addTearDown(chat.close);
      addTearDown(controller.dispose);
      addTearDown(lite.dispose);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: chat),
            BlocProvider.value(value: streaming),
            BlocProvider.value(value: files),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ValueListenableBuilder<bool>(
                valueListenable: lite,
                builder: (_, enabled, _) => ChatMessageList(
                  sessionId: 's',
                  scrollController: controller,
                  httpBaseUrl: null,
                  onRetryMessage: null,
                  collapseToolResults: null,
                  liteMode: enabled,
                ),
              ),
            ),
          ),
        ),
      );
      bridge.emitMessage(
        const AssistantServerMessage(
          message: AssistantMessage(
            id: 'a',
            role: 'assistant',
            model: 'test',
            content: [
              TextContent(text: 'Visible answer'),
              ToolUseContent(
                id: 't',
                name: 'Read',
                input: {'file_path': '/tmp/large'},
              ),
            ],
          ),
        ),
      );
      bridge.emitMessage(
        const ToolResultMessage(toolUseId: 't', content: 'Tool output'),
      );
      bridge.emitMessage(const StatusMessage(status: ProcessStatus.idle));
      await tester.pumpAndSettle();
      expect(find.byType(ChatEntryWidget), findsNWidgets(2));
      lite.value = true;
      await tester.pumpAndSettle();
      expect(find.byType(ChatEntryWidget), findsOneWidget);
      expect(find.text('Visible answer', findRichText: true), findsOneWidget);
      expect(chat.state.entries.length, 2);
      final projected = tester
          .widget<ChatEntryWidget>(find.byType(ChatEntryWidget))
          .entry;
      bridge.emitMessage(const StatusMessage(status: ProcessStatus.running));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ChatEntryWidget>(find.byType(ChatEntryWidget)).entry,
        same(projected),
      );
      lite.value = false;
      await tester.pumpAndSettle();
      expect(find.byType(ChatEntryWidget), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'activity survives display toggles, counts deltas, and resets per run',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsCubit(await SharedPreferences.getInstance())
        ..setLiteMode(true);
      final bridge = MockBridgeService();
      final streaming = StreamingStateCubit();
      final chat = ChatSessionCubit(
        sessionId: 's',
        bridge: bridge,
        streamingCubit: streaming,
      );
      addTearDown(settings.close);
      addTearDown(bridge.dispose);
      addTearDown(streaming.close);
      addTearDown(chat.close);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: settings),
            BlocProvider.value(value: chat),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: const MediaQuery(
              data: MediaQueryData(padding: EdgeInsets.only(bottom: 34)),
              child: Scaffold(body: LiteModeActivityBar(sessionId: 's')),
            ),
          ),
        ),
      );
      bridge.emitMessage(const StatusMessage(status: ProcessStatus.running));
      await tester.pump();
      expect(chat.activityObservedSince, isNotNull);
      final started = chat.activityObservedSince;
      settings.setLiteMode(false);
      await tester.pump();
      settings.setLiteMode(true);
      await tester.pump();
      expect(chat.activityObservedSince, started);
      bridge.emitMessage(const StreamDeltaMessage(text: 'hello'));
      await tester.pump(const Duration(seconds: 1));
      expect(chat.lastAgentActivityAt, isNotNull);
      expect(find.textContaining('Received'), findsOneWidget);
      bridge.emitMessage(const StatusMessage(status: ProcessStatus.idle));
      await tester.pump();
      expect(chat.activityObservedSince, isNull);
      await tester.pump();
      expect(find.textContaining('Idle'), findsOneWidget);
      expect(find.textContaining('Received'), findsNothing);
      bridge.emitMessage(
        const SessionContextMessage(
          sessionId: 's',
          context: SessionInfo(
            id: 's',
            projectPath: '/repo',
            status: 'running',
            createdAt: '',
            lastActivityAt: '',
            gitBranch: '',
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(chat.activityObservedSince, isNotNull);
      expect(find.textContaining('Observed'), findsOneWidget);
      bridge.emitMessage(
        const PermissionRequestMessage(
          toolUseId: 'approval',
          toolName: 'Bash',
          input: {'command': 'pwd'},
        ),
      );
      await tester.pump();
      await tester.pump();
      final padding =
          tester
                  .widget<Padding>(
                    find.byKey(const ValueKey('lite_mode_activity_indicator')),
                  )
                  .padding
              as EdgeInsets;
      expect(padding.bottom, 40);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
