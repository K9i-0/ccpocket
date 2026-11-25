import 'package:ccpocket/services/desktop_menu_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(DesktopMenuService.channelName);
  late List<MethodCall> outgoingCalls;
  late DesktopMenuService service;

  setUp(() {
    outgoingCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          outgoingCalls.add(call);
          return null;
        });
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<ByteData?> sendNativeCall(String method, [Object? arguments]) {
    final codec = const StandardMethodCodec();
    return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          DesktopMenuService.channelName,
          codec.encodeMethodCall(MethodCall(method, arguments)),
          (_) {},
        );
  }

  group('DesktopMenuService on macOS', () {
    setUp(() {
      service = DesktopMenuService(isSupported: () => true);
    });

    tearDown(() async {
      await service.dispose();
    });

    test(
      'dispatches every known DesktopMenuAction from native onMenuAction',
      () async {
        final received = <DesktopMenuAction>[];
        final sub = service.actions.listen(received.add);

        for (final action in DesktopMenuAction.values) {
          await sendNativeCall('onMenuAction', {'action': action.wireName});
        }
        await Future<void>.delayed(Duration.zero);

        expect(received, DesktopMenuAction.values);
        await sub.cancel();
      },
    );

    test(
      'ignores unknown or malformed action payloads without throwing',
      () async {
        final received = <DesktopMenuAction>[];
        final sub = service.actions.listen(received.add);

        await sendNativeCall('onMenuAction', {'action': 'unknownAction'});
        await sendNativeCall('onMenuAction', {'action': null});
        await sendNativeCall('onMenuAction', 'not-a-map');
        await Future<void>.delayed(Duration.zero);

        expect(received, isEmpty);
        await sub.cancel();
      },
    );

    test('updateMenuState serializes menuTitles and per-item state', () async {
      await service.updateMenuState(
        const DesktopMenuState(
          menuTitles: {
            DesktopTopLevelMenu.file: 'ファイル',
            DesktopTopLevelMenu.view: '表示',
          },
          items: {
            DesktopMenuAction.closeActive: DesktopMenuItemState(
              title: 'セッションを閉じる',
              enabled: true,
            ),
            DesktopMenuAction.toggleSidebar: DesktopMenuItemState(
              enabled: true,
              checked: true,
            ),
            DesktopMenuAction.newSession: DesktopMenuItemState(enabled: false),
          },
        ),
      );

      expect(outgoingCalls, hasLength(1));
      expect(outgoingCalls.single.method, 'updateMenuState');
      expect(outgoingCalls.single.arguments, {
        'menuTitles': {'file': 'ファイル', 'view': '表示'},
        'items': {
          'closeActive': {'title': 'セッションを閉じる', 'enabled': true},
          'toggleSidebar': {'enabled': true, 'checked': true},
          'newSession': {'enabled': false},
        },
      });
    });

    test('setWindowTitle sends title argument', () async {
      await service.setWindowTitle('ccpocket — CC Pocket');

      expect(outgoingCalls, hasLength(1));
      expect(outgoingCalls.single.method, 'setWindowTitle');
      expect(outgoingCalls.single.arguments, {'title': 'ccpocket — CC Pocket'});
    });

    test(
      'setDockBadge sends label and normalizes null to empty string',
      () async {
        await service.setDockBadge('3');
        await service.setDockBadge(null);

        expect(outgoingCalls, hasLength(2));
        expect(outgoingCalls[0].method, 'setDockBadge');
        expect(outgoingCalls[0].arguments, {'label': '3'});
        expect(outgoingCalls[1].method, 'setDockBadge');
        expect(outgoingCalls[1].arguments, {'label': ''});
      },
    );

    test('closeWindow invokes performCloseWindow', () async {
      await service.closeWindow();

      expect(outgoingCalls, hasLength(1));
      expect(outgoingCalls.single.method, 'performCloseWindow');
      expect(outgoingCalls.single.arguments, isNull);
    });

    test('gracefully swallows MissingPluginException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);

      await expectLater(
        service.updateMenuState(const DesktopMenuState()),
        completes,
      );
      await expectLater(service.setWindowTitle('Test'), completes);
      await expectLater(service.setDockBadge('1'), completes);
      await expectLater(service.closeWindow(), completes);
    });
  });

  group('DesktopMenuService on non-macOS platforms', () {
    setUp(() {
      service = DesktopMenuService(isSupported: () => false);
    });

    tearDown(() async {
      await service.dispose();
    });

    test('no-ops all outgoing calls when unsupported', () async {
      await service.updateMenuState(
        const DesktopMenuState(
          items: {
            DesktopMenuAction.openSettings: DesktopMenuItemState(enabled: true),
          },
        ),
      );
      await service.setWindowTitle('Ignored');
      await service.setDockBadge('5');
      await service.closeWindow();

      expect(outgoingCalls, isEmpty);
    });
  });

  group('DesktopMenuService default platform check', () {
    test('respects debugDefaultTargetPlatformOverride', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final iosService = DesktopMenuService();
      expect(iosService.isSupported, isFalse);
      await iosService.setWindowTitle('iOS');
      expect(outgoingCalls, isEmpty);
      await iosService.dispose();

      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      final macService = DesktopMenuService();
      expect(macService.isSupported, isTrue);
      await macService.setWindowTitle('macOS');
      expect(outgoingCalls, hasLength(1));
      await macService.dispose();
    });
  });
}
