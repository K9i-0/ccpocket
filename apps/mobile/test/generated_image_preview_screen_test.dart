import 'dart:typed_data';

import 'package:ccpocket/features/generated_image_preview/generated_image_preview_item.dart';
import 'package:ccpocket/features/generated_image_preview/generated_image_preview_screen.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GeneratedImagePreviewScreen', () {
    testWidgets('shows the selected image prompt and page counter', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(initialIndex: 1));
      await tester.pump();

      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('Second generated prompt'), findsOneWidget);
      expect(find.text('First generated prompt'), findsNothing);
    });

    testWidgets('moves to the next image with the navigation button', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey('generated_image_next_button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('Second generated prompt'), findsOneWidget);
    });

    testWidgets('swipes between images and updates metadata', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();

      await tester.drag(
        find.byKey(const ValueKey('generated_image_page_view')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('Second generated prompt'), findsOneWidget);
    });

    testWidgets('reveals technical details on demand', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pump();

      expect(find.text('/tmp/generated-1.png'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('generated_image_details_button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('/tmp/generated-1.png'), findsOneWidget);
      expect(find.text('completed'), findsOneWidget);
      expect(find.textContaining('Use case: style-transfer'), findsOneWidget);
    });

    testWidgets('does not truncate a prompt when no details are available', (
      tester,
    ) async {
      final prompt = List.filled(12, 'Long generated prompt').join(' ');
      await tester.pumpWidget(
        _wrapItems([
          GeneratedImagePreviewItem(
            id: 'prompt-only',
            bytes: _transparentPng,
            mimeType: 'image/png',
            prompt: prompt,
          ),
        ]),
      );
      await tester.pump();

      final promptWidget = tester.widget<SelectableText>(
        find.byKey(const ValueKey('generated_image_prompt_text')),
      );
      expect(promptWidget.maxLines, isNull);
    });

    testWidgets('clamps the current page when the image list shrinks', (
      tester,
    ) async {
      var items = _items;
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return GeneratedImagePreviewScreen(items: items);
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const ValueKey('generated_image_next_button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('generated_image_next_button')),
      );
      await tester.pumpAndSettle();
      expect(find.text('3 / 3'), findsOneWidget);

      rebuild(() => items = [_items.first]);
      await tester.pumpAndSettle();

      expect(find.text('1 / 1'), findsOneWidget);
      expect(find.text('First generated prompt'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

Widget _wrap({int initialIndex = 0}) {
  return _wrapItems(_items, initialIndex: initialIndex);
}

Widget _wrapItems(
  List<GeneratedImagePreviewItem> items, {
  int initialIndex = 0,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: GeneratedImagePreviewScreen(items: items, initialIndex: initialIndex),
  );
}

final _items = List.generate(
  3,
  (index) => GeneratedImagePreviewItem(
    id: 'generated-$index',
    bytes: _transparentPng,
    mimeType: 'image/png',
    prompt: switch (index) {
      0 => 'First generated prompt',
      1 => 'Second generated prompt',
      _ => 'Third generated prompt',
    },
    status: 'completed',
    savedPath: '/tmp/generated-${index + 1}.png',
    details: 'Use case: style-transfer',
  ),
  growable: false,
);

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
