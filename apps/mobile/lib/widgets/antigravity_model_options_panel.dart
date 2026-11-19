import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../models/messages.dart';

/// Model family list with the thinking levels of the selected family on top.
/// Shared by the chat screen's model sheet and the new-session sheet.
class AntigravityModelOptionsPanel extends StatelessWidget {
  final List<AntigravityModelOption> modelOptions;
  final String? model;
  final String? thoughtLevel;

  /// Levels of the selected family; empty when it has none.
  final List<String> thoughtLevels;
  final ValueChanged<AntigravityModelOption> onModelSelected;
  final ValueChanged<String> onThoughtLevelSelected;

  const AntigravityModelOptionsPanel({
    super.key,
    required this.modelOptions,
    required this.model,
    required this.thoughtLevel,
    required this.thoughtLevels,
    required this.onModelSelected,
    required this.onThoughtLevelSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
      ),
    );
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (thoughtLevels.isNotEmpty) ...[
              heading(l.effort),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    key: const ValueKey('antigravity_thought_levels'),
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final level in thoughtLevels)
                        ChoiceChip(
                          key: ValueKey('antigravity_thought_level_$level'),
                          label: Text(antigravityThoughtLevelLabel(level)),
                          selected: level == thoughtLevel,
                          onSelected: (_) => onThoughtLevelSelected(level),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            heading(l.model),
            Flexible(
              child: ListView.builder(
                key: const ValueKey('antigravity_model_list'),
                shrinkWrap: true,
                itemCount: modelOptions.length,
                itemBuilder: (context, index) {
                  final option = modelOptions[index];
                  return ListTile(
                    key: ValueKey('antigravity_model_option_${option.id}'),
                    dense: true,
                    title: Text(option.name),
                    trailing: option.id == model
                        ? Icon(Icons.check, color: cs.tertiary, size: 20)
                        : null,
                    onTap: () => onModelSelected(option),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
