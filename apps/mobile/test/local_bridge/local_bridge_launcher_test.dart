import 'package:ccpocket/features/local_bridge/data/local_bridge_launcher.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ccpocket/local_bridge_helper');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'sends one helper request at a time and reads its permissions',
    () async {
      // The helper reads a single request file: a second request sent before
      // the first is answered would leave the first without an answer.
      var running = 0;
      var overlapped = false;
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        final action = (call.arguments as Map)['action'] as String;
        calls.add(action);
        overlapped |= ++running > 1;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        running--;
        return {
          'ok': true,
          'status': 'enabled',
          'permissions': {'fullDiskAccess': false, 'screenCapture': true},
        };
      });

      const launcher = HelperLocalBridgeLauncher();
      final results = await Future.wait([
        launcher.run('status'),
        launcher.run('requestScreenCapture'),
        const HelperLocalBridgeLauncher().run('status'),
      ]);

      expect(overlapped, isFalse);
      expect(calls, ['status', 'requestScreenCapture', 'status']);
      expect(results.first.registration, LauncherRegistration.enabled);
      expect(
        results.first.permissions,
        const LauncherPermissions(fullDiskAccess: false, screenCapture: true),
      );
    },
  );

  test('opens the System Settings page of a permission', () async {
    final panes = <Object?>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      panes.add((call.arguments as Map)['pane']);
      return true;
    });
    expect(
      await const HelperLocalBridgeLauncher().openSystemSettings(
        BridgePermission.fullDiskAccess,
      ),
      isTrue,
    );
    expect(panes, ['fullDiskAccess']);
  });
}
