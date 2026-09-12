import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

/// Image sources stay available while clipboard availability is being checked.
class ImageAttachmentSheet extends StatelessWidget {
  const ImageAttachmentSheet({
    super.key,
    required this.clipboardHasImage,
    required this.onGallery,
    required this.onClipboard,
    required this.onSketch,
  });

  final Future<bool> clipboardHasImage;
  final VoidCallback onGallery;
  final VoidCallback onClipboard;
  final VoidCallback onSketch;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: const ValueKey('attach_from_gallery'),
            leading: const Icon(Icons.photo_library),
            title: Text(l.selectFromGallery),
            onTap: onGallery,
          ),
          FutureBuilder<bool>(
            future: clipboardHasImage,
            builder: (context, snapshot) => ListTile(
              key: const ValueKey('attach_from_clipboard'),
              leading: const Icon(Icons.content_paste),
              title: Text(l.pasteFromClipboard),
              enabled: snapshot.data == true,
              onTap: snapshot.data == true ? onClipboard : null,
            ),
          ),
          ListTile(
            key: const ValueKey('attach_sketch'),
            leading: const Icon(Icons.draw_outlined),
            title: Text(l.drawSketch),
            onTap: onSketch,
          ),
        ],
      ),
    );
  }
}
