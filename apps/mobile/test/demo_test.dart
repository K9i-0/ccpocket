import 'package:ccpocket/features/demo/demo_screen.dart';
import 'package:ccpocket/features/demo/state/demo_cubit.dart';
import 'package:ccpocket/features/demo/state/demo_state.dart';
import 'package:ccpocket/features/session_list/widgets/connect_form.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'demo transitions require a request and reset without retaining input',
    () {
      final cubit = DemoCubit();
      addTearDown(cubit.close);
      cubit.approve();
      cubit.send('  ');
      expect(cubit.state.phase, DemoPhase.ready);
      cubit.send(' hello ');
      cubit.send('duplicate');
      expect(cubit.state.prompt, 'hello');
      cubit.reject();
      cubit.approve();
      expect(cubit.state.phase, DemoPhase.rejected);
      cubit.restart();
      expect(cubit.state.phase, DemoPhase.ready);
      expect(cubit.state.prompt, isEmpty);
      cubit.send('try again');
      cubit.approve();
      expect(cubit.state.phase, DemoPhase.completed);
    },
  );

  Widget app({String language = 'en'}) => MaterialApp(
    theme: AppTheme.darkTheme,
    locale: Locale(language),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: ConnectForm(
        discoveredServers: const [],
        onScanQrCode: () {},
        onConnectToDiscovered: (_) {},
      ),
    ),
  );

  Future<void> tap(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'public entry works without Bridge, approves diff, exits and resets',
    (tester) async {
      await tester.pumpWidget(app());
      await tap(tester, 'demo_try_button');
      expect(find.byType(DemoScreen), findsOneWidget);
      await tap(tester, 'demo_suggestion_button');
      await tap(tester, 'demo_approve_button');
      expect(find.byKey(const ValueKey('demo_diff_button')), findsOneWidget);
      expect(find.textContaining('Hello, Pocket!'), findsWidgets);
      await tap(tester, 'demo_connect_button');
      expect(find.byType(DemoScreen), findsNothing);
      await tap(tester, 'demo_try_button');
      expect(find.byKey(const ValueKey('demo_message_input')), findsOneWidget);
      expect(find.byKey(const ValueKey('demo_diff_button')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('custom input remains local; rejecting does not show a diff', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tap(tester, 'demo_try_button');
    await tester.enterText(
      find.byKey(const ValueKey('demo_message_input')),
      'My sample request',
    );
    await tap(tester, 'demo_send_button');
    expect(find.text('My sample request'), findsOneWidget);
    await tap(tester, 'demo_reject_button');
    expect(find.byKey(const ValueKey('demo_diff_button')), findsNothing);
    await tap(tester, 'demo_try_again_button');
    expect(find.text('My sample request'), findsNothing);
    await tap(tester, 'demo_exit_button');
    expect(find.byType(DemoScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('restart also clears an unsent draft', (tester) async {
    await tester.pumpWidget(app());
    await tap(tester, 'demo_try_button');
    await tester.enterText(
      find.byKey(const ValueKey('demo_message_input')),
      'Unsent',
    );
    await tap(tester, 'demo_restart_button');
    expect(find.text('Unsent'), findsNothing);
    await tap(tester, 'demo_send_button');
    expect(find.byKey(const ValueKey('demo_message_input')), findsOneWidget);
    expect(find.byKey(const ValueKey('demo_approve_button')), findsNothing);
  });

  for (final locale in ['en', 'ja', 'ko', 'zh']) {
    testWidgets('small screen and large text: $locale', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(app(language: locale));
      await tap(tester, 'demo_try_button');
      await tap(tester, 'demo_suggestion_button');
      await tap(tester, 'demo_approve_button');
      await tap(tester, 'demo_connect_button');
      expect(tester.takeException(), isNull);
    });
  }
}
