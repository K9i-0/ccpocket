import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../theme/app_theme.dart';
import '../../../utils/diff_parser.dart';
import 'diff_image_viewer.dart';

/// Formats a byte count into a human-readable string.
String _formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Side-by-side image comparison widget for the diff screen.
///
/// Display modes based on image size (thresholds configured on Bridge server):
/// 1. Auto-display loading (≤ auto threshold, not yet loaded): auto-triggers load.
/// 2. Tap to load (auto threshold – max size): placeholder with load button.
/// 3. Text only (> max size): size info only.
/// 4. Loaded: side-by-side comparison.
class DiffImageWidget extends StatefulWidget {
  final DiffFile file;
  final DiffImageData imageData;
  final VoidCallback? onLoadRequested;
  final bool loading;

  const DiffImageWidget({
    super.key,
    required this.file,
    required this.imageData,
    this.onLoadRequested,
    this.loading = false,
  });

  @override
  State<DiffImageWidget> createState() => _DiffImageWidgetState();
}

class _DiffImageWidgetState extends State<DiffImageWidget> {
  bool _autoLoadTriggered = false;

  @override
  void didUpdateWidget(DiffImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset trigger if the file changed
    if (oldWidget.file.filePath != widget.file.filePath) {
      _autoLoadTriggered = false;
    }
  }

  void _triggerAutoLoad() {
    if (_autoLoadTriggered) return;
    _autoLoadTriggered = true;
    // Schedule after frame to avoid calling during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onLoadRequested?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final imageData = widget.imageData;

    // Loaded → show side-by-side comparison
    if (imageData.loaded) {
      return GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                DiffImageViewer(file: widget.file, imageData: imageData),
          ),
        ),
        child: Stack(
          children: [
            _SideBySideView(
              file: widget.file,
              imageData: imageData,
              appColors: appColors,
            ),
            Positioned(
              right: 12,
              bottom: 16,
              child: Icon(
                Icons.fullscreen,
                size: 20,
                color: appColors.subtleText,
              ),
            ),
          ],
        ),
      );
    }

    // Not loadable → image too large or unavailable
    if (!imageData.loadable) {
      return _TextOnlyNotice(imageData: imageData, appColors: appColors);
    }

    // Auto-display: trigger load automatically when widget is built
    if (imageData.autoDisplay) {
      _triggerAutoLoad();
      return _AutoLoadPlaceholder(imageData: imageData, appColors: appColors);
    }

    // Loadable but not auto-display → tap to load
    return _TapToLoadNotice(
      imageData: imageData,
      appColors: appColors,
      onLoadRequested: widget.onLoadRequested,
      loading: widget.loading,
    );
  }
}

// ---------------------------------------------------------------------------
// Auto-load placeholder (auto-display images loading in background)
// ---------------------------------------------------------------------------

class _AutoLoadPlaceholder extends StatelessWidget {
  final DiffImageData imageData;
  final AppColors appColors;

  const _AutoLoadPlaceholder({
    required this.imageData,
    required this.appColors,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(height: 8),
          _SizeInfoRow(imageData: imageData, appColors: appColors),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Text-only notice (exceeds max size threshold)
// ---------------------------------------------------------------------------

class _TextOnlyNotice extends StatelessWidget {
  final DiffImageData imageData;
  final AppColors appColors;

  const _TextOnlyNotice({required this.imageData, required this.appColors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_outlined, size: 40, color: appColors.subtleText),
          const SizedBox(height: 8),
          Text(
            imageData.oldSize != null || imageData.newSize != null
                ? 'Image too large for preview'
                : 'Image preview not available',
            style: TextStyle(color: appColors.subtleText),
          ),
          const SizedBox(height: 4),
          _SizeInfoRow(imageData: imageData, appColors: appColors),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tap to load (between auto-display and max thresholds)
// ---------------------------------------------------------------------------

class _TapToLoadNotice extends StatelessWidget {
  final DiffImageData imageData;
  final AppColors appColors;
  final VoidCallback? onLoadRequested;
  final bool loading;

  const _TapToLoadNotice({
    required this.imageData,
    required this.appColors,
    this.onLoadRequested,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_outlined, size: 40, color: appColors.subtleText),
          const SizedBox(height: 8),
          _SizeInfoRow(imageData: imageData, appColors: appColors),
          const SizedBox(height: 12),
          if (loading)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            OutlinedButton.icon(
              onPressed: onLoadRequested,
              icon: const Icon(Icons.download_outlined, size: 18),
              label: const Text('Tap to load preview'),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Side-by-side comparison
// ---------------------------------------------------------------------------

class _SideBySideView extends StatelessWidget {
  final DiffFile file;
  final DiffImageData imageData;
  final AppColors appColors;

  const _SideBySideView({
    required this.file,
    required this.imageData,
    required this.appColors,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Side-by-side images
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Before
                Expanded(
                  child: _ImagePanel(
                    label: 'Before',
                    bytes: imageData.oldBytes,
                    isSvg: imageData.isSvg,
                    placeholder: file.isNewFile ? 'New file' : null,
                    appColors: appColors,
                  ),
                ),
                const SizedBox(width: 8),
                // After
                Expanded(
                  child: _ImagePanel(
                    label: 'After',
                    bytes: imageData.newBytes,
                    isSvg: imageData.isSvg,
                    placeholder: file.isDeleted ? 'Deleted' : null,
                    appColors: appColors,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Size info
          _SizeInfoRow(imageData: imageData, appColors: appColors),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single image panel (Before / After)
// ---------------------------------------------------------------------------

class _ImagePanel extends StatelessWidget {
  final String label;
  final Uint8List? bytes;
  final bool isSvg;
  final String? placeholder;
  final AppColors appColors;

  const _ImagePanel({
    required this.label,
    this.bytes,
    this.isSvg = false,
    this.placeholder,
    required this.appColors,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: appColors.subtleText,
          ),
        ),
        const SizedBox(height: 4),
        // Image or placeholder
        Flexible(
          child: Container(
            constraints: const BoxConstraints(minHeight: 80, maxHeight: 200),
            decoration: BoxDecoration(
              border: Border.all(color: appColors.codeBorder),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: placeholder != null
                  ? _PlaceholderContent(
                      text: placeholder!,
                      appColors: appColors,
                    )
                  : bytes != null
                  ? _ImageContent(
                      bytes: bytes!,
                      isSvg: isSvg,
                      appColors: appColors,
                    )
                  : _PlaceholderContent(
                      text: 'Unavailable',
                      appColors: appColors,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Image content renderer
// ---------------------------------------------------------------------------

class _ImageContent extends StatelessWidget {
  final Uint8List bytes;
  final bool isSvg;
  final AppColors appColors;

  const _ImageContent({
    required this.bytes,
    required this.isSvg,
    required this.appColors,
  });

  @override
  Widget build(BuildContext context) {
    if (isSvg) {
      return SvgPicture.memory(
        bytes,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => Center(
          child: Icon(Icons.image_outlined, color: appColors.subtleText),
        ),
      );
    }
    return Image.memory(
      bytes,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) =>
          Center(child: Icon(Icons.broken_image, color: appColors.subtleText)),
    );
  }
}

// ---------------------------------------------------------------------------
// Placeholder for new/deleted/unavailable panels
// ---------------------------------------------------------------------------

class _PlaceholderContent extends StatelessWidget {
  final String text;
  final AppColors appColors;

  const _PlaceholderContent({required this.text, required this.appColors});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: TextStyle(
          color: appColors.subtleText,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Size info row
// ---------------------------------------------------------------------------

class _SizeInfoRow extends StatelessWidget {
  final DiffImageData imageData;
  final AppColors appColors;

  const _SizeInfoRow({required this.imageData, required this.appColors});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (imageData.oldSize != null) {
      parts.add(_formatFileSize(imageData.oldSize!));
    }
    if (imageData.newSize != null) {
      parts.add(_formatFileSize(imageData.newSize!));
    }
    final sizeText = parts.join(' → ');

    return Text(
      sizeText.isNotEmpty ? sizeText : 'Size unknown',
      style: TextStyle(fontSize: 12, color: appColors.subtleText),
    );
  }
}
