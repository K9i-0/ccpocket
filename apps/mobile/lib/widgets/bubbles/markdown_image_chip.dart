import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../features/file_peek/file_path_syntax.dart';

/// Local file path for a markdown image destination, or null for remote
/// images (http, https, data, ...), which keep the default rendering.
String? markdownLocalImagePath(Uri uri) {
  if (uri.scheme == 'file') {
    try {
      return uri.toFilePath();
    } catch (_) {
      return null;
    }
  }
  // A single-letter scheme is a Windows drive letter (C:/...), not a URL.
  if (uri.hasScheme && uri.scheme.length > 1) return null;
  if (uri.hasAuthority) return null;
  final raw = uri.toString();
  if (raw.isEmpty) return null;
  try {
    return Uri.decodeFull(raw);
  } catch (_) {
    return raw;
  }
}

/// Builds markdown images in chat text.
///
/// A phone cannot load a path on the Bridge host directly, so local images
/// become a compact tappable label here; the Bridge attaches the actual
/// pictures to the message and they are shown as a gallery below the text.
MarkdownSizedImageBuilder chatMarkdownImageBuilder({
  required FilePathTapCallback? onFileTap,
}) {
  return (config) {
    final path = markdownLocalImagePath(config.uri);
    if (path == null) {
      return Image.network(
        config.uri.toString(),
        width: config.width,
        height: config.height,
        errorBuilder: (context, error, stackTrace) =>
            _MarkdownImageChip(label: config.alt ?? config.uri.toString()),
      );
    }
    final alt = config.alt?.trim() ?? '';
    return _MarkdownImageChip(
      label: alt.isNotEmpty ? alt : path.split(RegExp(r'[/\\]')).last,
      onTap: onFileTap == null ? null : () => onFileTap(path),
    );
  };
}

class _MarkdownImageChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _MarkdownImageChip({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      key: const ValueKey('markdown_image_chip'),
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_outlined,
            size: 14,
            color: cs.primary.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
