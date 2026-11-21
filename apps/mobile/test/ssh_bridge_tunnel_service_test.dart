import 'package:ccpocket/models/machine.dart';
import 'package:ccpocket/services/machine_manager_service.dart';
import 'package:ccpocket/services/ssh_bridge_tunnel_service.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _EmptySecureStorage implements FlutterSecureStorage {
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

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('SshBridgeTunnelService', () {
    // No SSH password is stored, so every start stops at credential
    // resolution and never opens a network connection.
    const machine = Machine(
      id: 'm1',
      host: 'bridge.internal',
      port: 8765,
      sshEnabled: true,
      sshUsername: 'user',
      sshJumpHost: 'jump.internal',
    );

    late SshBridgeTunnelService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      service = SshBridgeTunnelService(
        MachineManagerService(prefs, _EmptySecureStorage()),
      );
    });

    tearDown(() => service.closeAll());

    test('a caller with a password prompt is still asked when it joins a '
        'start that had no credentials', () async {
      // A health check starts the tunnel without any way to ask for the
      // password; a connect that overlaps it must still get its prompt.
      final healthCheck = service.buildHttpBaseUrl(machine);
      var prompts = 0;
      final connect = service.buildWsUrl(
        machine,
        promptForPassword: () async {
          prompts++;
          return null;
        },
      );

      await expectLater(healthCheck, throwsA(isA<SSHAuthAbortError>()));
      await expectLater(connect, throwsA(isA<SSHAuthAbortError>()));
      expect(prompts, 1);
    });

    test(
      'callers without credentials share the failure of one start',
      () async {
        final first = service.buildHttpBaseUrl(machine);
        final second = service.buildHttpBaseUrl(machine);

        await expectLater(first, throwsA(isA<SSHAuthAbortError>()));
        await expectLater(second, throwsA(isA<SSHAuthAbortError>()));
      },
    );
  });
}
