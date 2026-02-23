import 'dart:async';

import 'package:ccpocket/features/settings/state/settings_cubit.dart';
import 'package:ccpocket/features/settings/state/settings_state.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:ccpocket/services/fcm_service.dart';
import 'package:ccpocket/services/machine_manager_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeBridgeService extends BridgeService {
  final _connectionController =
      StreamController<BridgeConnectionState>.broadcast();
  final registerCalls =
      <({String token, String platform, String? locale, bool? privacyMode})>[];
  final unregisterCalls = <String>[];
  bool _connected = false;
  String? _fakeLastUrl;

  @override
  bool get isConnected => _connected;

  @override
  String? get lastUrl => _fakeLastUrl;

  @override
  Stream<BridgeConnectionState> get connectionStatus =>
      _connectionController.stream;

  void emitConnection(BridgeConnectionState state, {String? url}) {
    _connected = state == BridgeConnectionState.connected;
    if (url != null) _fakeLastUrl = url;
    _connectionController.add(state);
  }

  @override
  void registerPushToken({
    required String token,
    required String platform,
    String? locale,
    bool? privacyMode,
  }) {
    registerCalls.add((
      token: token,
      platform: platform,
      locale: locale,
      privacyMode: privacyMode,
    ));
  }

  @override
  void unregisterPushToken(String token) {
    unregisterCalls.add(token);
  }

  @override
  void dispose() {
    _connectionController.close();
    super.dispose();
  }
}

class FakeFcmService extends FcmService {
  FakeFcmService({
    required this.available,
    this.token,
    this.platformName = 'ios',
  });

  final bool available;
  String? token;
  final String platformName;
  final _tokenRefreshController = StreamController<String>.broadcast();

  @override
  bool get isAvailable => available;

  @override
  Stream<String> get onTokenRefresh => _tokenRefreshController.stream;

  @override
  String get platform => platformName;

  @override
  Future<bool> init() async => available;

  @override
  Future<String?> getToken() async => token;

  @override
  String? cacheToken(String nextToken) {
    final previous = token;
    token = nextToken;
    return previous;
  }

  void emitTokenRefresh(String nextToken) {
    _tokenRefreshController.add(nextToken);
  }

  Future<void> disposeFake() async {
    await _tokenRefreshController.close();
  }
}

Future<void> _flushAsync() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

const _testMachineId = 'machine-001';
const _testHost = '192.168.1.1';
const _testPort = 8765;
const _testUrl = 'ws://$_testHost:$_testPort';

/// Creates a MachineManagerService with one pre-loaded machine.
Future<MachineManagerService> _createMachineManager(
  SharedPreferences prefs,
) async {
  final secureStorage = FakeSecureStorage();
  final manager = MachineManagerService(prefs, secureStorage);
  return manager;
}

/// Fake FlutterSecureStorage that does nothing.
class FakeSecureStorage extends Fake implements FlutterSecureStorage {
  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {}

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => null;
}

void main() {
  group('SettingsCubit push sync', () {
    test('auto registers token on init when machine is enabled', () async {
      SharedPreferences.setMockInitialValues({
        'settings_fcm_machines': '["$_testMachineId"]',
        'machines_v2':
            '[{"id":"$_testMachineId","host":"$_testHost","port":$_testPort}]',
      });
      final prefs = await SharedPreferences.getInstance();
      final manager = await _createMachineManager(prefs);
      await manager.init();
      final bridge = FakeBridgeService()
        ..emitConnection(BridgeConnectionState.connected, url: _testUrl);
      final fcm = FakeFcmService(available: true, token: 'token-1');
      final cubit = SettingsCubit(
        prefs,
        bridgeService: bridge,
        machineManager: manager,
        fcmService: fcm,
      );

      await _flushAsync();

      expect(bridge.registerCalls.length, 1);
      expect(bridge.registerCalls.first.token, 'token-1');
      expect(bridge.registerCalls.first.platform, 'ios');
      expect(bridge.registerCalls.first.locale, isNotNull);
      expect(cubit.state.fcmAvailable, isTrue);
      expect(cubit.state.fcmStatusKey, FcmStatusKey.enabled);

      await cubit.close();
      await fcm.disposeFake();
      bridge.dispose();
    });

    test('toggle off unregisters active token', () async {
      SharedPreferences.setMockInitialValues({
        'machines_v2':
            '[{"id":"$_testMachineId","host":"$_testHost","port":$_testPort}]',
      });
      final prefs = await SharedPreferences.getInstance();
      final manager = await _createMachineManager(prefs);
      await manager.init();
      final bridge = FakeBridgeService()
        ..emitConnection(BridgeConnectionState.connected, url: _testUrl);
      final fcm = FakeFcmService(available: true, token: 'token-1');
      final cubit = SettingsCubit(
        prefs,
        bridgeService: bridge,
        machineManager: manager,
        fcmService: fcm,
      );

      await _flushAsync();
      await cubit.toggleFcm(true);

      expect(bridge.registerCalls.length, 1);
      expect(bridge.registerCalls.first.token, 'token-1');

      await cubit.toggleFcm(false);

      expect(bridge.unregisterCalls, ['token-1']);
      expect(cubit.state.fcmEnabled, isFalse);

      await cubit.close();
      await fcm.disposeFake();
      bridge.dispose();
    });

    test(
      'token refresh unregisters old token then re-registers new token',
      () async {
        SharedPreferences.setMockInitialValues({
          'settings_fcm_machines': '["$_testMachineId"]',
          'machines_v2':
              '[{"id":"$_testMachineId","host":"$_testHost","port":$_testPort}]',
        });
        final prefs = await SharedPreferences.getInstance();
        final manager = await _createMachineManager(prefs);
        await manager.init();
        final bridge = FakeBridgeService()
          ..emitConnection(BridgeConnectionState.connected, url: _testUrl);
        final fcm = FakeFcmService(available: true, token: 'old-token');
        final cubit = SettingsCubit(
          prefs,
          bridgeService: bridge,
          machineManager: manager,
          fcmService: fcm,
        );

        await _flushAsync();
        fcm.emitTokenRefresh('new-token');
        await _flushAsync();

        expect(bridge.unregisterCalls, ['old-token']);
        expect(bridge.registerCalls.length, 2);
        expect(bridge.registerCalls.first.token, 'old-token');
        expect(bridge.registerCalls.last.token, 'new-token');

        await cubit.close();
        await fcm.disposeFake();
        bridge.dispose();
      },
    );

    test('toggle is no-op when not connected (no activeMachineId)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final bridge = FakeBridgeService();
      final fcm = FakeFcmService(available: true, token: 'token-1');
      final cubit = SettingsCubit(
        prefs,
        bridgeService: bridge,
        fcmService: fcm,
      );

      await _flushAsync();
      await cubit.toggleFcm(true);

      // No activeMachineId → toggle should be a no-op
      expect(bridge.registerCalls, isEmpty);
      expect(cubit.state.fcmEnabled, isFalse);

      await cubit.close();
      await fcm.disposeFake();
      bridge.dispose();
    });

    test('legacy migration enables all existing machines', () async {
      SharedPreferences.setMockInitialValues({
        'settings_fcm_enabled': true,
        'machines_v2':
            '[{"id":"m1","host":"10.0.0.1","port":8765},{"id":"m2","host":"10.0.0.2","port":8765}]',
      });
      final prefs = await SharedPreferences.getInstance();
      final manager = await _createMachineManager(prefs);
      await manager.init();
      final bridge = FakeBridgeService();
      final fcm = FakeFcmService(available: true, token: 'token-1');
      final cubit = SettingsCubit(
        prefs,
        bridgeService: bridge,
        machineManager: manager,
        fcmService: fcm,
      );

      await _flushAsync();

      expect(cubit.state.fcmEnabledMachines, {'m1', 'm2'});
      // Legacy key should be removed
      expect(prefs.getBool('settings_fcm_enabled'), isNull);
      // Migrated data should be persisted
      expect(prefs.getString('settings_fcm_machines'), isNotNull);

      await cubit.close();
      await fcm.disposeFake();
      bridge.dispose();
    });
  });
}
