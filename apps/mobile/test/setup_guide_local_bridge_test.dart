import 'package:ccpocket/constants/app_constants.dart';
import 'package:ccpocket/features/setup_guide/setup_guide_screen.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/l10n/app_localizations_delegates.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<void> pumpGuide(
  WidgetTester tester, {
  bool? localBridge,
  SetupGuidePlatform? platform,
  ThemeData? theme,
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      theme: theme,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SetupGuideScreen(
        localBridgeOverride: localBridge,
        platformOverride: platform,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<int> countRemainingPages(WidgetTester tester) async {
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
  testWidgets('on macOS the guide runs the 3-step local Bridge flow', (
    tester,
  ) async {
    await pumpGuide(tester, localBridge: true);

    // Step 1: About (shows all 3 providers)
    expect(find.text('Codex'), findsOneWidget);
    expect(find.text('Claude'), findsOneWidget);
    expect(find.text('Antigravity'), findsOneWidget);

    // Step 2: Local Bridge management
    await tester.tap(find.byKey(const ValueKey('guide_next_button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('guide_open_local_bridge_button')),
      findsOneWidget,
    );
    expect(find.text('Press "Start the Bridge"'), findsOneWidget);

    // Step 3: Mobile companion & ready (3 steps total -> 2 remaining from step 2)
    expect(await countRemainingPages(tester), 2);
    expect(
      find.byKey(const ValueKey('guide_mobile_install_copy_button')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('guide_done_button')), findsOneWidget);
  });

  testWidgets(
    'on mobile the guide recommends macOS app with copyable links and CLI tab',
    (tester) async {
      String? copiedText;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copiedText = (call.arguments as Map)['text'] as String?;
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      await pumpGuide(tester, localBridge: false);

      // Step 1 -> Step 2: Host setup defaults to Mac (Recommended)
      await tester.tap(find.byKey(const ValueKey('guide_next_button')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('guide_open_local_bridge_button')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('guide_mac_recommended_card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('guide_mac_copy_link_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('guide_mac_share_link_button')),
        findsOneWidget,
      );

      // Copy macOS download link
      await tester.tap(
        find.byKey(const ValueKey('guide_mac_copy_link_button')),
      );
      await tester.pump();
      expect(copiedText, AppConstants.macOSReleasesUrl);

      // Copy Homebrew command
      await tester.tap(
        find.byKey(const ValueKey('guide_mac_copy_brew_button')),
      );
      await tester.pump();
      expect(copiedText, AppConstants.macOSHomebrewCommand);

      // Switch to Linux / Windows / CLI tab
      await tester.tap(find.byKey(const ValueKey('guide_host_tab_cli')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('guide_cli_setup_content')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('guide_cli_copy_npx_button')));
      await tester.pump();
      expect(copiedText, 'npx --yes @ccpocket/bridge@latest');

      // Expand optional auto-start section
      await tester.tap(
        find.byKey(const ValueKey('guide_cli_autostart_toggle')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('guide_cli_copy_setup_button')),
        findsOneWidget,
      );

      // Step 2 -> Step 3 (Connect + expandable Tailscale) -> Step 4 (Ready)
      expect(await countRemainingPages(tester), 3);
      expect(find.byKey(const ValueKey('guide_done_button')), findsOneWidget);
    },
  );

  testWidgets('on Linux/Windows desktop the guide shows 3-step CLI flow', (
    tester,
  ) async {
    await pumpGuide(
      tester,
      platform: SetupGuidePlatform.desktopOther,
      theme: AppTheme.darkTheme,
    );

    await tester.tap(find.byKey(const ValueKey('guide_next_button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('guide_desktop_copy_npx_button')),
      findsOneWidget,
    );

    expect(await countRemainingPages(tester), 2);
    expect(
      find.byKey(const ValueKey('guide_mobile_install_copy_button')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('guide_done_button')), findsOneWidget);
  });

  testWidgets('mobile guide renders cleanly in dark theme across all pages', (
    tester,
  ) async {
    await pumpGuide(
      tester,
      platform: SetupGuidePlatform.mobile,
      theme: AppTheme.darkTheme,
      locale: const Locale('ja'),
    );

    expect(await countRemainingPages(tester), 4);
    expect(find.byKey(const ValueKey('guide_done_button')), findsOneWidget);
  });
}
