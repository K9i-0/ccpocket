import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:extended_image/extended_image.dart';

import 'package:ccpocket/features/gallery/widgets/gallery_image_viewer.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/theme/app_theme.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    theme: AppTheme.darkTheme,
    home: child,
  );
}

void main() {
  testWidgets('uses the gesture-aware gallery for pinch, pan, and paging', (
    tester,
  ) async {
    const images = [
      GalleryImage(
        id: 'img-1',
        url: '/image-1.png',
        mimeType: 'image/png',
        projectPath: '/project',
        projectName: 'project',
        addedAt: '2026-08-23T00:00:00Z',
        sizeBytes: 1,
      ),
      GalleryImage(
        id: 'img-2',
        url: '/image-2.png',
        mimeType: 'image/png',
        projectPath: '/project',
        projectName: 'project',
        addedAt: '2026-08-23T00:00:00Z',
        sizeBytes: 1,
      ),
    ];

    await tester.pumpWidget(
      _wrap(
        const GalleryImageViewer(
          images: images,
          initialIndex: 0,
          httpBaseUrl: 'http://localhost',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(ExtendedImageGesturePageView), findsOneWidget);

    final imageFinder = find.byType(ExtendedImage).first;
    final image = tester.widget<ExtendedImage>(imageFinder);
    final imageState = tester.state(imageFinder) as ExtendedImageState;
    final gestureConfig = image.initGestureConfigHandler!(imageState);

    expect(image.mode, ExtendedImageMode.gesture);
    expect(image.onDoubleTap, isNotNull);
    expect(gestureConfig.inPageView, isTrue);
    expect(gestureConfig.minScale, 1);
    expect(gestureConfig.maxScale, 5);
  });

  testWidgets('an unzoomed horizontal swipe still changes images', (
    tester,
  ) async {
    const images = [
      GalleryImage(
        id: 'img-1',
        url: '/image-1.png',
        mimeType: 'image/png',
        projectPath: '/project',
        projectName: 'project',
        addedAt: '2026-08-23T00:00:00Z',
        sizeBytes: 1,
      ),
      GalleryImage(
        id: 'img-2',
        url: '/image-2.png',
        mimeType: 'image/png',
        projectPath: '/project',
        projectName: 'project',
        addedAt: '2026-08-23T00:00:00Z',
        sizeBytes: 1,
      ),
    ];

    await tester.pumpWidget(
      _wrap(
        const GalleryImageViewer(
          images: images,
          initialIndex: 0,
          httpBaseUrl: 'http://localhost',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('1 / 2'), findsOneWidget);
    await tester.drag(
      find.byType(ExtendedImageGesturePageView),
      const Offset(-500, 0),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('2 / 2'), findsOneWidget);
  });
}
