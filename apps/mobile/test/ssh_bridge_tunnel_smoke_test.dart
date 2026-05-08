import 'dart:convert';
import 'dart:io';

import 'package:ccpocket/models/machine.dart';
import 'package:ccpocket/services/machine_manager_service.dart';
import 'package:ccpocket/services/ssh_bridge_tunnel_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

void _printSshDebugOnFailure(String? message) {
  if (message != null) {
    printOnFailure(message);
  }
}

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

Future<http.Response> _getWithRetry(Uri uri) async {
  Object? lastError;
  for (var attempt = 0; attempt < 10; attempt++) {
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) return response;
      lastError = 'HTTP ${response.statusCode}: ${response.body}';
    } catch (error) {
      lastError = error;
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  throw StateError('Failed to reach $uri: $lastError');
}

void main() {
  final enabled =
      Platform.environment['CCPOCKET_SSH_BRIDGE_TUNNEL_SMOKE'] == '1';

  group(
    'SSH Bridge tunnel smoke',
    skip: enabled ? null : 'smoke env not set',
    () {
      test(
        'target bridge is unreachable directly but reachable through jump tunnel',
        () async {
          final targetHost =
              Platform.environment['CCPOCKET_BRIDGE_TARGET_HOST'] ??
              'target-sshd';
          final targetPort = int.parse(
            Platform.environment['CCPOCKET_BRIDGE_TARGET_PORT'] ?? '8765',
          );
          final jumpHost =
              Platform.environment['CCPOCKET_SSH_JUMP_HOST'] ?? '127.0.0.1';
          final jumpPort = int.parse(
            Platform.environment['CCPOCKET_SSH_JUMP_PORT'] ?? '22220',
          );
          final username =
              Platform.environment['CCPOCKET_SSH_USERNAME'] ?? 'ccpocket';
          final password =
              Platform.environment['CCPOCKET_SSH_PASSWORD'] ?? 'ccpocket';

          await expectLater(
            http
                .get(Uri.parse('http://$targetHost:$targetPort/health'))
                .timeout(const Duration(seconds: 2)),
            throwsA(anything),
          );

          SharedPreferences.setMockInitialValues({});
          final prefs = await SharedPreferences.getInstance();
          final manager = MachineManagerService(prefs, _FakeSecureStorage());
          final tunnelService = SshBridgeTunnelService(
            manager,
            connectionTimeout: const Duration(seconds: 5),
            debugLog: _printSshDebugOnFailure,
          );
          addTearDown(tunnelService.closeAll);
          manager.configureBridgeTunnelResolvers(
            wsUrlResolver: tunnelService.buildWsUrl,
            httpBaseUrlResolver: tunnelService.buildHttpBaseUrl,
          );

          await manager.addMachine(
            Machine(
              id: 'm1',
              host: targetHost,
              port: targetPort,
              sshEnabled: true,
              sshUsername: username,
              sshJumpHost: jumpHost,
              sshJumpPort: jumpPort,
            ),
            sshPassword: password,
          );

          expect(await manager.checkHealth('m1'), MachineStatus.online);

          final wsUrl = await manager.buildWsUrl('m1');
          expect(wsUrl, startsWith('ws://127.0.0.1:'));
          final httpBaseUrl = wsUrl.replaceFirst('ws://', 'http://');

          final health = await _getWithRetry(Uri.parse('$httpBaseUrl/health'));
          expect(health.body, 'ok');

          final version = await _getWithRetry(
            Uri.parse('$httpBaseUrl/version'),
          );
          expect(
            jsonDecode(version.body),
            containsPair('version', '0.0.0-smoke'),
          );

          final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
          addTearDown(channel.sink.close);

          await channel.ready.timeout(const Duration(seconds: 5));
          final message = await channel.stream.first.timeout(
            const Duration(seconds: 5),
          );
          expect(
            jsonDecode(message as String),
            containsPair('type', 'bridge_smoke'),
          );
        },
      );
    },
  );
}
