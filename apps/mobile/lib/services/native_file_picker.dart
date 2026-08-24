import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/messages.dart';

class NativeFilePicker {
  NativeFilePicker._();

  static final instance = NativeFilePicker._();
  static const _channel = MethodChannel('ccpocket/file_picker');

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<List<PendingFileAttachment>> pickFiles() async {
    if (!isSupported) return const [];
    final result = await _channel.invokeListMethod<Object?>('pickFiles');
    if (result == null) return const [];
    return result.map((item) {
      final map = Map<Object?, Object?>.from(item! as Map);
      return (
        bytes: map['bytes']! as Uint8List,
        mimeType: map['mimeType'] as String? ?? 'application/octet-stream',
        name: map['name'] as String? ?? 'attachment',
      );
    }).toList();
  }
}
