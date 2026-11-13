import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../l10n/app_localizations.dart';
import '../html_preview_document.dart';

bool get supportsEmbeddedHtmlPreview =>
    !kIsWeb &&
    switch (defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.macOS => true,
      _ => false,
    };

@visibleForTesting
Set<Factory<OneSequenceGestureRecognizer>>
createHtmlPreviewGestureRecognizers() =>
    <Factory<OneSequenceGestureRecognizer>>{
      Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
    };

class HtmlFilePreview extends StatefulWidget {
  final String html;

  const HtmlFilePreview({super.key, required this.html});

  @override
  State<HtmlFilePreview> createState() => _HtmlFilePreviewState();
}

class _HtmlFilePreviewState extends State<HtmlFilePreview> {
  late final WebViewController _controller;
  int _loadGeneration = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    unawaited(_loadPreview());
  }

  @override
  void didUpdateWidget(covariant HtmlFilePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html == widget.html) return;

    _loading = true;
    _error = null;
    unawaited(_loadPreview());
  }

  Future<void> _loadPreview() async {
    final generation = ++_loadGeneration;
    final navigationGate = HtmlPreviewNavigationGate();

    try {
      await _controller.setJavaScriptMode(JavaScriptMode.disabled);
      if (generation != _loadGeneration) return;
      await _controller.setBackgroundColor(Colors.white);
      if (generation != _loadGeneration) return;
      await _controller.setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (generation != _loadGeneration) return;
            navigationGate.markPageStarted();
          },
          onPageFinished: (_) {
            if (!mounted || generation != _loadGeneration) return;
            setState(() {
              _loading = false;
            });
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame != true ||
                !mounted ||
                generation != _loadGeneration) {
              return;
            }
            setState(() {
              _loading = false;
              _error = error.description;
            });
          },
          onNavigationRequest: (request) {
            if (generation != _loadGeneration) {
              return NavigationDecision.prevent;
            }
            return navigationGate.allowNavigation(request.url)
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
        ),
      );
      if (generation != _loadGeneration) return;
      await _controller.loadHtmlString(
        buildSafeHtmlPreviewDocument(widget.html),
      );
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.web_asset_off_outlined, size: 40),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context).renderErrorFallback,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                error,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    return Semantics(
      label: AppLocalizations.of(context).filePreviewRenderedHtml,
      child: Stack(
        children: [
          WebViewWidget(
            key: const ValueKey('file_peek_html_preview'),
            controller: _controller,
            gestureRecognizers: createHtmlPreviewGestureRecognizers(),
          ),
          if (_loading)
            const Align(
              alignment: Alignment.topCenter,
              child: LinearProgressIndicator(
                key: ValueKey('file_peek_html_loading_indicator'),
                minHeight: 2,
              ),
            ),
        ],
      ),
    );
  }
}
