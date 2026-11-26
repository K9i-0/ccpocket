import 'package:ccpocket/services/clipboard_image_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(ClipboardImageService.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    ClipboardImageService.debugOverride = null;
  });

  group('ClipboardImageService', () {
    test('hasImage returns true/false from native channel', () async {
      var hasImageResult = true;
      final methods = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        methods.add(call.method);
        return hasImageResult;
      });

      final service = ClipboardImageService(isWeb: false);
      expect(await service.hasImage(), isTrue);

      hasImageResult = false;
      expect(await service.hasImage(), isFalse);
      expect(methods, ['hasImage', 'hasImage']);
    });

    test('hasImage falls back to false on MissingPluginException', () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw MissingPluginException(),
      );

      final service = ClipboardImageService(isWeb: false);
      expect(await service.hasImage(), isFalse);
    });

    test('hasImage falls back to false on PlatformException', () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: 'unavailable'),
      );

      final service = ClipboardImageService(isWeb: false);
      expect(await service.hasImage(), isFalse);
    });

    test(
      'hasImage and readImage return false/null on Web without calling channel',
      () async {
        var called = false;
        messenger.setMockMethodCallHandler(channel, (_) async {
          called = true;
          return true;
        });

        final service = ClipboardImageService(isWeb: true);
        expect(service.isAvailable, isFalse);
        expect(await service.hasImage(), isFalse);
        expect(await service.readImage(), isNull);
        expect(called, isFalse);
      },
    );

    test('readImage parses all supported MIME types', () async {
      for (final mimeType in supportedClipboardImageMimeTypes) {
        final expectedBytes = Uint8List.fromList([1, 2, 3, 4]);
        messenger.setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'readImage');
          return {'bytes': expectedBytes, 'mimeType': mimeType};
        });

        final service = ClipboardImageService(isWeb: false);
        final result = await service.readImage();
        expect(result, isNotNull);
        expect(result!.bytes, expectedBytes);
        expect(result.mimeType, mimeType);
      }
    });

    test('readImage returns null when clipboard has no image', () async {
      messenger.setMockMethodCallHandler(channel, (_) async => null);

      final service = ClipboardImageService(isWeb: false);
      expect(await service.readImage(), isNull);
    });

    test('readImage falls back to null on MissingPluginException', () async {
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw MissingPluginException(),
      );

      final service = ClipboardImageService(isWeb: false);
      expect(await service.readImage(), isNull);
    });

    test(
      'readImage propagates PlatformException so UI can show errors',
      () async {
        messenger.setMockMethodCallHandler(
          channel,
          (_) async => throw PlatformException(code: 'image_load_failed'),
        );

        final service = ClipboardImageService(isWeb: false);
        await expectLater(
          service.readImage(),
          throwsA(
            isA<PlatformException>().having(
              (e) => e.code,
              'code',
              'image_load_failed',
            ),
          ),
        );
      },
    );

    test('readImage rejects empty bytes and unsupported MIME types', () async {
      final invalidPayloads = <Object?>[
        {'bytes': Uint8List(0), 'mimeType': 'image/png'},
        {
          'bytes': Uint8List.fromList([1, 2]),
          'mimeType': 'image/svg+xml',
        },
        {'bytes': 'not-bytes', 'mimeType': 'image/png'},
        {
          'bytes': Uint8List.fromList([1, 2]),
        },
      ];

      final service = ClipboardImageService(isWeb: false);
      for (final payload in invalidPayloads) {
        messenger.setMockMethodCallHandler(channel, (_) async => payload);
        expect(await service.readImage(), isNull);
      }
    });

    test('debugOverride replaces singleton instance cleanly', () async {
      const customChannel = MethodChannel('ccpocket/clipboard_test_override');
      messenger.setMockMethodCallHandler(customChannel, (call) async {
        if (call.method == 'hasImage') return true;
        if (call.method == 'readImage') {
          return {
            'bytes': Uint8List.fromList([7, 8, 9]),
            'mimeType': 'image/gif',
          };
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(customChannel, null),
      );

      ClipboardImageService.debugOverride = ClipboardImageService(
        channel: customChannel,
        isWeb: false,
      );

      expect(await ClipboardImageService.instance.hasImage(), isTrue);
      final image = await ClipboardImageService.instance.readImage();
      expect(image?.mimeType, 'image/gif');
      expect(image?.bytes, Uint8List.fromList([7, 8, 9]));
    });
  });
}
