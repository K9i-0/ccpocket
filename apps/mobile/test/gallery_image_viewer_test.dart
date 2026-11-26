import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/features/gallery/widgets/gallery_image_viewer.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/l10n/app_localizations_delegates.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/cached_network_image.dart';
import 'package:ccpocket/widgets/zoomable_image_viewer.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    theme: AppTheme.darkTheme,
    home: child,
  );
}

const _images = [
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

Future<void> _pumpAnimation(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
}

Future<void> _doubleTap(WidgetTester tester, Offset position) async {
  await tester.tapAt(position);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tapAt(position);
  await _pumpAnimation(tester);
}

void main() {
  testWidgets('uses PageView with ZoomableImageViewer and CachedNetworkImage', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const GalleryImageViewer(
          images: _images,
          initialIndex: 0,
          httpBaseUrl: 'http://localhost',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final pageView = tester.widget<PageView>(find.byType(PageView));
    expect(pageView.physics, isNull);

    final viewer = tester.widget<ZoomableImageViewer>(
      find.byType(ZoomableImageViewer).first,
    );
    expect(viewer.minScale, 1.0);
    expect(viewer.onZoomChanged, isNotNull);
    expect(find.byType(CachedNetworkImage), findsWidgets);
  });

  testWidgets('an unzoomed horizontal swipe still changes images', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const GalleryImageViewer(
          images: _images,
          initialIndex: 0,
          httpBaseUrl: 'http://localhost',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('1 / 2'), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await _pumpAnimation(tester);

    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets('locks PageView physics while zoomed and unlocks when unzoomed', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const GalleryImageViewer(
          images: _images,
          initialIndex: 0,
          httpBaseUrl: 'http://localhost',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final pageViewFinder = find.byType(PageView);
    expect(tester.widget<PageView>(pageViewFinder).physics, isNull);

    final center = tester.getCenter(pageViewFinder);
    await _doubleTap(tester, center);

    expect(
      tester.widget<PageView>(pageViewFinder).physics,
      isA<NeverScrollableScrollPhysics>(),
    );

    // Dragging horizontally while zoomed must not advance to page 2.
    await tester.drag(pageViewFinder, const Offset(-500, 0));
    await _pumpAnimation(tester);
    expect(find.text('1 / 2'), findsOneWidget);

    // Double-tapping again returns to 1x and restores paging.
    await _doubleTap(tester, center);
    expect(tester.widget<PageView>(pageViewFinder).physics, isNull);

    await tester.drag(pageViewFinder, const Offset(-500, 0));
    await _pumpAnimation(tester);
    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets('single tap toggles chrome visibility', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const GalleryImageViewer(
          images: _images,
          initialIndex: 0,
          httpBaseUrl: 'http://localhost',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('1 / 2'), findsOneWidget);
    await tester.tap(find.byType(ZoomableImageViewer).first);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('1 / 2'), findsNothing);

    await tester.tap(find.byType(ZoomableImageViewer).first);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('1 / 2'), findsOneWidget);
  });
}
