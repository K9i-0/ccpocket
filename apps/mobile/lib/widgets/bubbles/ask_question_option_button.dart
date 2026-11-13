import 'package:material_ui/material_ui.dart';

import '../../theme/app_theme.dart';

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
    final appColors = Theme.of(context).extension<AppColors>()!;

    return Material(
      color: isSelected
          ? appColors.askIcon.withValues(alpha: 0.1)
          : Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        key: optionKey,
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: askQuestionOptionButtonHeight,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? appColors.askIcon.withValues(alpha: 0.45)
                  : Theme.of(context).colorScheme.outlineVariant
                        .withValues(alpha: 0.5),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              if (isMulti) ...[
                Icon(
                  isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 18,
                  color: isSelected
                      ? appColors.askIcon
                      : appColors.subtleText.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 8),
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
                        color: isSelected ? appColors.askIcon : null,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                  color: appColors.subtleText.withValues(alpha: 0.8),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
