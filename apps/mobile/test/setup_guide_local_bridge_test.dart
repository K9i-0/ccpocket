import 'package:ccpocket/features/setup_guide/setup_guide_screen.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<void> pumpGuide(WidgetTester tester, {required bool localBridge}) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SetupGuideScreen(localBridgeOverride: localBridge),
    ),
  );
  await tester.pumpAndSettle();
}

Future<int> countPages(WidgetTester tester) async {
  var pages = 1;
  while (find
      .byKey(const ValueKey('guide_next_button'))
      .evaluate()
      .isNotEmpty) {
    await tester.tap(find.byKey(const ValueKey('guide_next_button')));
    await tester.pumpAndSettle();
    pages += 1;
  }
  return pages;
}

void main() {
  testWidgets('on a Mac the guide starts the Bridge from the app', (
    tester,
  ) async {
    await pumpGuide(tester, localBridge: true);
    await tester.tap(find.byKey(const ValueKey('guide_next_button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('guide_open_local_bridge_button')),
      findsOneWidget,
    );
    expect(find.text('Press "Start the Bridge"'), findsOneWidget);
    // About, local Bridge, connection, Tailscale, ready: no terminal pages.
    expect(await countPages(tester), 4);
    expect(find.byKey(const ValueKey('guide_done_button')), findsOneWidget);
  });

  testWidgets('elsewhere the guide keeps the terminal setup', (tester) async {
    await pumpGuide(tester, localBridge: false);
    await tester.tap(find.byKey(const ValueKey('guide_next_button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('guide_open_local_bridge_button')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('guide_bridge_mac_app_note')),
      findsOneWidget,
    );
    expect(await countPages(tester), 5);
  });
}
