import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/services/native_file_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ccpocket/file_picker');

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('decodes Android document-picker results', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'pickFiles');
          return [
            {
              'name': 'synthetic.txt',
              'mimeType': 'text/plain',
              'bytes': Uint8List.fromList([104, 105]),
            },
          ];
        });

    final files = await NativeFilePicker.instance.pickFiles();

    expect(files, hasLength(1));
    expect(files.single.name, 'synthetic.txt');
    expect(files.single.mimeType, 'text/plain');
    expect(files.single.bytes, [104, 105]);
  });

  test('returns no files on unsupported platforms', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(await NativeFilePicker.instance.pickFiles(), isEmpty);
  });
}
