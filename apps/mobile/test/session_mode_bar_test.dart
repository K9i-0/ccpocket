import 'dart:async';
import 'dart:convert';

import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/features/chat_session/state/chat_session_cubit.dart';
import 'package:ccpocket/features/chat_session/state/streaming_state_cubit.dart';
import 'package:ccpocket/features/chat_session/widgets/session_mode_bar.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockBridgeService extends BridgeService {
  final _messageController = StreamController<ServerMessage>.broadcast();
  final _taggedController =
      StreamController<(ServerMessage, String?)>.broadcast();
  final sentMessages = <ClientMessage>[];

  void emitMessage(ServerMessage msg, {String? sessionId}) {
    _taggedController.add((msg, sessionId));
    _messageController.add(msg);
  }

  @override
  Stream<ServerMessage> get messages => _messageController.stream;

  @override
  Stream<ServerMessage> messagesForSession(String sessionId) {
    return _taggedController.stream
        .where((pair) => pair.$2 == null || pair.$2 == sessionId)
        .map((pair) => pair.$1);
  }

  @override
  void send(ClientMessage message) {
    sentMessages.add(message);
  }

  @override
  void interrupt(String sessionId) {}

  @override
  void stopSession(String sessionId) {}

  @override
  void requestFileList(String projectPath) {}

  @override
  void requestSessionList() {}

  @override
  void requestSessionHistory(String sessionId) {}

  @override
  void dispose() {
    _messageController.close();
    _taggedController.close();
    super.dispose();
  }
}

Widget _wrap(ChatSessionCubit cubit) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    theme: AppTheme.darkTheme,
    home: Scaffold(
      body: BlocProvider<ChatSessionCubit>.value(
        value: cubit,
        child: const SessionModeBar(),
      ),
    ),
  );
}

Map<String, dynamic> _decode(ClientMessage message) =>
    jsonDecode(message.toJson()) as Map<String, dynamic>;

void main() {
  late _MockBridgeService bridge;
  late StreamingStateCubit streamingCubit;
  late ChatSessionCubit cubit;

  setUp(() async {
    bridge = _MockBridgeService();
    streamingCubit = StreamingStateCubit();
    cubit = ChatSessionCubit(
      sessionId: 'codex-session',
      provider: Provider.codex,
      bridge: bridge,
      streamingCubit: streamingCubit,
    );
    await Future<void>.microtask(() {});
  });

  tearDown(() async {
    await cubit.close();
    await streamingCubit.close();
    bridge.dispose();
  });

  testWidgets('claude keeps permission and sandbox grouped', (tester) async {
    final claudeCubit = ChatSessionCubit(
      sessionId: 'claude-session',
      provider: Provider.claude,
      bridge: bridge,
      streamingCubit: streamingCubit,
    );
    addTearDown(claudeCubit.close);

    bridge.emitMessage(
      const SystemMessage(
        subtype: 'set_permission_mode',
        provider: 'claude',
        permissionMode: 'plan',
      ),
      sessionId: 'claude-session',
    );
    bridge.emitMessage(
      const StatusMessage(status: ProcessStatus.running),
      sessionId: 'claude-session',
    );

    await tester.pumpWidget(_wrap(claudeCubit));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Plan Off'), findsNothing);
    expect(find.text('Plan On'), findsNothing);
    expect(find.text('Plan'), findsOneWidget);
    expect(find.byType(PermissionModeChip), findsOneWidget);
    expect(find.byKey(const ValueKey('plan_mode_chip_glow')), findsNothing);
  });

  testWidgets('renders chips in Plan, Execution, Sandbox order', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(cubit));
    await tester.pump(const Duration(milliseconds: 100));

    final plan = tester.getCenter(find.text('Plan Off')).dx;
    final execution = tester.getCenter(find.text('Default')).dx;
    final sandbox = tester.getCenter(find.text('Sandbox')).dx;

    expect(plan, lessThan(execution));
    expect(execution, lessThan(sandbox));
  });

  testWidgets('shows bar-level glow when running in plan mode', (tester) async {
    bridge.emitMessage(
      const SystemMessage(
        subtype: 'set_permission_mode',
        provider: 'codex',
        permissionMode: 'plan',
        executionMode: 'default',
        planMode: true,
      ),
      sessionId: 'codex-session',
    );
    bridge.emitMessage(
      const StatusMessage(status: ProcessStatus.running),
      sessionId: 'codex-session',
    );
    await tester.pumpWidget(_wrap(cubit));
    await tester.pump(const Duration(milliseconds: 100));

    // Chip-local glow is off; bar-level rotating glow is used instead
    expect(find.byKey(const ValueKey('plan_mode_chip_glow')), findsNothing);
  });

  testWidgets('plan toggle updates in place for idle codex session', (
    tester,
  ) async {
    bridge.emitMessage(
      const StatusMessage(status: ProcessStatus.idle),
      sessionId: 'codex-session',
    );
    await tester.pumpWidget(_wrap(cubit));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Plan Off'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Enable Plan Mode'), findsNothing);
    expect(bridge.sentMessages, isNotEmpty);
    final message = _decode(bridge.sentMessages.last);
    expect(message['type'], 'set_permission_mode');
    expect(message['planMode'], true);
    expect(message['executionMode'], 'default');
  });

  testWidgets('execution change still shows restart confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(cubit));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Default'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Full Access'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Change Execution Mode'), findsOneWidget);
    expect(find.textContaining('will restart the session'), findsOneWidget);
  });

  testWidgets('sandbox change still shows restart confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(cubit));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Sandbox'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Sandbox Off'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Change Sandbox Mode'), findsOneWidget);
    expect(find.textContaining('will restart the session'), findsOneWidget);
  });
}
