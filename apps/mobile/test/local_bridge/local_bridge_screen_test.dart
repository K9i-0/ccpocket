import 'package:ccpocket/features/local_bridge/data/local_bridge_launcher.dart';
import 'package:ccpocket/features/local_bridge/local_bridge_screen.dart';
import 'package:ccpocket/features/local_bridge/state/local_bridge_cubit.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/services/connect_deep_link_scope.dart';
import 'package:ccpocket/services/connection_url_parser.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'local_bridge_fakes.dart';

final connectLinks = ValueNotifier<ConnectionParams?>(null);

Future<void> pumpScreen(
  WidgetTester tester,
  FakeLocalBridge bridge, {
  FakeLauncher? launcher,
}) async {
  connectLinks.value = null;
  tester.view.physicalSize = const Size(900, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) =>
          ConnectDeepLinkScope(notifier: connectLinks, child: child!),
      home: LocalBridgeScreen(
        createCubit: () => LocalBridgeCubit(
          clientFactory: bridge.client,
          launcher: launcher ?? FakeLauncher(bridge, available: false),
          startTimeout: const Duration(seconds: 1),
          restartPollInterval: const Duration(milliseconds: 10),
          restartTimeout: const Duration(seconds: 1),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder key(String value) => find.byKey(ValueKey(value));

void main() {
  testWidgets('shows status, pairing, tools and settings', (tester) async {
    await pumpScreen(tester, FakeLocalBridge());

    expect(find.text('Running'), findsOneWidget);
    expect(find.text('v1.120.0 · port 8765'), findsOneWidget);
    expect(find.text('2 sessions · 1 connected devices'), findsOneWidget);

    // Pairing: the QR code carries the API key, so it starts hidden.
    expect(find.text('ws://100.64.0.1:8765'), findsOneWidget);
    expect(key('local_bridge_qr_code'), findsNothing);
    await tester.tap(key('local_bridge_toggle_qr_button'));
    await tester.pump();
    expect(key('local_bridge_qr_code'), findsOneWidget);
    await tester.tap(key('local_bridge_address_chip:LAN'));
    await tester.pump();
    expect(find.text('ws://192.168.1.5:8765'), findsOneWidget);

    // Tools: a ready one, one needing sign-in, one missing without a command.
    expect(
      find.text('Node.js, Git and at least one agent are needed'),
      findsOneWidget,
    );
    expect(find.text('Required · v24.1.0'), findsOneWidget);
    expect(find.text('Agent · Needs setup'), findsOneWidget);
    expect(find.text('codex login'), findsOneWidget);
    expect(find.text('Agent · Not installed'), findsOneWidget);
    expect(key('local_bridge_tool_docs_button:antigravity'), findsOneWidget);

    // A setting pinned by an environment variable is locked.
    expect(
      find.text('Set by the environment variable BRIDGE_PORT'),
      findsOneWidget,
    );
  });

  testWidgets('saves an edited setting and restarts to apply it', (
    tester,
  ) async {
    final bridge = FakeLocalBridge();
    await pumpScreen(tester, bridge);
    expect(key('local_bridge_unsaved_bar'), findsNothing);

    await tester.tap(key('local_bridge_setting_toggle:allowClaudeOAuth'));
    await tester.pump();
    expect(key('local_bridge_unsaved_bar'), findsOneWidget);
    expect(key('local_bridge_setting_edited:allowClaudeOAuth'), findsOneWidget);

    await tester.tap(key('local_bridge_save_button'));
    await tester.pumpAndSettle();
    expect(bridge.fileSettings, {'allowClaudeOAuth': true});
    expect(key('local_bridge_unsaved_bar'), findsNothing);
    expect(key('local_bridge_restart_required_banner'), findsOneWidget);

    await tester.tap(key('local_bridge_restart_to_apply_button'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        '2 running sessions will be interrupted.\n'
        'Connected devices reconnect automatically.',
      ),
      findsOneWidget,
    );
    await tester.tap(key('local_bridge_restart_confirm_button'));
    await tester.pumpAndSettle();
    expect(bridge.pid, 101);
    expect(key('local_bridge_restart_required_banner'), findsNothing);
  });

  testWidgets('edits a text setting and a folder list', (tester) async {
    final bridge = FakeLocalBridge();
    await pumpScreen(tester, bridge);

    await tester.tap(key('local_bridge_setting_tile:host'));
    await tester.pumpAndSettle();
    await tester.enterText(key('local_bridge_setting_field'), '127.0.0.1');
    await tester.tap(key('local_bridge_setting_apply_button'));
    await tester.pumpAndSettle();

    await tester.tap(key('local_bridge_setting_tile:allowedDirs'));
    await tester.pumpAndSettle();
    expect(key('local_bridge_folder_row:/home/u'), findsOneWidget);
    await tester.enterText(key('local_bridge_folder_field'), '/work');
    await tester.tap(key('local_bridge_folder_add_button'));
    await tester.pump();
    await tester.tap(key('local_bridge_folder_remove:/home/u'));
    await tester.pump();
    await tester.tap(key('local_bridge_setting_apply_button'));
    await tester.pumpAndSettle();

    await tester.tap(key('local_bridge_save_button'));
    await tester.pumpAndSettle();
    expect(bridge.fileSettings, {
      'host': '127.0.0.1',
      'allowedDirs': ['/work'],
    });
  });

  testWidgets('connects this app over loopback with the pairing token', (
    tester,
  ) async {
    await pumpScreen(tester, FakeLocalBridge());
    await tester.tap(key('local_bridge_connect_here_button'));
    expect(connectLinks.value?.serverUrl, 'ws://127.0.0.1:8765');
    expect(connectLinks.value?.token, 'fixture-api-key');
  });

  testWidgets('explains a manually started Bridge and hides restart', (
    tester,
  ) async {
    await pumpScreen(tester, FakeLocalBridge()..supervised = false);
    expect(key('local_bridge_restart_button'), findsNothing);
    expect(key('local_bridge_not_supervised_note'), findsOneWidget);
  });

  testWidgets('shows how to start the Bridge when none is running', (
    tester,
  ) async {
    await pumpScreen(tester, FakeLocalBridge()..running = false);
    expect(find.text('The Bridge is not running'), findsOneWidget);
    expect(find.text('npx --yes @ccpocket/bridge@1'), findsOneWidget);
    expect(key('local_bridge_retry_button'), findsOneWidget);
  });

  testWidgets('starts the Bridge with one button and can stop it', (
    tester,
  ) async {
    final bridge = FakeLocalBridge()..running = false;
    await pumpScreen(tester, bridge, launcher: FakeLauncher(bridge));
    expect(
      find.text('Press the button to start the Bridge on this Mac.'),
      findsOneWidget,
    );
    await tester.tap(key('local_bridge_start_button'));
    await tester.pumpAndSettle();
    expect(find.text('Running'), findsOneWidget);
    expect(key('local_bridge_managed_note'), findsOneWidget);

    await tester.tap(key('local_bridge_stop_button'));
    await tester.pumpAndSettle();
    await tester.tap(key('local_bridge_stop_confirm_button'));
    await tester.pumpAndSettle();
    expect(bridge.running, isFalse);
    expect(key('local_bridge_start_button'), findsOneWidget);
  });

  testWidgets('shows how to install Node when the launcher misses it', (
    tester,
  ) async {
    final bridge = FakeLocalBridge()..running = false;
    final launcher = FakeLauncher(bridge)
      ..problemOnStart = LauncherStatus(
        state: 'node_missing',
        updatedAt: DateTime(2026),
      );
    await pumpScreen(tester, bridge, launcher: launcher);
    await tester.tap(key('local_bridge_start_button'));
    await tester.pumpAndSettle();
    expect(key('local_bridge_start_problem'), findsOneWidget);
    expect(find.text('brew install node'), findsOneWidget);
    expect(key('local_bridge_start_button'), findsNothing);

    // The waiting agent can still be turned off from here.
    await tester.tap(key('local_bridge_unregister_button'));
    await tester.pumpAndSettle();
    expect(launcher.registration, LauncherRegistration.notRegistered);
    expect(key('local_bridge_unregister_button'), findsNothing);
  });

  testWidgets('asks for an update when the Bridge is too old', (tester) async {
    await pumpScreen(tester, FakeLocalBridge()..adminSupported = false);
    expect(find.text('The Bridge needs an update'), findsOneWidget);
  });
}
