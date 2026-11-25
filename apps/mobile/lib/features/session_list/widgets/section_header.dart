import 'package:material_ui/material_ui.dart';

class SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Widget? trailing;
  final bool shrinkTrailingToFit;

  const SectionHeader({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.trailing,
    this.shrinkTrailingToFit = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 14, bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color.withValues(alpha: 0.78)),
          const SizedBox(width: 6),
          Flexible(
            fit: FlexFit.tight,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: color,
              ),
            ),
          ),
          if (trailing != null && shrinkTrailingToFit) ...[
            const SizedBox(width: 8),
            Flexible(
              fit: FlexFit.tight,
              child: Align(alignment: Alignment.centerRight, child: trailing!),
            ),
          ] else if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}
