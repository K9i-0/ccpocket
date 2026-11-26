import 'dart:async';

import 'package:ccpocket/services/clipboard_image_service.dart';
import 'package:ccpocket/services/desktop_image_drop_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channelName = DesktopImageDropService.channelName;
  const methodChannel = MethodChannel(channelName);
  const codec = StandardMethodCodec();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<String> lifecycleCalls;

  setUp(() {
    lifecycleCalls = [];
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      lifecycleCalls.add(call.method);
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(methodChannel, null);
    DesktopImageDropService.debugOverride = null;
  });

  Future<void> emitDropEvent(Object? payload) async {
    final done = Completer<void>();
    messenger.handlePlatformMessage(
      channelName,
      codec.encodeSuccessEnvelope(payload),
      (_) => done.complete(),
    );
    await done.future;
  }

  group('DesktopImageDropService', () {
    test(
      'subscribes lazily, parses valid images, and cancels on unsubscribe',
      () async {
        final service = DesktopImageDropService(supported: true);
        final received = <List<ClipboardImageData>>[];

        final sub = service.images.listen(received.add);
        await pumpEventQueue();
        expect(lifecycleCalls, ['listen']);

        final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);
        final gif = Uint8List.fromList([0x47, 0x49, 0x46, 0x38]);
        await emitDropEvent([
          {'bytes': gif, 'mimeType': 'image/gif'},
          {'bytes': Uint8List(0), 'mimeType': 'image/png'}, // ignored
          {'bytes': png, 'mimeType': 'image/bmp'}, // ignored
          {'bytes': png, 'mimeType': 'image/png'},
        ]);
        await pumpEventQueue();

        expect(received, hasLength(1));
        expect(received.single, hasLength(2));
        expect(received.single[0].mimeType, 'image/gif');
        expect(received.single[0].bytes, gif);
        expect(received.single[1].mimeType, 'image/png');
        expect(received.single[1].bytes, png);

        await sub.cancel();
        await pumpEventQueue();
        expect(lifecycleCalls, ['listen', 'cancel']);
      },
    );

    test('accepts single map payload defensively', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final parsed = DesktopImageDropService.parseDroppedImagesPayload({
        'bytes': bytes,
        'mimeType': 'image/webp',
      });
      expect(parsed, hasLength(1));
      expect(parsed.single.mimeType, 'image/webp');
      expect(parsed.single.bytes, bytes);
    });

    test('is a safe no-op when unsupported', () async {
      final service = DesktopImageDropService(supported: false);
      final received = <List<ClipboardImageData>>[];

      final sub = service.images.listen(received.add);
      await pumpEventQueue();
      expect(lifecycleCalls, isEmpty);
      expect(received, isEmpty);
      await sub.cancel();
    });

    test(
      'handles MissingPluginException gracefully without throwing',
      () async {
        messenger.setMockMethodCallHandler(
          methodChannel,
          (_) async => throw MissingPluginException(),
        );

        final service = DesktopImageDropService(supported: true);
        final received = <List<ClipboardImageData>>[];
        final errors = <Object>[];

        final sub = service.images.listen(received.add, onError: errors.add);
        await pumpEventQueue();
        expect(received, isEmpty);
        expect(errors, isEmpty);
        await sub.cancel();
      },
    );
  });

  group('DesktopImageDropTarget', () {
    testWidgets('forwards dropped images when enabled and current route', (
      tester,
    ) async {
      final service = DesktopImageDropService(supported: true);
      final received = <List<ClipboardImageData>>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopImageDropTarget(
              enabled: true,
              service: service,
              onImagesDropped: received.add,
              child: const Text('Composer'),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(lifecycleCalls, ['listen']);

      final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF]);
      await emitDropEvent([
        {'bytes': jpeg, 'mimeType': 'image/jpeg'},
      ]);
      await tester.pump();

      expect(received, hasLength(1));
      expect(received.single.single.mimeType, 'image/jpeg');
      expect(received.single.single.bytes, jpeg);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(lifecycleCalls, ['listen', 'cancel']);
    });

    testWidgets('does not subscribe when disabled', (tester) async {
      final service = DesktopImageDropService(supported: true);
      final received = <List<ClipboardImageData>>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopImageDropTarget(
              enabled: false,
              service: service,
              onImagesDropped: received.add,
              child: const Text('Mobile Composer'),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(lifecycleCalls, isEmpty);
    });

    testWidgets('ignores drops when route is not current', (tester) async {
      final service = DesktopImageDropService(supported: true);
      final received = <List<ClipboardImageData>>[];
      final navKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          home: Scaffold(
            body: DesktopImageDropTarget(
              enabled: true,
              service: service,
              onImagesDropped: received.add,
              child: const Text('Chat'),
            ),
          ),
        ),
      );
      await tester.pump();

      navKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Settings')),
        ),
      );
      await tester.pumpAndSettle();

      await emitDropEvent([
        {
          'bytes': Uint8List.fromList([1, 2, 3]),
          'mimeType': 'image/png',
        },
      ]);
      await tester.pump();

      expect(received, isEmpty);
    });
  });
}
