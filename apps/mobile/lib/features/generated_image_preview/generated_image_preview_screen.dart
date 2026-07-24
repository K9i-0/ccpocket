import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../widgets/workspace_pane_chrome.dart';
import 'generated_image_preview_item.dart';
import 'widgets/generated_image_details_panel.dart';
import 'widgets/generated_image_preview_page.dart';

class GeneratedImagePreviewScreen extends StatefulWidget {
  final List<GeneratedImagePreviewItem> items;
  final int initialIndex;

  const GeneratedImagePreviewScreen({
    super.key,
    required this.items,
    this.initialIndex = 0,
  }) : assert(items.length > 0);

  @override
  State<GeneratedImagePreviewScreen> createState() =>
      _GeneratedImagePreviewScreenState();
}

class _GeneratedImagePreviewScreenState
    extends State<GeneratedImagePreviewScreen> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _chromeVisible = true;
  bool _detailsExpanded = false;

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
