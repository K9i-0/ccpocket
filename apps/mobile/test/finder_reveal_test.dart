import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ccpocket/features/file_peek/state/finder_reveal_cubit.dart';
import 'package:ccpocket/features/file_peek/widgets/finder_reveal_button.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Bridge extends BridgeService {
  final responses = StreamController<ServerMessage>.broadcast();
  final sent = Completer<Map<String, dynamic>>();
  bool connected = true;
  void Function(Map<String, dynamic>)? onSend;

  @override
  Stream<ServerMessage> get messages => responses.stream;
  @override
  bool get isConnected => connected;
  @override
  void send(ClientMessage message) {
    final json = jsonDecode(message.toJson()) as Map<String, dynamic>;
    if (!sent.isCompleted) sent.complete(json);
    onSend?.call(json);
  }

  @override
  void dispose() {
    responses.close();
    super.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test(
    'creates a local proof, correlates responses and removes the proof',
    () async {
      final bridge = _Bridge();
      final cubit = FinderRevealCubit(bridge);
      addTearDown(bridge.dispose);
      addTearDown(cubit.close);
      final operation = cubit.reveal('/project', 'video.mp4');
      final request = await bridge.sent.future;
      final file = File(request['proofPath'] as String);
      expect(await file.readAsString(), request['proofToken']);
      bridge.responses.add(
        const FileRevealResultMessage(
          requestId: 'another',
          errorCode: 'reveal_failed',
        ),
      );
      bridge.responses.add(
        FileRevealResultMessage(requestId: request['requestId'] as String),
      );
      await operation;
      expect(cubit.state.busy, isFalse);
      expect(cubit.state.errorCode, isNull);
      expect(await file.parent.exists(), isFalse);
    },
  );

  test('handles old Bridge and remote-host responses', () async {
    for (final error in ['bridge_update_required', 'not_local_mac']) {
      final bridge = _Bridge();
      final cubit = FinderRevealCubit(bridge);
      bridge.onSend = (request) => bridge.responses.add(
        error == 'bridge_update_required'
            ? const ErrorMessage(
                message: 'reveal_file',
                errorCode: 'unsupported_message',
              )
            : FileRevealResultMessage(
                requestId: request['requestId'] as String,
                errorCode: error,
              ),
      );
      await cubit.reveal('/project', 'video.mp4');
      expect(cubit.state.errorCode, error);
      final request = await bridge.sent.future;
      expect(
        await File(request['proofPath'] as String).parent.exists(),
        isFalse,
      );
      await cubit.close();
      bridge.dispose();
    }
  });

  test('cleans up on timeout and when its preview closes', () async {
    for (final close in [false, true]) {
      final bridge = _Bridge();
      final cubit = FinderRevealCubit(
        bridge,
        timeout: const Duration(milliseconds: 20),
      );
      final operation = cubit.reveal('/project', 'video.mp4');
      final request = await bridge.sent.future;
      if (close) await cubit.close();
      await operation;
      expect(
        await File(request['proofPath'] as String).parent.exists(),
        isFalse,
      );
      if (!close) {
        expect(cubit.state.errorCode, 'reveal_failed');
        await cubit.close();
      }
      bridge.dispose();
    }
  });

  test('does not send a Finder operation while disconnected', () async {
    final bridge = _Bridge()..connected = false;
    final cubit = FinderRevealCubit(bridge);
    await cubit.reveal('/project', 'video.mp4');
    expect(bridge.sent.isCompleted, isFalse);
    expect(cubit.state.errorCode, 'reveal_failed');
    await cubit.close();
    bridge.dispose();
  });

  testWidgets('shows Finder tooltip and a connection failure in the preview', (
    tester,
  ) async {
    final bridge = _Bridge()..connected = false;
    addTearDown(bridge.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: FinderRevealButton(
            bridge: bridge,
            projectPath: '/project',
            filePath: 'movie.mp4',
          ),
        ),
      ),
    );
    expect(find.byTooltip('Show in Finder'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('file_peek_reveal_finder_button')),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Could not show the file in Finder. Check the file and Bridge connection.',
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
