import 'package:ccpocket/features/media_feedback/media_feedback_scope.dart';
import 'package:ccpocket/features/media_feedback/state/media_feedback_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:ccpocket/features/generated_image_preview/generated_image_preview_item.dart';
import 'package:ccpocket/features/generated_image_preview/generated_image_preview_screen.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  group('GeneratedImagePreviewScreen', () {
    testWidgets(
      'keeps image instructions separate across pages with keyboard visible',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final cubit = MediaFeedbackCubit(await SharedPreferences.getInstance());
        addTearDown(cubit.close);
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpWidget(
          _wrapItems(_items, feedback: MediaFeedbackBinding(cubit, 'session')),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('media_feedback_input')),
          'Blue background',
        );
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(find.text('1 / 3'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(
          find.byKey(const ValueKey('generated_image_next_button')),
        );
        await tester.pumpAndSettle();
        expect(find.text('2 / 3'), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty,
        );
        await tester.enterText(find.byType(TextField), 'Warm lighting');
        await tester.tap(
          find.byKey(const ValueKey('generated_image_previous_button')),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Blue background',
        );
        expect(cubit.items('session').length, 2);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('shows the selected image prompt and page counter', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(initialIndex: 1));
      await tester.pump();

      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('Second generated prompt'), findsOneWidget);
      expect(find.text('First generated prompt'), findsNothing);
    });

    testWidgets('shares the currently selected image from the app bar', (
      tester,
    ) async {
      ShareParams? shareParams;
      await tester.pumpWidget(
        _wrap(
          initialIndex: 1,
          shareImage: (params) async {
            shareParams = params;
          },
        ),
      );
      await tester.pump();

      final shareButton = find.byKey(
        const ValueKey('generated_image_share_button'),
      );
      expect(shareButton, findsOneWidget);
      expect(find.byTooltip('Share'), findsOneWidget);

      await tester.tap(shareButton);
      await tester.pumpAndSettle();

      final params = shareParams;
      expect(params, isNotNull);
      expect(params!.fileNameOverrides, ['generated-image-2.png']);
      expect(params.sharePositionOrigin, isNotNull);
      expect(params.sharePositionOrigin!.isEmpty, isFalse);
      expect(params.files, hasLength(1));
      expect(params.files!.single.mimeType, 'image/png');
      expect(await params.files!.single.readAsBytes(), _transparentPng);
    });

    testWidgets('hides file sharing on unsupported Linux builds', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        await tester.pumpWidget(_wrap());
        await tester.pump();

        expect(
          find.byKey(const ValueKey('generated_image_share_button')),
          findsNothing,
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
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

Widget _wrap({
  int initialIndex = 0,
  Future<void> Function(ShareParams params)? shareImage,
}) {
  return _wrapItems(_items, initialIndex: initialIndex, shareImage: shareImage);
}

Widget _wrapItems(
  List<GeneratedImagePreviewItem> items, {
  int initialIndex = 0,
  Future<void> Function(ShareParams params)? shareImage,
  MediaFeedbackBinding? feedback,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: GeneratedImagePreviewScreen(
      items: items,
      initialIndex: initialIndex,
      shareImage: shareImage,
      feedback: feedback,
    ),
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
