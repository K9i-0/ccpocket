import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../l10n/app_localizations.dart';

/// Displays every page with scrolling and pinch zoom inside the file browser.
class FilePeekPdfPreview extends StatelessWidget {
  const FilePeekPdfPreview({
    super.key,
    required this.pdfUrl,
    required this.onRetry,
  });

  final String? pdfUrl;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final url = pdfUrl;
    if (url == null) {
      return _PdfPreviewError(onRetry: onRetry, needsBridgeUpdate: true);
    }
    return PdfViewer.uri(
      Uri.parse(url),
      key: ValueKey('file_peek_pdf_$url'),
      params: PdfViewerParams(
        loadingBannerBuilder: (context, downloaded, total) =>
            const Center(child: CircularProgressIndicator.adaptive()),
        errorBannerBuilder: (context, error, stackTrace, document) =>
            _PdfPreviewError(onRetry: onRetry),
      ),
    );
  }
}

class _PdfPreviewError extends StatelessWidget {
  const _PdfPreviewError({
    required this.onRetry,
    this.needsBridgeUpdate = false,
  });

  final VoidCallback onRetry;
  final bool needsBridgeUpdate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf_outlined, size: 40),
            const SizedBox(height: 12),
            Text(
              needsBridgeUpdate
                  ? l10n.directoryBrowserBridgeUpdateRequired
                  : l10n.markdownFileUnavailable,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              key: const ValueKey('file_peek_pdf_retry_button'),
              onPressed: onRetry,
              child: Text(l10n.browserRetry),
            ),
          ],
        ),
      ),
    );
  }
}
