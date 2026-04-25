import 'dart:typed_data';

import 'package:ccpocket/features/debug/debug_screen.dart';
import 'package:ccpocket/features/settings/state/settings_cubit.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/services/in_app_review_service.dart';
import 'package:ccpocket/services/support_banner_service.dart';
import 'package:ccpocket/widgets/bubbles/image_preview.dart';
import 'package:ccpocket/widgets/workspace_pane_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('DebugScreen AppBar clears macOS window buttons', (tester) async {
    await tester.pumpWidget(await _wrapDebugScreen());

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(
      scaffold.appBar?.preferredSize.height,
      kToolbarHeight + kWorkspaceMacOSSinglePaneTopInset,
    );
  });

  testWidgets('FullScreenImageViewer AppBar clears macOS window buttons', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.macOS),
        home: FullScreenImageViewer(bytes: _transparentPng),
      ),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(
      scaffold.appBar?.preferredSize.height,
      kToolbarHeight + kWorkspaceMacOSSinglePaneTopInset,
    );
  });
}

Future<Widget> _wrapDebugScreen() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  return ChangeNotifierProvider<SupportBannerService>(
    create: (_) => SupportBannerService(
      prefs: prefs,
      reviewService: InAppReviewService(prefs: prefs),
    ),
    child: BlocProvider<SettingsCubit>(
      create: (_) => SettingsCubit(prefs),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(platform: TargetPlatform.macOS),
        home: const DebugScreen(),
      ),
    ),
  );
}

final _transparentPng = Uint8List.fromList([
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
  0x00,
  0x00,
  0x00,
  0x0d,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1f,
  0x15,
  0xc4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0a,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9c,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0d,
  0x0a,
  0x2d,
  0xb4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4e,
  0x44,
  0xae,
  0x42,
  0x60,
  0x82,
]);
