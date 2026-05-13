import 'dart:async';

import 'package:ccpocket/features/claude_session/claude_session_screen.dart';
import 'package:ccpocket/features/codex_session/codex_session_screen.dart';
import 'package:ccpocket/features/settings/state/settings_cubit.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/providers/bridge_cubits.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:ccpocket/services/database_service.dart';
import 'package:ccpocket/services/draft_service.dart';
import 'package:ccpocket/services/prompt_history_service.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingBridgeService extends BridgeService {
  final _messageController = StreamController<ServerMessage>.broadcast();
  final _taggedController =
      StreamController<(ServerMessage, String?)>.broadcast();
  final _connectionController =
      StreamController<BridgeConnectionState>.broadcast();
  final _fileListController = StreamController<List<String>>.broadcast();
  final _sessionListController =
      StreamController<List<SessionInfo>>.broadcast();

  final requestedFileLists = <String>[];

  void emitMessage(ServerMessage msg, {String? sessionId}) {
    _taggedController.add((msg, sessionId));
    _messageController.add(msg);
  }

  @override
  Stream<ServerMessage> get messages => _messageController.stream;

  @override
  Stream<BridgeConnectionState> get connectionStatus =>
      _connectionController.stream;

  @override
  Stream<List<String>> get fileList => _fileListController.stream;

  @override
  Stream<List<SessionInfo>> get sessionList => _sessionListController.stream;

  @override
  bool get isConnected => true;

  @override
  String? get httpBaseUrl => 'http://localhost:8765';

  @override
  void requestFileList(String projectPath) {
    requestedFileLists.add(projectPath);
  }

  @override
  void send(ClientMessage message) {}

  @override
  void interrupt(String sessionId) {}

  @override
  void requestSessionList() {}

  @override
  void requestSessionHistory(String sessionId) {}

  @override
  void stopSession(String sessionId) {}

  @override
  Stream<ServerMessage> messagesForSession(String sessionId) {
    return _taggedController.stream
        .where((pair) => pair.$2 == null || pair.$2 == sessionId)
        .map((pair) => pair.$1);
  }

  @override
  void dispose() {
    _messageController.close();
    _taggedController.close();
    _connectionController.close();
    _fileListController.close();
    _sessionListController.close();
    super.dispose();
  }
}

Future<Widget> _wrap(Widget child, _RecordingBridgeService bridge) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    theme: AppTheme.darkTheme,
    home: MultiRepositoryProvider(
      providers: [
        RepositoryProvider<BridgeService>.value(value: bridge),
        RepositoryProvider<DraftService>.value(value: DraftService(prefs)),
        RepositoryProvider<PromptHistoryService>.value(
          value: PromptHistoryService(DatabaseService()),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<ConnectionCubit>(
            create: (_) => ConnectionCubit(
              BridgeConnectionState.connected,
              bridge.connectionStatus,
            ),
          ),
          BlocProvider<FileListCubit>(
            create: (_) => FileListCubit(const <String>[], bridge.fileList),
          ),
          BlocProvider<SettingsCubit>(create: (_) => SettingsCubit(prefs)),
        ],
        child: child,
      ),
    ),
  );
}

void main() {
  group('file list refresh for file peek', () {
    testWidgets('Codex refreshes file list after write-like tool results', (
      tester,
    ) async {
      final bridge = _RecordingBridgeService();
      addTearDown(bridge.dispose);

      await tester.pumpWidget(
        await _wrap(
          const CodexSessionScreen(
            sessionId: 'codex-session',
            projectPath: '/tmp/project',
          ),
          bridge,
        ),
      );
      await tester.pump();

      expect(bridge.requestedFileLists, ['/tmp/project']);

      bridge.emitMessage(
        const ToolResultMessage(
          toolUseId: 'tool-1',
          toolName: 'Write',
          content: 'created docs/install/index.html',
        ),
        sessionId: 'codex-session',
      );
      await tester.pump();

      expect(bridge.requestedFileLists, ['/tmp/project', '/tmp/project']);
    });

    testWidgets('Claude requests file list after pending session resolves', (
      tester,
    ) async {
      final bridge = _RecordingBridgeService();
      addTearDown(bridge.dispose);

      await tester.pumpWidget(
        await _wrap(
          const ClaudeSessionScreen(sessionId: 'pending', isPending: true),
          bridge,
        ),
      );
      await tester.pump();

      expect(bridge.requestedFileLists, isEmpty);

      bridge.emitMessage(
        const SystemMessage(
          subtype: 'session_created',
          sessionId: 'real-session',
          projectPath: '/tmp/project',
        ),
      );
      await tester.pump();

      expect(bridge.requestedFileLists, ['/tmp/project']);
    });

    testWidgets('Claude restores app bar project actions from history', (
      tester,
    ) async {
      final bridge = _RecordingBridgeService();
      addTearDown(bridge.dispose);

      await tester.pumpWidget(
        await _wrap(
          const ClaudeSessionScreen(sessionId: 'claude-session'),
          bridge,
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('appbar_explore_button')), findsNothing);
      expect(find.byKey(const ValueKey('appbar_view_changes')), findsNothing);

      bridge.emitMessage(
        const HistoryMessage(
          messages: [
            SystemMessage(
              subtype: 'session_created',
              sessionId: 'claude-session',
              projectPath: '/tmp/project',
            ),
            StatusMessage(status: ProcessStatus.idle),
          ],
        ),
        sessionId: 'claude-session',
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('appbar_explore_button')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('appbar_view_changes')), findsOneWidget);
      expect(bridge.requestedFileLists, contains('/tmp/project'));
    });

    testWidgets('Codex restores app bar project actions from history', (
      tester,
    ) async {
      final bridge = _RecordingBridgeService();
      addTearDown(bridge.dispose);

      await tester.pumpWidget(
        await _wrap(
          const CodexSessionScreen(sessionId: 'codex-session'),
          bridge,
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('appbar_explore_button')), findsNothing);
      expect(find.byKey(const ValueKey('appbar_view_changes')), findsNothing);

      bridge.emitMessage(
        const HistoryMessage(
          messages: [
            SystemMessage(
              subtype: 'session_created',
              sessionId: 'codex-session',
              provider: 'codex',
              projectPath: '/tmp/project',
            ),
            StatusMessage(status: ProcessStatus.idle),
          ],
        ),
        sessionId: 'codex-session',
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('appbar_explore_button')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('appbar_view_changes')), findsOneWidget);
      expect(bridge.requestedFileLists, contains('/tmp/project'));
    });

    testWidgets(
      'Codex shows join command copy action when bridge provides it',
      (tester) async {
        final bridge = _RecordingBridgeService();
        addTearDown(bridge.dispose);

        await tester.pumpWidget(
          await _wrap(
            const CodexSessionScreen(sessionId: 'codex-session'),
            bridge,
          ),
        );
        await tester.pump();

        expect(
          find.byKey(const ValueKey('appbar_copy_codex_join_button')),
          findsNothing,
        );

        bridge.emitMessage(
          const SystemMessage(
            subtype: 'init',
            provider: 'codex',
            sessionId: 'thr_123',
            codexCliJoin: CodexCliJoinTarget(
              url: 'ws://127.0.0.1:8767',
              command: 'codex resume thr_123 --remote ws://127.0.0.1:8767',
            ),
          ),
          sessionId: 'codex-session',
        );
        await tester.pump();

        expect(
          find.byKey(const ValueKey('appbar_copy_codex_join_button')),
          findsOneWidget,
        );
      },
    );
  });
}
