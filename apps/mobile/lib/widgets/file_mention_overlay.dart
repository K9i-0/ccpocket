import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class FileMentionOverlay extends StatelessWidget {
  final List<String> filteredFiles;
  final void Function(String filePath) onSelect;
  final VoidCallback onDismiss;

  const FileMentionOverlay({
    super.key,
    required this.filteredFiles,
    required this.onSelect,
    required this.onDismiss,
  });

  IconData _fileIcon(String path) {
    if (path.endsWith('.dart')) return Icons.code;
    if (path.endsWith('.ts') || path.endsWith('.tsx')) return Icons.javascript;
    if (path.endsWith('.json')) return Icons.data_object;
    if (path.endsWith('.yaml') || path.endsWith('.yml')) return Icons.settings;
    if (path.endsWith('.md')) return Icons.description;
    if (path.contains('/test/')) return Icons.science;
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppColors>()!;
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      color: cs.surfaceContainer,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 220),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant, width: 0.5),
        ),
        child: ListView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: filteredFiles.length,
          itemBuilder: (context, index) {
            final file = filteredFiles[index];
            final fileName = file.split('/').last;
            final dirPath = file.contains('/')
                ? file.substring(0, file.lastIndexOf('/'))
                : '';
            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onSelect(file),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Icon(
                      _fileIcon(file),
                      size: 16,
                      color: appColors.subtleText,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fileName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: cs.primary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (dirPath.isNotEmpty)
                            Text(
                              dirPath,
                              style: TextStyle(
                                fontSize: 10,
                                color: appColors.subtleText,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
