import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../google_search_text_selection.dart';

/// Builds the collapsed preview text for [ThinkingBubble].
///
/// While streaming, shows the latest 2 non-empty lines so the user can follow
/// progress; once complete, shows up to the first 80 characters.
@visibleForTesting
String buildThinkingPreview(String thinking, {required bool isStreaming}) {
  if (isStreaming) {
    final nonEmptyLines = thinking
        .split('\n')
        .map((line) => line.trimRight())
        .where((line) => line.trim().isNotEmpty)
        .toList();
    if (nonEmptyLines.isEmpty) return thinking.trim();
    final start = nonEmptyLines.length > 2 ? nonEmptyLines.length - 2 : 0;
    return nonEmptyLines.sublist(start).join('\n');
  }
  return thinking.length > 80 ? '${thinking.substring(0, 80)}...' : thinking;
}

/// Displays Claude's thinking content with a collapsible UI.
///
/// When [isStreaming] is true, shows an animated indicator.
class ThinkingBubble extends StatefulWidget {
  final String thinking;
  final bool initiallyExpanded;

  /// Whether thinking is still streaming (shows animation).
  final bool isStreaming;

  const ThinkingBubble({
    super.key,
    required this.thinking,
    this.initiallyExpanded = false,
    this.isStreaming = false,
  });

  @override
  State<ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<ThinkingBubble>
    with SingleTickerProviderStateMixin {
  late bool _expanded;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _copiedResetTimer;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.isStreaming) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(ThinkingBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isStreaming && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isStreaming && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _copiedResetTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _copyThinking() {
    Clipboard.setData(ClipboardData(text: widget.thinking));
    HapticFeedback.lightImpact();
    _copiedResetTimer?.cancel();
    setState(() => _copied = true);
    _copiedResetTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final thinkingColor = cs.tertiary;
    final preview = buildThinkingPreview(
      widget.thinking,
      isStreaming: widget.isStreaming,
    );
    final lineCount = '\n'.allMatches(widget.thinking).length + 1;

    final l = Localizations.of<AppLocalizations>(context, AppLocalizations);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: thinkingColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: thinkingColor.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                key: const ValueKey('thinking_bubble_toggle'),
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(12),
                  bottom: _expanded ? Radius.zero : const Radius.circular(12),
                ),
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(12, 12, 12, _expanded ? 8 : 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Animated icon when streaming
                          if (widget.isStreaming)
                            AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                return Opacity(
                                  opacity: _pulseAnimation.value,
                                  child: Icon(
                                    Icons.psychology,
                                    size: 16,
                                    color: thinkingColor,
                                  ),
                                );
                              },
                            )
                          else
                            Icon(
                              Icons.psychology,
                              size: 16,
                              color: thinkingColor,
                            ),
                          const SizedBox(width: 6),
                          Text(
                            widget.isStreaming ? 'Thinking...' : 'Thinking',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: thinkingColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: thinkingColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$lineCount lines',
                              style: TextStyle(
                                fontSize: 10,
                                color: thinkingColor,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (_expanded)
                            IconButton(
                              key: const ValueKey(
                                'thinking_bubble_copy_button',
                              ),
                              icon: Icon(
                                _copied ? Icons.check : Icons.copy_outlined,
                                size: 14,
                              ),
                              color: _copied
                                  ? cs.primary
                                  : thinkingColor.withValues(alpha: 0.7),
                              tooltip: _copied
                                  ? (l?.copied ?? 'Copied')
                                  : (l?.copy ?? 'Copy'),
                              onPressed: _copyThinking,
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints.tightFor(
                                width: 26,
                                height: 24,
                              ),
                            ),
                          Icon(
                            _expanded ? Icons.expand_less : Icons.expand_more,
                            size: 18,
                            color: thinkingColor.withValues(alpha: 0.6),
                          ),
                        ],
                      ),
                      if (!_expanded) ...[
                        const SizedBox(height: 6),
                        Text(
                          preview,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.6),
                            fontFamily: 'monospace',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (_expanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: SingleChildScrollView(
                      child: GoogleSearchSelectionArea(
                        child: Text(
                          widget.thinking,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.8),
                            fontFamily: 'monospace',
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
