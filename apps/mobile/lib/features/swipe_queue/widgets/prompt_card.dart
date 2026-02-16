import 'dart:math';

import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Mock prompt chip suggestions.
const mockPromptChips = [
  'Write tests',
  'Create PR',
  'Refactor',
  'Check build',
  'Commit',
  'Fix errors',
  'Add docs',
];

/// A prompt input card displayed when the agent is waiting for the next prompt.
///
/// Visually differentiated from approval cards with a dashed border,
/// transparent tint background, and no shadow.
class PromptCard extends StatefulWidget {
  /// Called when the user submits a prompt (via chip tap or text input).
  final ValueChanged<String>? onSubmit;

  /// Drag offset X for swipe overlay hints.
  final double dragOffset;

  /// Drag offset Y for swipe overlay hints.
  final double dragOffsetY;

  /// Whether the text field currently has focus (disables swiping).
  final ValueChanged<bool>? onFocusChanged;

  const PromptCard({
    super.key,
    this.onSubmit,
    this.dragOffset = 0,
    this.dragOffsetY = 0,
    this.onFocusChanged,
  });

  @override
  State<PromptCard> createState() => _PromptCardState();
}

class _PromptCardState extends State<PromptCard> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  String? _selectedChip;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      widget.onFocusChanged?.call(_focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _hasContent =>
      _textController.text.isNotEmpty || _selectedChip != null;

  String get _promptText => _selectedChip ?? _textController.text;

  void _selectChip(String chip) {
    setState(() {
      if (_selectedChip == chip) {
        _selectedChip = null;
      } else {
        _selectedChip = chip;
        _textController.clear();
        _focusNode.unfocus();
      }
    });
  }

  void _submit() {
    if (_hasContent) {
      widget.onSubmit?.call(_promptText);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppColors>()!;

    // Swipe-based color overlay
    Color? bgOverlay;
    Color? borderHighlight;
    final dist = sqrt(
      widget.dragOffset * widget.dragOffset +
          widget.dragOffsetY * widget.dragOffsetY,
    );
    if (dist > 15) {
      if (widget.dragOffset > 30 && _hasContent) {
        // Right swipe with content = send
        bgOverlay = Colors.green.withValues(
          alpha: (widget.dragOffset / 200).clamp(0, 0.12),
        );
        borderHighlight = Colors.green.withValues(alpha: 0.4);
      } else if (widget.dragOffset < -30) {
        // Left swipe = dismiss
        bgOverlay = Colors.amber.withValues(
          alpha: (-widget.dragOffset / 200).clamp(0, 0.12),
        );
        borderHighlight = Colors.amber.withValues(alpha: 0.4);
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        // No shadow (intentionally flat / "unfinished" feel)
        color: cs.primary.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: borderHighlight ?? cs.primary.withValues(alpha: 0.2),
          width: borderHighlight != null ? 2 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: cs.primary.withValues(alpha: 0.15),
            borderRadius: 24,
            dashWidth: 8,
            dashGap: 5,
          ),
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
                  Divider(color: cs.outlineVariant.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  _buildChips(cs),
                  const SizedBox(height: 16),
                  _buildTextField(cs, appColors),
                  const SizedBox(height: 16),
                  _buildFooter(cs, appColors),
                ],
              ),
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
          child: Icon(Icons.add_circle_outline, color: cs.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            "What's next?",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Prompt',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: cs.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChips(ColorScheme cs) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: mockPromptChips.map((chip) {
        final isSelected = _selectedChip == chip;
        return GestureDetector(
          onTap: () => _selectChip(chip),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? cs.primary.withValues(alpha: 0.15)
                  : cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? cs.primary.withValues(alpha: 0.5)
                    : cs.outlineVariant,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Text(
              chip,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? cs.primary : cs.onSurface,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextField(ColorScheme cs, AppColors appColors) {
    return TextField(
      controller: _textController,
      focusNode: _focusNode,
      onChanged: (_) {
        // Clear chip selection when typing
        if (_selectedChip != null) {
          setState(() => _selectedChip = null);
        }
      },
      decoration: InputDecoration(
        hintText: 'Type your prompt...',
        suffixIcon: _hasContent
            ? IconButton(
                icon: Icon(Icons.send, color: cs.primary),
                onPressed: _submit,
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      onSubmitted: (_) => _submit(),
    );
  }

  Widget _buildFooter(ColorScheme cs, AppColors appColors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              Icons.arrow_back,
              size: 14,
              color: Colors.amber.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 4),
            Text(
              'Dismiss',
              style: TextStyle(
                fontSize: 12,
                color: Colors.amber.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Text(
              _hasContent ? 'Send' : 'Type or select',
              style: TextStyle(
                fontSize: 12,
                color: _hasContent
                    ? Colors.green.withValues(alpha: 0.6)
                    : appColors.subtleText.withValues(alpha: 0.5),
                fontWeight: FontWeight.w500,
              ),
            ),
            if (_hasContent) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_forward,
                size: 14,
                color: Colors.green.withValues(alpha: 0.6),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Draws a dashed border effect inside the card.
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double borderRadius;
  final double dashWidth;
  final double dashGap;

  _DashedBorderPainter({
    required this.color,
    required this.borderRadius,
    required this.dashWidth,
    required this.dashGap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromLTRBR(
      0,
      0,
      size.width,
      size.height,
      Radius.circular(borderRadius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0.0, metric.length);
        final segment = metric.extractPath(distance, end);
        canvas.drawPath(segment, paint);
        distance += dashWidth + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
