import 'dart:async';
import 'dart:convert';

import 'package:ccpocket/features/project_setup/state/project_setup_cubit.dart';
import 'package:ccpocket/features/project_setup/widgets/new_project_sheet.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SetupBridge extends BridgeService {
  final events = StreamController<ServerMessage>.broadcast();
  final sent = <Map<String, dynamic>>[];
  bool connected = true;
  @override
  bool get isConnected => connected;
  @override
  Stream<ServerMessage> get messages => events.stream;
  @override
  void send(ClientMessage message) =>
      sent.add(jsonDecode(message.toJson()) as Map<String, dynamic>);
  @override
  void dispose() {
    events.close();
    super.dispose();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'ignores unrelated responses and surfaces old Bridge update guidance',
    () async {
      final bridge = SetupBridge();
      final cubit = ProjectSetupCubit(bridge);
      final future = cubit.request({
        'type': 'bootstrap_project',
      }, updateHint: 'Update Bridge');
      bridge.events.add(
        ProjectSetupResultMessage(requestId: 'other', projectPath: '/wrong'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.busy, isTrue);
      bridge.events.add(
        ErrorMessage(
          message: 'bootstrap_project',
          errorCode: 'unsupported_message',
        ),
      );
      expect(await future, isNull);
      expect(cubit.state.error, 'Update Bridge');
      await cubit.close();
      bridge.dispose();
    },
  );
  test('does not queue folder creation while disconnected', () async {
    final bridge = SetupBridge()..connected = false;
    final cubit = ProjectSetupCubit(bridge);
    expect(
      await cubit.request({
        'type': 'bootstrap_project',
      }, updateHint: 'Update Bridge'),
      isNull,
    );
    expect(bridge.sent, isEmpty);
    await cubit.close();
    bridge.dispose();
  });
  test('serializes setup requests and correlates successful replies', () async {
    final bridge = SetupBridge();
    final cubit = ProjectSetupCubit(bridge);
    final future = cubit.request({
      'type': 'bootstrap_project',
    }, updateHint: 'Update Bridge');
    expect(
      await cubit.request({
        'type': 'bootstrap_project',
      }, updateHint: 'Update Bridge'),
      isNull,
    );
    expect(bridge.sent, hasLength(1));
    bridge.events.add(
      ProjectSetupResultMessage(
        requestId: bridge.sent.single['requestId'] as String,
        projectPath: '/workspace/app',
      ),
    );
    expect((await future)?.projectPath, '/workspace/app');
    expect(cubit.state.busy, isFalse);
    await cubit.close();
    bridge.dispose();
  });
  testWidgets(
    'new project form fits a phone and offers optional settings inheritance',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bridge = SetupBridge();
      final cubit = ProjectSetupCubit(bridge);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BlocProvider.value(
              value: cubit,
              child: const NewProjectSheet(sources: ['/workspace/ccpocket']),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('新しいプロジェクトを作る'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('new_project_source_field')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.enterText(
        find.byKey(const ValueKey('new_project_name_field')),
        'new-app',
      );
      await tester.enterText(
        find.byKey(const ValueKey('new_project_parent_field')),
        '/workspace',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('new_project_create_button')),
      );
      await tester.tap(find.byKey(const ValueKey('new_project_create_button')));
      await tester.pump();
      expect(bridge.sent.single, containsPair('name', 'new-app'));
      expect(bridge.sent.single, containsPair('initializeGit', true));
      bridge.events.add(
        ProjectSetupResultMessage(
          requestId: bridge.sent.single['requestId'] as String,
          error: 'Already exists',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Already exists'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await cubit.close();
      bridge.dispose();
    },
  );
}
