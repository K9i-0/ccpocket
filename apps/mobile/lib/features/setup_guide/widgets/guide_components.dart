import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/messages.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/provider_style.dart';

/// High-contrast surface and accent tokens for the setup guide in both light
/// and dark themes. Avoids `tertiaryContainer` / `secondaryContainer` which
/// are unset in [AppTheme.darkTheme].
class GuidePalette {
  const GuidePalette({
    required this.cardSurface,
    required this.cardBorder,
    required this.mutedSurface,
    required this.accentSurface,
    required this.accentBorder,
    required this.tealSurface,
    required this.tealBorder,
    required this.codeSurface,
    required this.codeBorder,
    required this.hintSurface,
    required this.hintBorder,
    required this.hintForeground,
    required this.successColor,
  });

  final Color cardSurface;
  final Color cardBorder;
  final Color mutedSurface;
  final Color accentSurface;
  final Color accentBorder;
  final Color tealSurface;
  final Color tealBorder;
  final Color codeSurface;
  final Color codeBorder;
  final Color hintSurface;
  final Color hintBorder;
  final Color hintForeground;
  final Color successColor;

  static GuidePalette of(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final appColors = theme.extension<AppColors>();
    final isDark = theme.brightness == Brightness.dark;

    return GuidePalette(
      cardSurface: isDark ? const Color(0xFF171717) : cs.surfaceContainerHigh,
      cardBorder: isDark ? const Color(0xFF333333) : cs.outlineVariant,
      mutedSurface: isDark ? const Color(0xFF1F1F22) : cs.surfaceContainerLow,
      accentSurface: isDark
          ? cs.primary.withValues(alpha: 0.14)
          : cs.primary.withValues(alpha: 0.06),
      accentBorder: isDark
          ? cs.primary.withValues(alpha: 0.48)
          : cs.primary.withValues(alpha: 0.32),
      tealSurface: isDark
          ? cs.secondary.withValues(alpha: 0.14)
          : cs.secondary.withValues(alpha: 0.08),
      tealBorder: isDark
          ? cs.secondary.withValues(alpha: 0.42)
          : cs.secondary.withValues(alpha: 0.28),
      codeSurface:
          appColors?.codeBackground ??
          (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F0EB)),
      codeBorder:
          appColors?.codeBorder ??
          (isDark ? const Color(0xFF3D3D3D) : cs.outlineVariant),
      hintSurface:
          appColors?.warningBubble ??
          (isDark ? const Color(0xFF281F0A) : const Color(0xFFFFFBEB)),
      hintBorder:
          appColors?.warningBubbleBorder ??
          (isDark ? const Color(0xFF784E12) : const Color(0xFFF59E0B)),
      hintForeground:
          appColors?.warningText ??
          (isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E)),
      successColor:
          appColors?.statusOnline ??
          (isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A)),
    );
  }
}

/// Computes a safe popover anchor for share sheets on iPad / macOS.
Rect? shareOriginFromContext(BuildContext context) {
  final renderObject = context.findRenderObject();
  if (renderObject is RenderBox && renderObject.hasSize) {
    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
  }
  return null;
}

/// Shared card surface with crisp 1px border that remains legible in dark mode.
class GuideCard extends StatelessWidget {
  const GuideCard({
    super.key,
    required this.child,
    this.highlighted = false,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final bool highlighted;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final palette = GuidePalette.of(context);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: highlighted ? palette.accentSurface : palette.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlighted ? palette.accentBorder : palette.cardBorder,
          width: highlighted ? 1.5 : 1,
        ),
      ),
      child: child,
    );
  }
}

/// Pill badge used for "Recommended" or step labels.
class GuideBadge extends StatelessWidget {
  const GuideBadge({
    super.key,
    required this.label,
    this.filled = true,
    this.icon,
  });

  final String label;
  final bool filled;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final palette = GuidePalette.of(context);
    final fg = filled ? cs.onPrimary : cs.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? cs.primary : palette.accentSurface,
        borderRadius: BorderRadius.circular(999),
        border: filled ? null : Border.all(color: palette.accentBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Numbered step row with high-contrast badge.
class GuideNumberedStep extends StatelessWidget {
  const GuideNumberedStep({
    super.key,
    required this.number,
    required this.title,
    this.detail,
    this.trailing,
  });

  final int number;
  final String title;
  final String? detail;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(
            '$number',
            style: theme.textTheme.labelMedium?.copyWith(
              color: cs.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (detail != null && detail!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  detail!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
              if (trailing != null) ...[const SizedBox(height: 8), trailing!],
            ],
          ),
        ),
      ],
    );
  }
}

/// Bullet item with a colored icon and readable body text.
class GuideBulletItem extends StatelessWidget {
  const GuideBulletItem({
    super.key,
    required this.text,
    this.icon = Icons.check_circle_rounded,
    this.iconColor,
  });

  final String text;
  final IconData icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 17, color: iconColor ?? cs.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurface,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

enum GuideCalloutTone { hint, info }

/// Readable callout box for tips and notes in both light and dark themes.
class GuideCallout extends StatelessWidget {
  const GuideCallout({
    super.key,
    required this.icon,
    required this.text,
    this.title,
    this.tone = GuideCalloutTone.hint,
  });

  final IconData icon;
  final String? title;
  final String text;
  final GuideCalloutTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final palette = GuidePalette.of(context);
    final bg = switch (tone) {
      GuideCalloutTone.hint => palette.hintSurface,
      GuideCalloutTone.info => palette.tealSurface,
    };
    final border = switch (tone) {
      GuideCalloutTone.hint => palette.hintBorder,
      GuideCalloutTone.info => palette.tealBorder,
    };
    final iconColor = switch (tone) {
      GuideCalloutTone.hint => palette.hintForeground,
      GuideCalloutTone.info => cs.secondary,
    };
    final textColor = switch (tone) {
      GuideCalloutTone.hint => palette.hintForeground,
      GuideCalloutTone.info => cs.onSurface,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  text,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: textColor,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Monospace command or URL box with one-tap copy feedback and optional share /
/// external-open action buttons.
class GuideCopyableBox extends StatefulWidget {
  const GuideCopyableBox({
    super.key,
    required this.value,
    this.displayValue,
    this.label,
    this.copyButtonKey,
    this.copyLabel,
    this.shareText,
    this.shareLabel,
    this.shareButtonKey,
    this.openUrl,
    this.openLabel,
    this.openButtonKey,
  });

  /// Exact text written to the clipboard when copied.
  final String value;

  /// Optional shorter label shown in the box (defaults to [value]).
  final String? displayValue;

  /// Short caption shown above the monospace text.
  final String? label;

  final Key? copyButtonKey;
  final String? copyLabel;

  /// When non-null, renders a share button that sends [shareText].
  final String? shareText;
  final String? shareLabel;
  final Key? shareButtonKey;

  /// When non-null, renders a button that opens [openUrl] externally.
  final String? openUrl;
  final String? openLabel;
  final Key? openButtonKey;

  @override
  State<GuideCopyableBox> createState() => _GuideCopyableBoxState();
}

class _GuideCopyableBoxState extends State<GuideCopyableBox> {
  bool _copied = false;
  Timer? _resetTimer;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleCopy() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final copiedMessage = AppLocalizations.of(context).copied;
    await Clipboard.setData(ClipboardData(text: widget.value));
    if (!mounted) return;
    _resetTimer?.cancel();
    setState(() => _copied = true);
    _resetTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _copied = false);
    });
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(copiedMessage)));
  }

  Future<void> _handleShare(BuildContext buttonContext) async {
    final text = widget.shareText;
    if (text == null) return;
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        sharePositionOrigin: shareOriginFromContext(buttonContext),
      ),
    );
  }

  Future<void> _handleOpen() async {
    final url = widget.openUrl;
    if (url == null) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l = AppLocalizations.of(context);
    final palette = GuidePalette.of(context);
    final hasActionRow =
        widget.shareText != null ||
        widget.openUrl != null ||
        widget.copyLabel != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: theme.textTheme.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Container(
          padding: EdgeInsets.fromLTRB(
            12,
            hasActionRow ? 10 : 6,
            hasActionRow ? 12 : 4,
            hasActionRow ? 10 : 6,
          ),
          decoration: BoxDecoration(
            color: palette.codeSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: palette.codeBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: SelectableText(
                  widget.displayValue ?? widget.value,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'JetBrainsMono',
                    fontFamilyFallback: const ['monospace'],
                    fontSize: 13,
                    color: cs.onSurface,
                    height: 1.4,
                  ),
                ),
              ),
              if (!hasActionRow)
                IconButton(
                  key:
                      widget.copyButtonKey ??
                      ValueKey('guide_copy_button:${widget.value}'),
                  visualDensity: VisualDensity.compact,
                  tooltip: _copied ? l.copied : l.copy,
                  icon: Icon(
                    _copied ? Icons.check_rounded : Icons.copy_rounded,
                    size: 18,
                    color: _copied ? palette.successColor : cs.onSurfaceVariant,
                  ),
                  onPressed: _handleCopy,
                ),
            ],
          ),
        ),
        if (hasActionRow) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key:
                    widget.copyButtonKey ??
                    ValueKey('guide_copy_button:${widget.value}'),
                style: FilledButton.styleFrom(
                  backgroundColor: _copied
                      ? palette.successColor.withValues(alpha: 0.16)
                      : palette.accentSurface,
                  foregroundColor: _copied ? palette.successColor : cs.primary,
                  side: BorderSide(
                    color: _copied
                        ? palette.successColor.withValues(alpha: 0.5)
                        : palette.accentBorder,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _handleCopy,
                icon: Icon(
                  _copied ? Icons.check_rounded : Icons.copy_rounded,
                  size: 16,
                ),
                label: Text(_copied ? l.copied : (widget.copyLabel ?? l.copy)),
              ),
              if (widget.shareText != null)
                Builder(
                  builder: (buttonContext) => OutlinedButton.icon(
                    key: widget.shareButtonKey,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _handleShare(buttonContext),
                    icon: const Icon(Icons.ios_share_rounded, size: 16),
                    label: Text(widget.shareLabel ?? l.share),
                  ),
                ),
              if (widget.openUrl != null)
                OutlinedButton.icon(
                  key: widget.openButtonKey,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: _handleOpen,
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: Text(widget.openLabel ?? l.guideOpenWebsite),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Clean accordion card so optional details do not overwhelm first-time users.
class GuideExpandableSection extends StatefulWidget {
  const GuideExpandableSection({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.toggleKey,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Key? toggleKey;
  final bool initiallyExpanded;

  @override
  State<GuideExpandableSection> createState() => _GuideExpandableSectionState();
}

class _GuideExpandableSectionState extends State<GuideExpandableSection> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final palette = GuidePalette.of(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: widget.toggleKey,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  Icon(widget.icon, size: 18, color: cs.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: 20,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Divider(height: 1, color: palette.cardBorder),
            Padding(padding: const EdgeInsets.all(14), child: widget.child),
          ],
        ],
      ),
    );
  }
}

/// Brand-styled provider pills for Codex, Claude, and Antigravity.
class GuideProviderBadges extends StatelessWidget {
  const GuideProviderBadges({super.key});

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _ProviderPill(provider: Provider.codex, label: 'Codex'),
        _ProviderPill(provider: Provider.claude, label: 'Claude'),
        _ProviderPill(provider: Provider.antigravity, label: 'Antigravity'),
      ],
    );
  }
}

class _ProviderPill extends StatelessWidget {
  const _ProviderPill({required this.provider, required this.label});

  final Provider provider;
  final String label;

  @override
  Widget build(BuildContext context) {
    final style = providerStyleFor(context, provider);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: style.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ProviderIcon(provider, size: 14, color: style.foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: style.foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
