import 'dart:convert';

import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/l10n/app_localizations_delegates.dart';
import 'package:ccpocket/widgets/bubbles/image_preview.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final bytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
  );

  testWidgets('tapping the image hides and restores the app bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: FullScreenImageViewer(bytes: bytes),
      ),
    );
    final appBar = find.byKey(const ValueKey('full_screen_image_app_bar'));
    final viewer = find.byKey(const ValueKey('full_screen_image_viewer'));
    expect(appBar, findsOneWidget);
    // The image is laid out behind the translucent app bar.
    expect(tester.getRect(viewer).top, 0);

    await tester.tap(viewer);
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(appBar, findsNothing);

    await tester.tap(viewer);
    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(appBar, findsOneWidget);
  });
}
