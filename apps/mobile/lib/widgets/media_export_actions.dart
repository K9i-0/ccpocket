import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../services/photo_library_service.dart';

/// Exports the original image, including images held only in memory.
class MediaExportActions extends StatefulWidget {
  final String? url;
  final Uint8List? bytes;
  final String? mimeType;
  final bool showShare;
  final bool allowSave;

  const MediaExportActions({
    super.key,
    this.url,
    this.bytes,
    this.mimeType,
    this.showShare = true,
    this.allowSave = true,
  });

  @override
  State<MediaExportActions> createState() => _MediaExportActionsState();
}

class _MediaExportActionsState extends State<MediaExportActions> {
  bool _busy = false;

  Future<void> _export(bool save) async {
    if (_busy) return;
    final source = widget;
    final box = context.findRenderObject() as RenderBox;
    final origin = box.localToGlobal(Offset.zero) & box.size;
    setState(() => _busy = true);
    final l = AppLocalizations.of(context);
    try {
      final bytes =
          source.bytes ?? await PhotoLibraryService.loadBytes(source.url!);
      if (save) {
        await PhotoLibraryService.save(bytes: bytes);
        if (mounted) _message(l.savedToPhotos);
      } else {
        final mime = source.mimeType ?? imageMimeType(bytes);
        final extension = switch (mime) {
          'image/jpeg' => 'jpg',
          'image/gif' => 'gif',
          'image/webp' => 'webp',
          'image/svg+xml' => 'svg',
          _ => 'png',
        };
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile.fromData(bytes, mimeType: mime)],
            fileNameOverrides: ['image.$extension'],
            sharePositionOrigin: origin,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        _message(save ? photoSaveError(l, error) : l.failedToShareImage);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (PhotoLibraryService.supported && widget.allowSave)
          IconButton(
            key: const ValueKey('media_save_to_photos_button'),
            tooltip: l.saveToPhotos,
            onPressed: _busy ? null : () => _export(true),
            icon: const Icon(Icons.save_alt),
          ),
        if (widget.showShare &&
            (kIsWeb || defaultTargetPlatform != TargetPlatform.linux))
          IconButton(
            key: const ValueKey('media_share_button'),
            tooltip: l.share,
            onPressed: _busy ? null : () => _export(false),
            icon: const Icon(Icons.share),
          ),
        if (_busy)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }
}

String photoSaveError(AppLocalizations l, Object error) =>
    error is PlatformException && error.code == 'permission_denied'
    ? l.photosPermissionDenied
    : l.saveToPhotosFailed;

String imageMimeType(Uint8List bytes) {
  if (bytes.length >= 3 && bytes[0] == 0xff && bytes[1] == 0xd8) {
    return 'image/jpeg';
  }
  if (bytes.length >= 3 && bytes[0] == 0x47 && bytes[1] == 0x49) {
    return 'image/gif';
  }
  if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
    return 'image/webp';
  }
  return 'image/png';
}
