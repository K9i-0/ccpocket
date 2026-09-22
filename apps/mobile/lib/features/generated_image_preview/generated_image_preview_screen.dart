import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import '../../l10n/app_localizations.dart';
import '../../widgets/workspace_pane_chrome.dart';
import '../../widgets/media_export_actions.dart';
import 'generated_image_preview_item.dart';
import 'widgets/generated_image_details_panel.dart';
import 'widgets/generated_image_preview_page.dart';

class GeneratedImagePreviewScreen extends StatefulWidget {
  final List<GeneratedImagePreviewItem> items;
  final int initialIndex;
  @visibleForTesting
  final Future<void> Function(ShareParams params)? shareImage;

  const GeneratedImagePreviewScreen({
    super.key,
    required this.items,
    this.initialIndex = 0,
    this.shareImage,
  }) : assert(items.length > 0);

  @override
  State<GeneratedImagePreviewScreen> createState() =>
      _GeneratedImagePreviewScreenState();
}

class _GeneratedImagePreviewScreenState
    extends State<GeneratedImagePreviewScreen> {
  final _shareButtonAnchorKey = GlobalKey();
  late final PageController _pageController;
  late int _currentIndex;
  bool _chromeVisible = true;
  bool _detailsExpanded = false;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.items.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void didUpdateWidget(covariant GeneratedImagePreviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.items, widget.items)) return;

    final clampedIndex = _currentIndex.clamp(0, widget.items.length - 1);
    if (clampedIndex == _currentIndex) return;
    _currentIndex = clampedIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pageController.hasClients) {
        _pageController.jumpToPage(_currentIndex);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleChrome() {
    setState(() => _chromeVisible = !_chromeVisible);
    SystemChrome.setEnabledSystemUIMode(
      _chromeVisible ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
    );
  }

  void _toggleDetails() {
    setState(() => _detailsExpanded = !_detailsExpanded);
    HapticFeedback.selectionClick();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _detailsExpanded = false;
    });
    HapticFeedback.selectionClick();
  }

  void _goToPage(int index) {
    if (index < 0 || index >= widget.items.length) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _shareCurrentImage() async {
    if (_sharing) return;

    final item = widget.items[_currentIndex];
    setState(() => _sharing = true);
    try {
      final shareButtonBox =
          _shareButtonAnchorKey.currentContext?.findRenderObject()
              as RenderBox?;
      if (shareButtonBox == null || !shareButtonBox.hasSize) {
        throw StateError('Share button position is unavailable');
      }
      await _shareGeneratedImage(
        item,
        index: _currentIndex,
        sharePositionOrigin:
            shareButtonBox.localToGlobal(Offset.zero) & shareButtonBox.size,
        share: widget.shareImage,
      );
    } on _GeneratedImageDownloadException {
      if (mounted) {
        _showShareFailure(AppLocalizations.of(context).failedToDownloadImage);
      }
    } catch (_) {
      if (mounted) {
        _showShareFailure(AppLocalizations.of(context).failedToShareImage);
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _showShareFailure(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  KeyEventResult _handleKeyEvent(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _goToPage(_currentIndex - 1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _goToPage(_currentIndex + 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final chrome = resolveStandalonePaneChrome(context);
    final currentItem = widget.items[_currentIndex];
    return Focus(
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: _chromeVisible
            ? chrome.wrapAppBar(
                AppBar(
                  backgroundColor: Colors.black45,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  centerTitle: true,
                  title: Text(
                    '${_currentIndex + 1} / ${widget.items.length}',
                    key: const ValueKey('generated_image_page_indicator'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  actions: [
                    MediaExportActions(
                      url: currentItem.url,
                      bytes: currentItem.bytes,
                      mimeType: currentItem.mimeType,
                      showShare: false,
                    ),
                    if (_supportsGeneratedImageSharing)
                      SizedBox(
                        key: _shareButtonAnchorKey,
                        child: IconButton(
                          key: const ValueKey('generated_image_share_button'),
                          onPressed: _sharing ? null : _shareCurrentImage,
                          tooltip: AppLocalizations.of(context).share,
                          icon: _sharing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.share),
                        ),
                      ),
                  ],
                ),
              )
            : null,
        body: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              key: const ValueKey('generated_image_page_view'),
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              allowImplicitScrolling: true,
              itemCount: widget.items.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                final item = widget.items[index];
                return GeneratedImagePreviewPage(
                  key: ValueKey(item.id),
                  item: item,
                  onTap: _toggleChrome,
                  onSwipePrevious: index > 0
                      ? () => _goToPage(index - 1)
                      : null,
                  onSwipeNext: index < widget.items.length - 1
                      ? () => _goToPage(index + 1)
                      : null,
                );
              },
            ),
            if (_chromeVisible) ...[
              _PreviewNavigationButton(
                buttonKey: const ValueKey('generated_image_previous_button'),
                alignment: Alignment.centerLeft,
                icon: Icons.chevron_left,
                tooltip: AppLocalizations.of(context).previousImage,
                onPressed: _currentIndex > 0
                    ? () => _goToPage(_currentIndex - 1)
                    : null,
              ),
              _PreviewNavigationButton(
                buttonKey: const ValueKey('generated_image_next_button'),
                alignment: Alignment.centerRight,
                icon: Icons.chevron_right,
                tooltip: AppLocalizations.of(context).nextImage,
                onPressed: _currentIndex < widget.items.length - 1
                    ? () => _goToPage(_currentIndex + 1)
                    : null,
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: GeneratedImageDetailsPanel(
                  item: currentItem,
                  expanded: _detailsExpanded,
                  onToggleExpanded: _toggleDetails,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> _shareGeneratedImage(
  GeneratedImagePreviewItem item, {
  required int index,
  required Rect sharePositionOrigin,
  Future<void> Function(ShareParams params)? share,
}) async {
  final bytes = item.bytes ?? await _downloadGeneratedImage(item.url!);
  final extension = _extensionFromMime(item.mimeType);
  final params = ShareParams(
    files: [XFile.fromData(bytes, mimeType: item.mimeType)],
    fileNameOverrides: ['generated-image-${index + 1}$extension'],
    sharePositionOrigin: sharePositionOrigin,
  );
  if (share != null) {
    await share(params);
  } else {
    await SharePlus.instance.share(params);
  }
}

Future<Uint8List> _downloadGeneratedImage(String url) async {
  try {
    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw const _GeneratedImageDownloadException();
    }
    return response.bodyBytes;
  } on _GeneratedImageDownloadException {
    rethrow;
  } catch (_) {
    throw const _GeneratedImageDownloadException();
  }
}

bool get _supportsGeneratedImageSharing =>
    kIsWeb || defaultTargetPlatform != TargetPlatform.linux;

String _extensionFromMime(String mimeType) {
  return switch (mimeType) {
    'image/png' => '.png',
    'image/jpeg' || 'image/jpg' => '.jpg',
    'image/gif' => '.gif',
    'image/webp' => '.webp',
    _ => '.png',
  };
}

class _GeneratedImageDownloadException implements Exception {
  const _GeneratedImageDownloadException();
}

class _PreviewNavigationButton extends StatelessWidget {
  final Key buttonKey;
  final Alignment alignment;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _PreviewNavigationButton({
    required this.buttonKey,
    required this.alignment,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: SafeArea(
        minimum: const EdgeInsets.symmetric(horizontal: 10),
        child: AnimatedOpacity(
          opacity: onPressed == null ? 0 : 1,
          duration: const Duration(milliseconds: 150),
          child: IgnorePointer(
            ignoring: onPressed == null,
            child: IconButton(
              key: buttonKey,
              onPressed: onPressed,
              tooltip: tooltip,
              style: IconButton.styleFrom(
                backgroundColor: Colors.black45,
                foregroundColor: Colors.white,
                minimumSize: const Size(42, 42),
              ),
              icon: Icon(icon, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}
