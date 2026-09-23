import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/ios_clipboard_image_availability.dart';

class IOSImagePasteSheet extends StatelessWidget {
  const IOSImagePasteSheet({
    super.key,
    required this.onImage,
    required this.onLegacyPaste,
  });

  final void Function(Uint8List bytes, String mimeType) onImage;
  final VoidCallback onLegacyPaste;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(AppLocalizations.of(context).pasteImage),
        ),
        IOSImagePasteButton(onImage: onImage, onLegacyPaste: onLegacyPaste),
      ],
    ),
  );
}

/// A genuine system paste control, not a Flutter button that reads the clipboard.
class IOSImagePasteButton extends StatefulWidget {
  const IOSImagePasteButton({
    super.key,
    required this.onImage,
    required this.onLegacyPaste,
    this.menuStyle = false,
    this.cupertinoStyle = false,
  });

  final void Function(Uint8List bytes, String mimeType) onImage;
  final VoidCallback onLegacyPaste;
  final bool menuStyle;
  final bool cupertinoStyle;

  @override
  State<IOSImagePasteButton> createState() => _IOSImagePasteButtonState();
}

class _IOSImagePasteButtonState extends State<IOSImagePasteButton> {
  late final _supported = IOSClipboardImageAvailability.supportsPasteControl();
  MethodChannel? _channel;
  bool _delivered = false;

  void _onPlatformViewCreated(int id) {
    _channel?.setMethodCallHandler(null);
    _channel = MethodChannel('ccpocket/image_paste_button/$id')
      ..setMethodCallHandler(_handleMethodCall);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    // A dismissed sheet stays mounted during its reverse animation. Reject
    // results immediately so its callback cannot pop the underlying chat route.
    if (!mounted || _delivered || ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    switch (call.method) {
      case 'image':
        final args = call.arguments;
        if (args is Map &&
            args['bytes'] is Uint8List &&
            (args['bytes'] as Uint8List).isNotEmpty &&
            const {
              'image/gif',
              'image/webp',
              'image/png',
              'image/jpeg',
            }.contains(args['mimeType'])) {
          _delivered = true;
          widget.onImage(
            args['bytes'] as Uint8List,
            args['mimeType'] as String,
          );
        } else {
          _showError();
        }
      case 'error':
        _showError();
      default:
        throw MissingPluginException(
          'Unknown image paste event: ${call.method}',
        );
    }
  }

  void _showError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).failedToReadClipboard),
      ),
    );
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final sheetColor =
        theme.bottomSheetTheme.modalBackgroundColor ??
        theme.bottomSheetTheme.backgroundColor ??
        (theme.useMaterial3 ? colors.surfaceContainerLow : theme.canvasColor);
    return FutureBuilder<bool>(
      future: _supported,
      builder: (context, snapshot) {
        if (snapshot.data == false) {
          if (widget.cupertinoStyle) {
            return CupertinoActionSheetAction(
              onPressed: widget.onLegacyPaste,
              child: Text(AppLocalizations.of(context).pasteFromClipboard),
            );
          }
          return ListTile(
            leading: const Icon(Icons.content_paste),
            title: Text(AppLocalizations.of(context).pasteFromClipboard),
            onTap: widget.onLegacyPaste,
          );
        }
        if (snapshot.hasError) {
          return ListTile(
            leading: const Icon(Icons.content_paste),
            title: Text(AppLocalizations.of(context).failedToReadClipboard),
            enabled: false,
          );
        }
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: widget.menuStyle || widget.cupertinoStyle ? 2 : 8,
          ),
          child: SizedBox(
            height: 52 * MediaQuery.textScalerOf(context).scale(14) / 14,
            child: snapshot.data == true
                ? UiKitView(
                    key: const ValueKey('ios_image_paste_button'),
                    viewType: 'ccpocket/image_paste_button',
                    creationParamsCodec: const StandardMessageCodec(),
                    creationParams: {
                      'backgroundColor':
                          (widget.cupertinoStyle
                                  ? CupertinoDynamicColor.resolve(
                                      CupertinoColors.secondarySystemBackground,
                                      context,
                                    )
                                  : widget.menuStyle
                                  ? sheetColor
                                  : colors.primary)
                              .toARGB32(),
                      'foregroundColor':
                          (widget.cupertinoStyle
                                  ? CupertinoTheme.of(context).primaryColor
                                  : widget.menuStyle
                                  ? colors.onSurface
                                  : colors.onPrimary)
                              .toARGB32(),
                      'menuStyle': widget.menuStyle,
                      'dark': Theme.of(context).brightness == Brightness.dark,
                    },
                    onPlatformViewCreated: _onPlatformViewCreated,
                  )
                : const Center(child: CircularProgressIndicator()),
          ),
        );
      },
    );
  }
}
