import 'dart:async';

import 'package:ccpocket/features/chat_session/widgets/ios_image_paste_button.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const clipboard = MethodChannel('ccpocket/clipboard');
  final calls = <String>[];
  var supported = true;
  var legacyPastes = 0;
  int? viewId;
  final received = <({Uint8List bytes, String mimeType})>[];

  void iosTest(String description, WidgetTesterCallback callback) {
    testWidgets(
      description,
      callback,
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }

  setUp(() {
    supported = true;
    legacyPastes = 0;
    viewId = null;
    calls.clear();
    received.clear();
    messenger.setMockMethodCallHandler(clipboard, (call) async {
      calls.add(call.method);
      return supported;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        viewId = (call.arguments as Map)['id'] as int;
      }
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(clipboard, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
  });

  Future<void> pumpButton(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: IOSImagePasteButton(
            onImage: (bytes, mimeType) =>
                received.add((bytes: bytes, mimeType: mimeType)),
            onLegacyPaste: () => legacyPastes++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> nativeEvent(String method, [Object? args]) async {
    final done = Completer<void>();
    messenger.handlePlatformMessage(
      'ccpocket/image_paste_button/$viewId',
      const StandardMethodCodec().encodeMethodCall(MethodCall(method, args)),
      (_) => done.complete(),
    );
    await done.future;
  }

  iosTest(
    'uses native control without reading clipboard; delivers image once',
    (tester) async {
      await pumpButton(tester);
      expect(find.byType(UiKitView), findsOneWidget);
      expect(calls, ['supportsPasteControl']);
      expect(legacyPastes, 0);
      final bytes = Uint8List.fromList([1, 2, 3]);
      await nativeEvent('image', {'bytes': bytes, 'mimeType': 'image/webp'});
      await nativeEvent('image', {'bytes': bytes, 'mimeType': 'image/webp'});
      expect(received, hasLength(1));
      expect(received.single.bytes, bytes);
      expect(received.single.mimeType, 'image/webp');
    },
  );

  iosTest('native failure permits retry without direct clipboard fallback', (
    tester,
  ) async {
    await pumpButton(tester);
    await nativeEvent('error');
    await tester.pump();
    expect(find.text('Failed to read clipboard'), findsOneWidget);
    expect(legacyPastes, 0);
    await nativeEvent('image', {
      'bytes': Uint8List.fromList([1]),
      'mimeType': 'image/png',
    });
    expect(received, hasLength(1));
  });

  iosTest('invalid payload is rejected and closing ignores late events', (
    tester,
  ) async {
    await pumpButton(tester);
    await nativeEvent('image', {
      'bytes': Uint8List(0),
      'mimeType': 'image/png',
    });
    expect(received, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await nativeEvent('image', {
      'bytes': Uint8List.fromList([1]),
      'mimeType': 'image/png',
    });
    expect(received, isEmpty);
    expect(tester.takeException(), isNull);
  });

  iosTest('older iOS retains explicit legacy paste action', (tester) async {
    supported = false;
    await pumpButton(tester);
    expect(find.byType(UiKitView), findsNothing);
    expect(legacyPastes, 0);
    await tester.tap(find.text('Paste from Clipboard'));
    expect(legacyPastes, 1);
  });

  iosTest('old runner without native method retains legacy action', (
    tester,
  ) async {
    messenger.setMockMethodCallHandler(
      clipboard,
      (_) async => throw MissingPluginException(),
    );
    await pumpButton(tester);
    await tester.tap(find.text('Paste from Clipboard'));
    expect(legacyPastes, 1);
  });

  iosTest('dismissed sheet ignores a result during its reverse animation', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: Text('Home')),
      ),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              builder: (sheetContext) => IOSImagePasteSheet(
                onImage: (bytes, mimeType) {
                  Navigator.pop(sheetContext);
                  received.add((bytes: bytes, mimeType: mimeType));
                },
                onLegacyPaste: () {},
              ),
            ),
            child: const Text('Chat: paste image'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chat: paste image'));
    await tester.pumpAndSettle();
    expect(find.byType(IOSImagePasteButton), findsOneWidget);
    navigator.currentState!.pop();
    // No pump: the sheet and its channel still exist during reverse animation.
    await nativeEvent('image', {
      'bytes': Uint8List.fromList([1]),
      'mimeType': 'image/png',
    });
    await tester.pumpAndSettle();
    expect(received, isEmpty);
    expect(find.text('Chat: paste image'), findsOneWidget);
    expect(navigator.currentState!.canPop(), isTrue);
  });

  iosTest('capability error does not silently read clipboard', (tester) async {
    messenger.setMockMethodCallHandler(
      clipboard,
      (_) async => throw PlatformException(code: 'unavailable'),
    );
    await pumpButton(tester);
    expect(find.text('Failed to read clipboard'), findsOneWidget);
    expect(find.byType(UiKitView), findsNothing);
    expect(legacyPastes, 0);
  });
}
