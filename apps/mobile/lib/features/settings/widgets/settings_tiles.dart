import 'dart:async';

import 'package:flutter/material.dart';

/// Small uppercase label shown above a [SettingsGroup].
class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// A card that stacks settings rows and inserts dividers between them.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    required this.children,
    this.title,
    this.footer,
    this.cardKey,
  });

  final List<Widget> children;
  final String? title;
  final String? footer;
  final Key? cardKey;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          SettingsSectionHeader(title: title!)
        else
          const SizedBox(height: 16),
        SettingsCard(
          key: cardKey,
          child: Column(
            children: [
              for (final (index, child) in children.indexed) ...[
                if (index > 0) const SettingsDivider(),
                child,
              ],
            ],
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              footer!,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

/// Rounded surface shared by every settings group.
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: child,
    );
  }
}

/// Inset divider between rows of a [SettingsCard].
class SettingsDivider extends StatelessWidget {
  const SettingsDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: Theme.of(context).colorScheme.outlineVariant
          .withValues(alpha: 0.55),
    );
  }
}

/// Success color used for "up to date" / "online" states.
Color settingsSuccessColor(Brightness brightness) =>
    brightness == Brightness.dark
    ? const Color(0xFF4ADE80)
    : const Color(0xFF16A34A);

/// Provides the accent color of the current settings category.
class SettingsAccent extends InheritedWidget {
  const SettingsAccent({super.key, required this.color, required super.child});

  final Color color;

  static Color of(BuildContext context) {
    final accent = context.dependOnInheritedWidgetOfExactType<SettingsAccent>();
    return accent?.color ?? Theme.of(context).colorScheme.primary;
  }

  @override
  bool updateShouldNotify(SettingsAccent oldWidget) => color != oldWidget.color;
}

/// Rounded, tinted icon used as the leading widget of settings rows.
class SettingsLeadingIcon extends StatelessWidget {
  const SettingsLeadingIcon(this.icon, {super.key, this.color});

  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? SettingsAccent.of(context);
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 19, color: accent),
    );
  }
}

/// Solid, colored icon badge used for categories.
class SettingsCategoryBadge extends StatelessWidget {
  const SettingsCategoryBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 36,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(color, Colors.white, 0.18)!, color],
        ),
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.28),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, size: size * 0.55, color: Colors.white),
    );
  }
}

/// A row whose control (segmented button, slider, …) sits below its label.
class SettingsControlTile extends StatelessWidget {
  const SettingsControlTile({
    super.key,
    required this.icon,
    required this.title,
    required this.control,
    this.description,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget control;
  final String? description;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SettingsLeadingIcon(icon),
              const SizedBox(width: 16),
              Expanded(child: Text(title, style: theme.textTheme.bodyLarge)),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          control,
          if (description != null) ...[
            const SizedBox(height: 8),
            Text(
              description!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Which settings row should be revealed and highlighted.
class SettingsHighlightScope extends InheritedWidget {
  const SettingsHighlightScope({
    super.key,
    required this.entryId,
    required this.requestId,
    required super.child,
  });

  final String? entryId;

  /// Changes on every request, so the same row can be highlighted again.
  final int requestId;

  static SettingsHighlightScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SettingsHighlightScope>();
  }

  @override
  bool updateShouldNotify(SettingsHighlightScope oldWidget) =>
      entryId != oldWidget.entryId || requestId != oldWidget.requestId;
}

/// Wraps one settings row so that search and deep links can reveal it.
class SettingsItem extends StatefulWidget {
  const SettingsItem({
    super.key,
    required this.id,
    required this.child,
    this.framed = false,
  });

  final String id;
  final Widget child;

  /// Draws the highlight as a rounded frame, for rows that are whole cards.
  final bool framed;

  static Key keyFor(String id) => ValueKey('settings_item_$id');

  @override
  State<SettingsItem> createState() => _SettingsItemState();
}

class _SettingsItemState extends State<SettingsItem> {
  int? _handledRequestId;
  bool _highlighted = false;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = SettingsHighlightScope.maybeOf(context);
    if (scope == null ||
        scope.entryId != widget.id ||
        scope.requestId == _handledRequestId) {
      return;
    }
    _handledRequestId = scope.requestId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
  }

  Future<void> _reveal() async {
    if (!mounted) return;
    await Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      alignment: 0.15,
    );
    if (!mounted) return;
    setState(() => _highlighted = true);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _highlighted = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = SettingsAccent.of(context);
    if (widget.framed) {
      return KeyedSubtree(
        key: SettingsItem.keyFor(widget.id),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            widget.child,
            Positioned(
              left: 8,
              right: 8,
              top: -6,
              bottom: -6,
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: _highlighted ? 0.08 : 0),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: accent.withValues(alpha: _highlighted ? 0.7 : 0),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return KeyedSubtree(
      key: SettingsItem.keyFor(widget.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        color: accent.withValues(alpha: _highlighted ? 0.14 : 0),
        // Keeps ListTile ink splashes visible above the highlight color.
        child: Material(type: MaterialType.transparency, child: widget.child),
      ),
    );
  }
}

/// Standard row that opens a picker or another screen.
class SettingsNavTile extends StatelessWidget {
  const SettingsNavTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.external = false,
  });

  final IconData icon;
  final Widget title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  /// Shows an "open in new" glyph instead of a chevron.
  final bool external;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: SettingsLeadingIcon(icon),
      title: title,
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing:
          trailing ??
          (onTap == null
              ? null
              : Icon(
                  external ? Icons.open_in_new_rounded : Icons.chevron_right,
                  size: external ? 18 : 20,
                  color: cs.onSurfaceVariant,
                )),
      onTap: onTap,
    );
  }
}

/// Standard on/off row.
class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: SettingsLeadingIcon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      value: value,
      onChanged: onChanged,
    );
  }
}
