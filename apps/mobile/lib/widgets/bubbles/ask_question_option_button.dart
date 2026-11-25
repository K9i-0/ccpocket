import 'package:material_ui/material_ui.dart';

const askQuestionOptionButtonHeight = 44.0;

class AskQuestionOptionButton extends StatelessWidget {
  final Key? optionKey;
  final String label;
  final String description;
  final bool isSelected;
  final bool isMulti;
  final VoidCallback? onTap;

  const AskQuestionOptionButton({
    super.key,
    this.optionKey,
    required this.label,
    required this.description,
    required this.isSelected,
    required this.isMulti,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final backgroundColor = isSelected
        ? cs.primary.withValues(alpha: isDark ? 0.14 : 0.07)
        : (isDark
              ? cs.onSurface.withValues(alpha: 0.045)
              : cs.surfaceContainerLow);
    final borderColor = isSelected
        ? cs.primary.withValues(alpha: isDark ? 0.65 : 0.55)
        : cs.outlineVariant.withValues(alpha: isDark ? 0.75 : 0.85);

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        key: optionKey,
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: askQuestionOptionButtonHeight,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1),
          ),
          child: Row(
            children: [
              if (isMulti) ...[
                Icon(
                  isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 18,
                  color: isSelected
                      ? cs.primary
                      : cs.onSurfaceVariant.withValues(alpha: 0.75),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: cs.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!isMulti) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: isSelected
                      ? cs.primary
                      : cs.onSurfaceVariant.withValues(alpha: 0.65),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
