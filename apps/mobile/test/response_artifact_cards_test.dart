import 'package:ccpocket/features/response_artifacts/response_artifact_cards.dart';
import 'package:ccpocket/features/response_artifacts/workspace_output_links.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/features/gallery/widgets/gallery_image_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('gallery image card opens the saved gallery image', (
    tester,
  ) async {
    const image = GalleryImage(
      id: 'gallery-image-1',
      url: '/api/gallery/gallery-image-1',
      mimeType: 'image/png',
      projectPath: '/workspace/project',
      projectName: 'project',
      sessionId: 'session-1',
      addedAt: '2026-10-11T00:00:00.000Z',
      sizeBytes: 128,
    );
    await tester.pumpWidget(
      _wrap(
        const ResponseArtifactCards(
          images: [image],
          httpBaseUrl: 'https://bridge.test',
        ),
      ),
    );

    final card = find.byKey(
      const ValueKey('response_gallery_image_card_gallery-image-1'),
    );
    expect(card, findsOneWidget);
    await tester.tap(card);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(GalleryImageViewer), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'file card passes the complete resolved destination to File Peek',
    (tester) async {
      String? openedPath;
      await tester.pumpWidget(
        _wrap(
          ResponseArtifactCards(
            files: const [
              WorkspaceOutputLink(
                path: '/workspace/reports/Release review.pdf:18',
                label: 'Release review',
              ),
            ],
            onFileTap: (path) => openedPath = path,
          ),
        ),
      );
      await tester.tap(
        find.byKey(
          const ValueKey(
            'response_file_card_/workspace/reports/Release review.pdf:18',
          ),
        ),
      );
      expect(openedPath, '/workspace/reports/Release review.pdf:18');
      expect(find.text('Release review.pdf'), findsOneWidget);
    },
  );
}

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: Scaffold(body: child),
);
