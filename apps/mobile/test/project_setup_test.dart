import 'dart:async';
import 'dart:convert';

import 'package:ccpocket/features/project_setup/state/project_setup_cubit.dart';
import 'package:ccpocket/features/project_setup/widgets/new_project_sheet.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/new_session_sheet.dart';
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
  testWidgets('resume settings cannot create a different project', (
    tester,
  ) async {
    final bridge = SetupBridge();
    addTearDown(bridge.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: [AppColors.dark()]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              child: const Text('Open'),
              onPressed: () => showNewSessionSheet(
                context: context,
                bridge: bridge,
                recentProjects: [],
                lockProvider: true,
                initialParams: NewSessionParams(
                  projectPath: '/workspace/existing',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const ValueKey('create_new_project_button')),
          )
          .onPressed,
      isNull,
    );
  });
  for (final switchToExisting in [false, true]) {
    testWidgets('creation returns to session sheet; switch=$switchToExisting', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final bridge = SetupBridge();
      addTearDown(bridge.dispose);
      NewSessionParams? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: [AppColors.dark()]),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ja'),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                child: const Text('Open'),
                onPressed: () async => result = await showNewSessionSheet(
                  context: context,
                  bridge: bridge,
                  recentProjects: [(path: '/workspace/old', name: 'old')],
                  initialParams: NewSessionParams(
                    projectPath: '/workspace/old',
                    provider: Provider.claude,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('マルチ'), findsOneWidget);
      expect(find.text('管理'), findsNothing);
      expect(find.byKey(const ValueKey('dialog_project_path')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('create_new_project_button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('new_project_name_field')),
        'fresh',
      );
      await tester.enterText(
        find.byKey(const ValueKey('new_project_parent_field')),
        '/workspace',
      );
      await tester.enterText(
        find.byKey(const ValueKey('new_project_description_field')),
        'Build a Flutter app',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('new_project_create_button')),
      );
      await tester.tap(find.byKey(const ValueKey('new_project_create_button')));
      await tester.pump();
      final request = bridge.sent.singleWhere(
        (m) => m['type'] == 'bootstrap_project',
      );
      await tester.runAsync(() async {
        bridge.events.add(
          ProjectSetupResultMessage(
            requestId: request['requestId'] as String,
            projectPath: '/workspace/fresh',
            copiedFiles: ['CLAUDE.md'],
          ),
        );
        await Future<void>.delayed(Duration.zero);
      });
      // Let async stream cancellation and SharedPreferences finish before
      // settling the route animation in the fake frame clock.
      for (
        var attempt = 0;
        attempt < 10 && find.byType(NewProjectSheet).evaluate().isNotEmpty;
        attempt++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pumpAndSettle();
      }
      expect(result, isNull);
      expect(bridge.sent.where((m) => m['type'] == 'start'), isEmpty);
      expect(
        find.byKey(const ValueKey('new_project_name_field')),
        findsNothing,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('selected_project_path')))
            .data,
        '/workspace/fresh',
      );
      if (switchToExisting) {
        await tester.tap(
          find.byKey(const ValueKey('recent_project_/workspace/old_tile')),
        );
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(
        find.byKey(const ValueKey('dialog_start_button')),
      );
      await tester.tap(find.byKey(const ValueKey('dialog_start_button')));
      await tester.pumpAndSettle();
      expect(result?.provider, Provider.claude);
      expect(
        result?.projectPath,
        switchToExisting ? '/workspace/old' : '/workspace/fresh',
      );
      expect(result?.isNewProject, !switchToExisting);
      expect(result?.projectId, isNull);
      expect(result?.additionalWritableRoots, isEmpty);
      if (switchToExisting) {
        expect(result?.initialPrompt, isNull);
      } else {
        expect(result?.initialPrompt, contains('Build a Flutter app'));
        expect(
          result!.initialPrompt!.length,
          greaterThan('Build a Flutter app'.length),
        );
        final restored = sessionStartDefaultsFromJson(
          sessionStartDefaultsToJson(result!),
        );
        expect(restored?.initialPrompt, isNull);
        expect(restored?.isNewProject, isFalse);
      }
      expect(tester.takeException(), isNull);
    });
  }
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
          theme: ThemeData.dark().copyWith(extensions: [AppColors.dark()]),
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
