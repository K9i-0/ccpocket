import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class DiffErrorState extends StatelessWidget {
  final String error;

  const DiffErrorState({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: appColors.errorText),
            const SizedBox(height: 12),
            Text(
              error,
              style: TextStyle(color: appColors.errorText),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
