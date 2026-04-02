import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class ExploreBreadcrumbs extends StatelessWidget {
  final String projectName;
  final String currentPath;
  final List<String> breadcrumbs;
  final ValueChanged<String> onTapCrumb;

  const ExploreBreadcrumbs({
    super.key,
    required this.projectName,
    required this.currentPath,
    required this.breadcrumbs,
    required this.onTapCrumb,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            projectName,
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          if (currentPath.isEmpty)
            Text(
              '/',
              style: textTheme.bodySmall?.copyWith(
                color: appColors.subtleText,
                fontFamily: 'monospace',
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ActionChip(
                  key: const ValueKey('explore_breadcrumb_root'),
                  label: const Text('/'),
                  onPressed: () => onTapCrumb(''),
                ),
                for (final crumb in breadcrumbs)
                  ActionChip(
                    key: ValueKey('explore_breadcrumb_$crumb'),
                    label: Text(crumb.split('/').last),
                    onPressed: () => onTapCrumb(crumb),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
