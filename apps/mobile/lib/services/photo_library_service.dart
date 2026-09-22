import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class PhotoLibraryService {
  static const channel = MethodChannel('ccpocket/photo_library');

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static Future<Uint8List> loadBytes(String url) async {
    final uri = Uri.parse(url);
    if (uri.scheme == 'data') return uri.data!.contentAsBytes();
    final response = await http.get(uri).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) throw StateError('Download failed');
    return response.bodyBytes;
  }

  static Future<void> save({
    Uint8List? bytes,
    String? path,
    bool isVideo = false,
  }) {
    assert(bytes != null || path != null);
    return channel.invokeMethod<void>('save', {
      'bytes': ?bytes,
      'path': ?path,
      'isVideo': isVideo,
    });
  }
}
