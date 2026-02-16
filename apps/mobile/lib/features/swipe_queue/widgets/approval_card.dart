import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_theme.dart';
import '../swipe_queue_data.dart';
import '../swipe_queue_screen.dart' show optionSwipeColors;

/// A card that displays an approval item in the swipe queue.
///
/// The card content changes based on [ApprovalType]:
/// - toolApproval: tool name + command/file + optional diff
/// - askQuestion: question + tappable option buttons
/// - planApproval: summary + expandable full plan text
/// - textInput: prompt + text field
class ApprovalCard extends StatefulWidget {
  final ApprovalItem item;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final ValueChanged<String>? onSelectOption;
  final ValueChanged<Set<String>>? onSelectMultiple;
  final ValueChanged<String>? onSubmitText;
  final double dragOffset;
  final double dragOffsetY;

  /// Which option tile to highlight during swipe (selectOption mode).
  final int? highlightedOptionIndex;

  /// Whether the current drag is in the skip zone (left half-circle or down).
  final bool isInSkipZone;

  /// Whether this card was previously deferred (skipped).
  final bool isDeferred;

  const ApprovalCard({
    super.key,
    required this.item,
    required this.onApprove,
    required this.onReject,
    this.onSelectOption,
    this.onSelectMultiple,
    this.onSubmitText,
    this.dragOffset = 0,
    this.dragOffsetY = 0,
    this.highlightedOptionIndex,
    this.isInSkipZone = false,
    this.isDeferred = false,
  });

  @override
  State<ApprovalCard> createState() => _ApprovalCardState();
}

class _ApprovalCardState extends State<ApprovalCard> {
  bool _planExpanded = false;
  final _textController = TextEditingController();
  final Set<String> _selectedOptions = {};

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  /// Determine the swipe mode for overlay color logic.
  _CardSwipeMode get _cardSwipeMode {
    switch (widget.item.type) {
      case ApprovalType.toolApproval:
      case ApprovalType.planApproval:
        return _CardSwipeMode.full;
      case ApprovalType.askQuestion:
        if (!widget.item.multiSelect &&
            widget.item.options != null &&
            widget.item.options!.isNotEmpty) {
          return _CardSwipeMode.selectOption;
        }
        return _CardSwipeMode.deferOnly;
      case ApprovalType.textInput:
        return _CardSwipeMode.deferOnly;
    }
  }

  /// Drag distance for radial mode.
  double get _dragDist => sqrt(
      widget.dragOffset * widget.dragOffset +
      widget.dragOffsetY * widget.dragOffsetY);

  /// Whether the card is being dragged primarily downward (non-selectOption).
  bool get _isDraggingDown =>
      widget.dragOffsetY > 30 &&
      widget.dragOffset.abs() < widget.dragOffsetY * 0.8;

  /// Get the color for a specific option index from the palette.
  Color _optionColor(int index) =>
      optionSwipeColors[index % optionSwipeColors.length];

  /// Get the color for the currently highlighted option (if any).
  Color? get _highlightedColor {
    final idx = widget.highlightedOptionIndex;
    if (idx == null) return null;
    return _optionColor(idx);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppColors>()!;
    final mode = _cardSwipeMode;

    // Background color hint based on drag direction and mode
    Color? bgOverlay;
    Color? borderHighlight;

    // Priority: skip zone overrides option selection
    if (mode == _CardSwipeMode.selectOption) {
      if (_dragDist > 15) {
        if (widget.isInSkipZone) {
          bgOverlay = Colors.amber.withValues(
            alpha: (_dragDist / 200).clamp(0, 0.12),
          );
          borderHighlight = Colors.amber.withValues(alpha: 0.4);
        } else {
          final color = _highlightedColor ?? Colors.blue;
          bgOverlay = color.withValues(
            alpha: (_dragDist / 200).clamp(0, 0.12),
          );
          borderHighlight = color.withValues(alpha: 0.4);
        }
      }
    } else if (_isDraggingDown) {
      bgOverlay = Colors.amber.withValues(
        alpha: (widget.dragOffsetY / 200).clamp(0, 0.12),
      );
      borderHighlight = Colors.amber.withValues(alpha: 0.4);
    } else if (mode == _CardSwipeMode.deferOnly) {
      if (widget.dragOffset < -30) {
        bgOverlay = Colors.amber.withValues(
          alpha: (-widget.dragOffset / 200).clamp(0, 0.12),
        );
        borderHighlight = Colors.amber.withValues(alpha: 0.4);
      }
    } else {
      if (widget.dragOffset > 30) {
        bgOverlay = Colors.green.withValues(
          alpha: (widget.dragOffset / 200).clamp(0, 0.15),
        );
        borderHighlight = Colors.green.withValues(alpha: 0.4);
      } else if (widget.dragOffset < -30) {
        bgOverlay = Colors.red.withValues(
          alpha: (-widget.dragOffset / 200).clamp(0, 0.15),
        );
        borderHighlight = Colors.red.withValues(alpha: 0.4);
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderHighlight ?? cs.outlineVariant,
          width: borderHighlight != null ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ColoredBox(
          color: bgOverlay ?? Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(cs, appColors),
                const SizedBox(height: 16),
                Divider(color: cs.outlineVariant, height: 1),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: SingleChildScrollView(
                    child: _buildContent(cs, appColors),
                  ),
                ),
                const SizedBox(height: 16),
                _buildFooter(cs, appColors),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs, AppColors appColors) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(widget.item.sessionIcon, color: cs.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.item.sessionName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.item.projectPath,
                style: TextStyle(fontSize: 11, color: appColors.subtleText),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (widget.isDeferred) ...[
          _buildDeferredBadge(cs),
          const SizedBox(width: 6),
        ],
        _buildTypeBadge(cs),
      ],
    );
  }

  /// "Skipped" badge shown when item was previously deferred.
  Widget _buildDeferredBadge(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, size: 14, color: Colors.amber.shade700),
          const SizedBox(width: 4),
          Text(
            'Skipped',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.amber.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeBadge(ColorScheme cs) {
    final (label, color, icon) = switch (widget.item.type) {
      ApprovalType.toolApproval => ('Tool', cs.primary, Icons.shield),
      ApprovalType.askQuestion => (
        'Question',
        cs.secondary,
        Icons.help_outline,
      ),
      ApprovalType.planApproval => ('Plan', cs.tertiary, Icons.assignment),
      ApprovalType.textInput => ('Input', cs.outline, Icons.edit_note),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ColorScheme cs, AppColors appColors) {
    return switch (widget.item.type) {
      ApprovalType.toolApproval => _buildToolContent(cs, appColors),
      ApprovalType.askQuestion => _buildQuestionContent(cs, appColors),
      ApprovalType.planApproval => _buildPlanContent(cs, appColors),
      ApprovalType.textInput => _buildTextInputContent(cs, appColors),
    };
  }

  // ── Tool Approval ──────────────────────────────────────────────────────

  Widget _buildToolContent(ColorScheme cs, AppColors appColors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tool name badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: appColors.toolBubble,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: appColors.toolBubbleBorder, width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.terminal, size: 14, color: appColors.toolIcon),
              const SizedBox(width: 6),
              Text(
                widget.item.toolName ?? 'Tool',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: appColors.toolIcon,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Command / file path
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: appColors.codeBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: appColors.codeBorder, width: 0.5),
          ),
          child: Text(
            widget.item.toolSummary ?? '',
            style: GoogleFonts.ibmPlexMono(
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        // Optional diff preview
        if (widget.item.diffPreview != null) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: appColors.codeBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: appColors.codeBorder, width: 0.5),
            ),
            child: _buildDiffText(widget.item.diffPreview!, appColors),
          ),
        ],
      ],
    );
  }

  Widget _buildDiffText(String diff, AppColors appColors) {
    final lines = diff.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        Color textColor;
        Color? bgColor;
        if (line.startsWith('+')) {
          textColor = appColors.diffAdditionText;
          bgColor = appColors.diffAdditionBackground.withValues(alpha: 0.5);
        } else if (line.startsWith('-')) {
          textColor = appColors.diffDeletionText;
          bgColor = appColors.diffDeletionBackground.withValues(alpha: 0.5);
        } else {
          textColor = appColors.subtleText;
          bgColor = null;
        }
        return Container(
          width: double.infinity,
          color: bgColor,
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Text(
            line,
            style: GoogleFonts.ibmPlexMono(fontSize: 11, color: textColor),
          ),
        );
      }).toList(),
    );
  }

  // ── Ask Question ───────────────────────────────────────────────────────

  Widget _buildQuestionContent(ColorScheme cs, AppColors appColors) {
    final options = widget.item.options;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.item.question ?? '',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        if (widget.item.multiSelect) ...[
          const SizedBox(height: 4),
          Text(
            'Select all that apply',
            style: TextStyle(fontSize: 11, color: appColors.subtleText),
          ),
        ],
        const SizedBox(height: 12),
        if (options != null)
          ...options.asMap().entries.map(
                (entry) => _buildOptionTile(
                  entry.value,
                  entry.key,
                  cs,
                  appColors,
                ),
              ),
        if (widget.item.multiSelect && _selectedOptions.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => widget.onSelectMultiple?.call(_selectedOptions),
              child: Text(
                'Submit (${_selectedOptions.length} selected)',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOptionTile(
    QuestionOption opt,
    int index,
    ColorScheme cs,
    AppColors appColors,
  ) {
    final isSelected = _selectedOptions.contains(opt.label);
    final isDragHighlighted =
        widget.highlightedOptionIndex != null &&
        widget.highlightedOptionIndex == index;
    final optColor = _optionColor(index);

    // Drag highlight takes priority over tap selection
    final Color tileBg;
    final Color tileBorder;
    final Color? labelColor;

    if (isDragHighlighted) {
      tileBg = optColor.withValues(alpha: 0.15);
      tileBorder = optColor.withValues(alpha: 0.6);
      labelColor = optColor;
    } else if (isSelected) {
      tileBg = cs.primaryContainer.withValues(alpha: 0.6);
      tileBorder = cs.primary.withValues(alpha: 0.5);
      labelColor = cs.primary;
    } else {
      tileBg = cs.surfaceContainerLow;
      tileBorder = cs.outlineVariant;
      labelColor = null;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: tileBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: tileBorder,
            width: isDragHighlighted || isSelected ? 1.5 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              if (widget.item.multiSelect) {
                setState(() {
                  if (isSelected) {
                    _selectedOptions.remove(opt.label);
                  } else {
                    _selectedOptions.add(opt.label);
                  }
                });
              } else {
                widget.onSelectOption?.call(opt.label);
              }
            },
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Color indicator dot for single-select
                  if (!widget.item.multiSelect) ...[
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: isDragHighlighted
                            ? optColor
                            : optColor.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  if (widget.item.multiSelect) ...[
                    Icon(
                      isSelected
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 20,
                      color: isSelected ? cs.primary : appColors.subtleText,
                    ),
                    const SizedBox(width: 10),
                  ],
                  if (isDragHighlighted && !widget.item.multiSelect) ...[
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: optColor,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          opt.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isDragHighlighted
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: labelColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          opt.description,
                          style: TextStyle(
                            fontSize: 11,
                            color: appColors.subtleText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!widget.item.multiSelect && !isDragHighlighted)
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: appColors.subtleText,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Plan Approval ──────────────────────────────────────────────────────

  Widget _buildPlanContent(ColorScheme cs, AppColors appColors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.item.planSummary ?? '',
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        if (widget.item.planFullText != null) ...[
          const SizedBox(height: 12),
          InkWell(
            onTap: () => setState(() => _planExpanded = !_planExpanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    _planExpanded ? Icons.unfold_less : Icons.unfold_more,
                    size: 18,
                    color: cs.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _planExpanded ? 'Collapse plan' : 'View full plan',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_planExpanded) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: appColors.codeBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: appColors.codeBorder, width: 0.5),
              ),
              child: Text(
                widget.item.planFullText!,
                style: const TextStyle(fontSize: 12, height: 1.6),
              ),
            ),
          ],
        ],
      ],
    );
  }

  // ── Text Input ─────────────────────────────────────────────────────────

  Widget _buildTextInputContent(ColorScheme cs, AppColors appColors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.item.inputPrompt ?? '',
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _textController,
          decoration: InputDecoration(
            hintText: widget.item.inputHint ?? 'Type here...',
            suffixIcon: IconButton(
              icon: Icon(Icons.send, color: cs.primary),
              onPressed: () {
                if (_textController.text.isNotEmpty) {
                  widget.onSubmitText?.call(_textController.text);
                }
              },
            ),
          ),
          onSubmitted: (text) {
            if (text.isNotEmpty) {
              widget.onSubmitText?.call(text);
            }
          },
        ),
      ],
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────────

  Widget _buildFooter(ColorScheme cs, AppColors appColors) {
    final mode = _cardSwipeMode;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Mode-specific hint (horizontal swipe)
        _buildHorizontalHint(mode, cs, appColors),
        const SizedBox(height: 6),
        // Universal skip hint (down swipe)
        _buildDownSkipHint(appColors),
      ],
    );
  }

  Widget _buildHorizontalHint(
    _CardSwipeMode mode,
    ColorScheme cs,
    AppColors appColors,
  ) {
    if (mode == _CardSwipeMode.selectOption) {
      return _buildSwipeZoneGuide(cs, appColors);
    }

    if (mode == _CardSwipeMode.deferOnly) {
      // Left-only skip hint
      return Row(
        children: [
          Icon(
            Icons.arrow_back,
            size: 14,
            color: Colors.amber.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 4),
          Text(
            'Skip',
            style: TextStyle(
              fontSize: 12,
              color: Colors.amber.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    // Full mode: approve / reject
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              Icons.arrow_back,
              size: 14,
              color: Colors.red.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 4),
            Text(
              'Reject',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Text(
              'Approve',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_forward,
              size: 14,
              color: Colors.green.withValues(alpha: 0.6),
            ),
          ],
        ),
      ],
    );
  }

  /// Radial zone guide — small half-circle diagram showing option sectors.
  Widget _buildSwipeZoneGuide(ColorScheme cs, AppColors appColors) {
    final options = widget.item.options;
    if (options == null || options.isEmpty) return const SizedBox.shrink();

    final highlightIdx = widget.highlightedOptionIndex;

    return Row(
      children: [
        // Left: Skip label
        Text(
          '← Skip',
          style: TextStyle(
            fontSize: 11,
            color: Colors.amber.withValues(
              alpha: widget.isInSkipZone ? 0.9 : 0.5,
            ),
            fontWeight:
                widget.isInSkipZone ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        // Center: radial diagram
        SizedBox(
          width: 44,
          height: 44,
          child: CustomPaint(
            painter: _RadialGuidePainter(
              optionCount: options.length,
              highlightedIndex: highlightIdx,
              isInSkipZone: widget.isInSkipZone,
              colors: optionSwipeColors,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Right: option labels stacked
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: options.asMap().entries.map((entry) {
              final idx = entry.key;
              final opt = entry.value;
              final color = _optionColor(idx);
              final isHighlighted = highlightIdx == idx;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: color.withValues(
                          alpha: isHighlighted ? 1.0 : 0.4,
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        opt.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isHighlighted
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: color.withValues(
                            alpha: isHighlighted ? 0.9 : 0.5,
                          ),
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  /// Universal down-swipe skip hint shown for all card types.
  Widget _buildDownSkipHint(AppColors appColors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.arrow_downward,
          size: 12,
          color: appColors.subtleText.withValues(alpha: 0.5),
        ),
        const SizedBox(width: 3),
        Text(
          'Skip',
          style: TextStyle(
            fontSize: 11,
            color: appColors.subtleText.withValues(alpha: 0.5),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

/// Internal enum mirroring SwipeMode for the card's own overlay logic.
enum _CardSwipeMode { full, selectOption, deferOnly }

/// Small radial guide painter for the footer hint.
class _RadialGuidePainter extends CustomPainter {
  final int optionCount;
  final int? highlightedIndex;
  final bool isInSkipZone;
  final List<Color> colors;

  _RadialGuidePainter({
    required this.optionCount,
    required this.highlightedIndex,
    required this.isInSkipZone,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;

    // Left half: skip (amber)
    final skipAlpha = isInSkipZone ? 0.3 : 0.1;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi / 2,
      pi,
      true,
      Paint()
        ..color = Colors.amber.withValues(alpha: skipAlpha)
        ..style = PaintingStyle.fill,
    );

    // Right half: option sectors
    final sectorAngle = pi / optionCount;
    for (var i = 0; i < optionCount; i++) {
      final color = colors[i % colors.length];
      final isHighlighted = highlightedIndex == i;
      final alpha = isHighlighted ? 0.4 : 0.15;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2 + (i * sectorAngle),
        sectorAngle,
        true,
        Paint()
          ..color = color.withValues(alpha: alpha)
          ..style = PaintingStyle.fill,
      );

      // Sector boundary
      if (i > 0) {
        final lineAngle = -pi / 2 + (i * sectorAngle);
        canvas.drawLine(
          center,
          Offset(
            center.dx + radius * cos(lineAngle),
            center.dy + radius * sin(lineAngle),
          ),
          Paint()
            ..color = color.withValues(alpha: 0.3)
            ..strokeWidth = 0.5
            ..style = PaintingStyle.stroke,
        );
      }
    }

    // Vertical boundary (skip | options)
    final bPaint = Paint()
      ..color = Colors.amber.withValues(alpha: 0.4)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      bPaint,
    );

    // Outer circle
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
  }

  @override
  bool shouldRepaint(_RadialGuidePainter oldDelegate) =>
      oldDelegate.highlightedIndex != highlightedIndex ||
      oldDelegate.isInSkipZone != isInSkipZone;
}
