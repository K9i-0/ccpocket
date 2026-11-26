import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Decoded image payload returned by the native clipboard channel.
typedef ClipboardImageData = ({Uint8List bytes, String mimeType});

/// Supported clipboard image MIME types in priority order.
///
/// Original animated/modern formats are preferred before raster fallbacks.
const supportedClipboardImageMimeTypes = <String>[
  'image/gif',
  'image/webp',
  'image/png',
  'image/jpeg',
];

const _supportedMimeTypeSet = <String>{
  'image/gif',
  'image/webp',
  'image/png',
  'image/jpeg',
};

/// Reads images from the system clipboard via the `ccpocket/clipboard` channel.
///
/// Extends the existing `ccpocket/clipboard` channel cleanly alongside the iOS
/// `supportsPasteControl` / `hasSupportedImage` methods.
class ClipboardImageService {
  ClipboardImageService({MethodChannel? channel, bool? isWeb})
    : _channel = channel ?? const MethodChannel(channelName),
      _isWeb = isWeb ?? kIsWeb;

  static const channelName = 'ccpocket/clipboard';

  static final _default = ClipboardImageService();
  static ClipboardImageService? _override;

  static ClipboardImageService get instance => _override ?? _default;

  /// Replaces [instance] in tests; pass null to restore the default instance.
  @visibleForTesting
  static set debugOverride(ClipboardImageService? service) {
    _override = service;
  }

  final MethodChannel _channel;
  final bool _isWeb;

  /// Whether native clipboard image access is available on the current runtime.
  bool get isAvailable => !_isWeb;

  /// Returns whether the clipboard currently contains a supported image.
  ///
  /// Safe on Web and older native runners without this method (returns false).
  Future<bool> hasImage() async {
    if (_isWeb) return false;
    try {
      return await _channel.invokeMethod<bool>('hasImage') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Reads the highest-priority supported image from the clipboard.
  ///
  /// Priority order: `image/gif`, `image/webp`, `image/png`, `image/jpeg`.
  /// Returns `null` when no supported image is on the clipboard, on Web, or on
  /// older native runners without the `readImage` handler.
  ///
  /// Throws [PlatformException] when the native platform reports a read error
  /// (for example `image_load_failed` when an image exceeds the size limit or
  /// fails to decode).
  Future<ClipboardImageData?> readImage() async {
    if (_isWeb) return null;
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'readImage',
      );
      return parseClipboardImagePayload(result);
    } on MissingPluginException {
      return null;
    }
  }

  /// Validates and parses a `{bytes, mimeType}` payload from a platform channel.
  static ClipboardImageData? parseClipboardImagePayload(Object? raw) {
    if (raw is! Map) return null;
    final bytes = raw['bytes'];
    final mimeType = raw['mimeType'];
    if (bytes is! Uint8List || bytes.isEmpty) return null;
    if (mimeType is! String || !_supportedMimeTypeSet.contains(mimeType)) {
      return null;
    }
    return (bytes: bytes, mimeType: mimeType);
  }
}
