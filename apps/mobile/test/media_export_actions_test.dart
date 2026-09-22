import 'dart:async';
import 'dart:convert';

import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/features/git/widgets/diff_image_viewer.dart';
import 'package:ccpocket/utils/diff_parser.dart';
import 'package:ccpocket/widgets/bubbles/image_preview.dart';
import 'package:ccpocket/services/photo_library_service.dart';
import 'package:ccpocket/widgets/media_export_actions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final bytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
  );
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(PhotoLibraryService.channel, null);
  });

  Future<void> mount(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        appBar: AppBar(actions: [MediaExportActions(bytes: bytes)]),
      ),
    ),
  );

  testWidgets(
    'saves original bytes and prevents duplicate taps while pending',
    (tester) async {
      final done = Completer<void>();
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(PhotoLibraryService.channel, (call) async {
            calls.add(call);
            await done.future;
            return null;
          });
      await mount(tester);
      final button = find.byKey(const ValueKey('media_save_to_photos_button'));
      await tester.tap(button);
      await tester.pump();
      await tester.tap(button);
      expect(calls, hasLength(1));
      expect(calls.single.arguments['bytes'], bytes);
      expect(calls.single.arguments['isVideo'], false);
      done.complete();
      await tester.pumpAndSettle();
      expect(find.text('Saved to Photos'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('explains denied permission and allows retry', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(PhotoLibraryService.channel, (_) async {
          throw PlatformException(code: 'permission_denied');
        });
    await mount(tester);
    await tester.tap(find.byKey(const ValueKey('media_save_to_photos_button')));
    await tester.pumpAndSettle();
    expect(
      find.text('Allow adding photos in Settings to save images and videos.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('media_save_to_photos_button')),
          )
          .onPressed,
      isNotNull,
    );
    expect(find.text('Saved to Photos'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('keeps sharing but hides Photos on Android', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await mount(tester);
    expect(
      find.byKey(const ValueKey('media_save_to_photos_button')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('media_share_button')), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('full-screen image preview exposes share and save', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: FullScreenImageViewer(bytes: bytes),
      ),
    );
    expect(find.byKey(const ValueKey('media_share_button')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('media_save_to_photos_button')),
      findsOneWidget,
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('diff exports after by default and lets user select before', (
    tester,
  ) async {
    final before = Uint8List.fromList(bytes);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DiffImageViewer(
          file: const DiffFile(filePath: 'image.png', hunks: []),
          imageData: DiffImageData(oldBytes: before, newBytes: bytes),
        ),
      ),
    );
    expect(
      identical(
        tester
            .widget<MediaExportActions>(find.byType(MediaExportActions))
            .bytes,
        bytes,
      ),
      isTrue,
    );
    await tester.tap(
      find.byKey(const ValueKey('diff_image_export_side_dropdown')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Before').last);
    await tester.pumpAndSettle();
    expect(
      identical(
        tester
            .widget<MediaExportActions>(find.byType(MediaExportActions))
            .bytes,
        before,
      ),
      isTrue,
    );
    debugDefaultTargetPlatformOverride = null;
  });

  test('passes a video file path without loading video into memory', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(PhotoLibraryService.channel, (call) async {
          expect(call.arguments, {'path': '/tmp/movie.mp4', 'isVideo': true});
          return null;
        });
    await PhotoLibraryService.save(path: '/tmp/movie.mp4', isVideo: true);
  });
}
