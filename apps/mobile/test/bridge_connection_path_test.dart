import 'dart:convert';
import 'dart:io';

import 'package:ccpocket/models/machine.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:ccpocket/services/machine_manager_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSecureStorage implements FlutterSecureStorage {
  final Map<String, String> values = {};

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
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return values[key];
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Bridge connection path handling', () {
    test('BridgeService.checkHealth preserves websocket path prefix', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));

      server.listen((request) async {
        if (request.uri.path == '/bridge/health') {
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({'status': 'ok'}));
        } else {
          request.response
            ..statusCode = 404
            ..write('Not Found');
        }
        await request.response.close();
      });

      final health = await BridgeService.checkHealth(
        'ws://127.0.0.1:${server.port}/bridge',
      );

      expect(health, isNotNull);
      expect(health, containsPair('status', 'ok'));
    });

    test(
      'MachineManagerService preserves full websocket URL for reconnect',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));

        server.listen((request) async {
          if (request.uri.path == '/bridge/health') {
            request.response
              ..statusCode = 200
              ..headers.contentType = ContentType.json
              ..write(jsonEncode({'status': 'ok'}));
          } else if (request.uri.path == '/bridge/version') {
            request.response
              ..statusCode = 200
              ..headers.contentType = ContentType.json
              ..write(jsonEncode({'version': '1.0.0'}));
          } else {
            request.response
              ..statusCode = 404
              ..write('Not Found');
          }
          await request.response.close();
        });

        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final manager = MachineManagerService(prefs, _FakeSecureStorage());
        await manager.init();

        final machine = await manager.recordConnection(
          host: '127.0.0.1',
          port: server.port,
          useSsl: false,
          wsUrl: 'ws://127.0.0.1:${server.port}/bridge',
        );

        expect(
          await manager.buildWsUrl(machine.id),
          'ws://127.0.0.1:${server.port}/bridge',
        );
        expect(await manager.checkHealth(machine.id), MachineStatus.online);
      },
    );
  });
}
