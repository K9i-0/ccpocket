import 'package:material_ui/material_ui.dart';

/// Small label marking a feature that is still a preview.
class PreviewBadge extends StatelessWidget {
  const PreviewBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, color: cs.onTertiaryContainer),
      ),
    );
  }
}
