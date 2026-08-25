import 'dart:async';

import 'package:ccpocket/features/chat_session/state/chat_session_cubit.dart';
import 'package:ccpocket/features/chat_session/state/streaming_state_cubit.dart';
import 'package:ccpocket/features/chat_session/widgets/session_composer_activity_indicator.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestBridgeService extends BridgeService {
  final _messages = StreamController<(ServerMessage, String?)>.broadcast();

  void emit(ServerMessage message, {required String sessionId}) {
    _messages.add((message, sessionId));
  }

  @override
  Stream<ServerMessage> messagesForSession(String sessionId) => _messages.stream
      .where((event) => event.$2 == sessionId)
      .map((event) => event.$1);

  @override
  void dispose() {
    _messages.close();
    super.dispose();
  }
}

void main() {
  testWidgets('rebases elapsed time when history arrives after the screen', (
    tester,
  ) async {
    final now = DateTime.utc(2026, 8, 23, 12, 6, 12);
    final bridge = _TestBridgeService();
    final streamingCubit = StreamingStateCubit();
    final sessionCubit = ChatSessionCubit(
      sessionId: 'late-history',
      bridge: bridge,
      streamingCubit: streamingCubit,
    );
    var disposed = false;
    addTearDown(() async {
      if (disposed) return;
      await sessionCubit.close();
      await streamingCubit.close();
      bridge.dispose();
    });

    expect(sessionCubit.state.entries, isEmpty);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: MultiBlocProvider(
          providers: [
            BlocProvider<ChatSessionCubit>.value(value: sessionCubit),
            BlocProvider<StreamingStateCubit>.value(value: streamingCubit),
          ],
          child: Scaffold(
            body: SessionComposerActivityIndicator(
              status: ProcessStatus.running,
              now: () => now,
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('composer_activity_indicator')),
      findsNothing,
    );

    bridge.emit(
      const HistoryMessage(
        messages: [
          UserInputMessage(
            text: 'Continue the work',
            timestamp: '2026-08-23T12:00:00.000Z',
          ),
        ],
      ),
      sessionId: 'late-history',
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Working'), findsOneWidget);
    expect(find.text(' · 6:12'), findsOneWidget);
    expect(find.text('6m ago'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await sessionCubit.close();
    await streamingCubit.close();
    bridge.dispose();
    disposed = true;
  });
}
