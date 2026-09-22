import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';

/// Hosts the system edit menu with an image action identified as native paste.
/// Unlike a generic Flutter custom menu callback, its native action captures
/// the pasteboard while UIKit still knows this is an explicit paste gesture.
class IOSImagePasteContextMenu extends StatefulWidget {
  const IOSImagePasteContextMenu({
    super.key,
    required this.editableTextState,
    required this.onImage,
    required this.fallback,
  });

  final EditableTextState editableTextState;
  final void Function(Uint8List bytes, String mimeType) onImage;
  final Widget fallback;

  @override
  State<IOSImagePasteContextMenu> createState() =>
      _IOSImagePasteContextMenuState();
}

class _IOSImagePasteContextMenuState extends State<IOSImagePasteContextMenu> {
  static const _channel = MethodChannel('ccpocket/image_paste_menu');
  static var _nextId = 0;
  final _requestId = _nextId++;
  var _useFallback = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_show()));
  }

  Future<void> _show() async {
    if (!mounted || !widget.editableTextState.mounted) return;
    final anchor = widget.editableTextState.contextMenuAnchors.primaryAnchor;
    try {
      final payload = await _channel.invokeMapMethod<String, dynamic>('show', {
        'requestId': _requestId,
        'title': AppLocalizations.of(context).pasteImage,
        'x': anchor.dx,
        'y': anchor.dy,
      });
      if (!mounted || ModalRoute.of(context)?.isCurrent == false) return;
      if (payload != null) {
        final bytes = payload['bytes'];
        final mimeType = payload['mimeType'];
        if (bytes is! Uint8List ||
            bytes.isEmpty ||
            !const {
              'image/gif',
              'image/webp',
              'image/png',
              'image/jpeg',
            }.contains(mimeType)) {
          throw PlatformException(code: 'invalid_image');
        }
        widget.onImage(bytes, mimeType as String);
      }
      _hideToolbar();
    } on MissingPluginException {
      // Native code is absent on an older installed runner/OTA update.
      if (mounted) setState(() => _useFallback = true);
    } on PlatformException {
      if (!mounted || ModalRoute.of(context)?.isCurrent == false) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).failedToReadClipboard),
        ),
      );
      _hideToolbar();
    }
  }

  void _hideToolbar() {
    if (widget.editableTextState.mounted) {
      widget.editableTextState.hideToolbar();
    }
  }

  Future<void> _cancel() async {
    try {
      await _channel.invokeMethod<void>('cancel', {'requestId': _requestId});
    } on MissingPluginException {
      // Older runners do not have the native menu channel.
    } on PlatformException {
      // The route is already gone; there is no result left to consume.
    }
  }

  @override
  void dispose() {
    unawaited(_cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _useFallback ? widget.fallback : const SizedBox.shrink();
}
