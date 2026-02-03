import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class GalleryEmptyState extends StatelessWidget {
  final bool isSessionMode;

  const GalleryEmptyState({super.key, required this.isSessionMode});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.preview,
                size: 40,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No previews yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              isSessionMode
                  ? 'Use /preview command to capture screenshots from this session.'
                  : 'Screenshots from Claude sessions will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: appColors.subtleText),
            ),
          ],
        ),
      ),
    );
  }
}
