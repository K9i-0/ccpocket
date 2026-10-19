import 'package:ccpocket/features/file_peek/widgets/file_peek_pdf_preview.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

void main() {
  testWidgets('shows Bridge update hint and retries when PDF URL is missing', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: FilePeekPdfPreview(pdfUrl: null, onRetry: () => retries++),
        ),
      ),
    );
    final context = tester.element(find.byType(FilePeekPdfPreview));
    expect(
      find.text(
        AppLocalizations.of(context).directoryBrowserBridgeUpdateRequired,
      ),
      findsOneWidget,
    );
    expect(find.byType(PdfViewer), findsNothing);
    await tester.tap(find.byKey(const ValueKey('file_peek_pdf_retry_button')));
    expect(retries, 1);
  });

  testWidgets('offers retry when PDF loading fails', (tester) async {
    var retries = 0;
    // Build the error UI without loading a native PDF renderer in widget tests.
    const url = 'http://localhost:8766/api/media/pdf';
    final preview = FilePeekPdfPreview(pdfUrl: url, onRetry: () => retries++);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              final viewer = preview.build(context) as PdfViewer;
              return viewer.params.errorBannerBuilder!(
                context,
                Exception('Invalid PDF'),
                null,
                viewer.documentRef,
              );
            },
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('file_peek_pdf_retry_button')));
    expect(retries, 1);
  });
}
