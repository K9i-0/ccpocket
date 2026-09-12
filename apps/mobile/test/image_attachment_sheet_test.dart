import 'dart:async';

import 'package:ccpocket/features/chat_session/widgets/image_attachment_sheet.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget subject(Future<bool> clipboard, VoidCallback onSketch) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('ja'),
    home: Scaffold(
      body: ImageAttachmentSheet(
        clipboardHasImage: clipboard,
        onGallery: () {},
        onClipboard: () {},
        onSketch: onSketch,
      ),
    ),
  );

  testWidgets(
    'sketch is the third choice and works while clipboard is pending',
    (tester) async {
      final clipboard = Completer<bool>();
      var opened = false;
      await tester.pumpWidget(subject(clipboard.future, () => opened = true));
      final choices = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .toList();
      expect(choices.map((tile) => tile.key), [
        const ValueKey('attach_from_gallery'),
        const ValueKey('attach_from_clipboard'),
        const ValueKey('attach_sketch'),
      ]);
      expect(choices[1].enabled, isFalse);
      await tester.tap(find.text('スケッチを描く'));
      expect(opened, isTrue);
      clipboard.complete(true);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ListTile>(
              find.byKey(const ValueKey('attach_from_clipboard')),
            )
            .enabled,
        isTrue,
      );
    },
  );

  testWidgets('clipboard errors do not block drawing or gallery', (
    tester,
  ) async {
    final clipboard = Completer<bool>();
    var opened = false;
    await tester.pumpWidget(subject(clipboard.future, () => opened = true));
    clipboard.completeError(StateError('Clipboard unavailable'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester
          .widget<ListTile>(find.byKey(const ValueKey('attach_from_gallery')))
          .enabled,
      isTrue,
    );
    await tester.tap(find.byKey(const ValueKey('attach_sketch')));
    expect(opened, isTrue);
  });
}
