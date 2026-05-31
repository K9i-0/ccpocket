import 'dart:convert';
import 'dart:typed_data';

import 'package:ccpocket/models/machine.dart';
import 'package:ccpocket/services/machine_manager_service.dart';
import 'package:ccpocket/services/ssh_startup_service.dart';
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

class _ConnectionCall {
  final String host;
  final int port;
  final String username;
  final SshAuthType authType;
  final String? password;
  final String? privateKey;
  final SshJumpConfig? jump;

  const _ConnectionCall({
    required this.host,
    required this.port,
    required this.username,
    required this.authType,
    required this.password,
    required this.privateKey,
    required this.jump,
  });
}

class _RecordingConnectionGateway implements SshConnectionGateway {
  final calls = <_ConnectionCall>[];
  final clients = <_FakeRemoteClient>[];

  @override
  Future<SshConnectionHandle> connect({
    required String host,
    required int port,
    required String username,
    required SshAuthType authType,
    String? password,
    String? privateKey,
    SshJumpConfig? jump,
  }) async {
    calls.add(
      _ConnectionCall(
        host: host,
        port: port,
        username: username,
        authType: authType,
        password: password,
        privateKey: privateKey,
        jump: jump,
      ),
    );
    final client = _FakeRemoteClient();
    clients.add(client);
    return SshConnectionHandle(client);
  }
}

class _FakeRemoteClient implements SshRemoteClient {
  var closed = false;
  final commands = <String>[];

  @override
  Future<Uint8List> run(String command) async {
    commands.add(command);
    return utf8.encode('Connection successful');
  }

  @override
  Future<SshCommandResult> execute(String command) async {
    commands.add(command);
    return const SshCommandResult(exitCode: 0, output: 'ok');
  }

  @override
  void close() {
    closed = true;
  }
}

void main() {
  Future<MachineManagerService> createManager(
    Machine machine, {
    String? sshJumpPassword,
    String? sshJumpPrivateKey,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final manager = MachineManagerService(prefs, _FakeSecureStorage());
    await manager.addMachine(
      machine,
      sshPassword: machine.sshAuthType == SshAuthType.password ? 'pw' : null,
      sshPrivateKey: machine.sshAuthType == SshAuthType.privateKey
          ? 'private-key'
          : null,
      sshJumpPassword: sshJumpPassword,
      sshJumpPrivateKey: sshJumpPrivateKey,
    );
    return manager;
  }

  group('SshStartupService start preflight', () {
    test('checks npx before starting launchd service', () {
      final command = SshStartupService.startCommandForTest;

      expect(command, contains("/bin/zsh -li -c 'command -v npx"));
      expect(
        command,
        contains('npx is not available in the remote login shell'),
      );
      expect(command, contains('npx @ccpocket/bridge@latest setup'));
    });

    test('checks npx availability for the systemd service', () {
      final preflight = SshStartupService.startPreflightCommandForTest;

      expect(preflight, contains("grep -E '^ExecStart='"));
      expect(preflight, contains('/bin/bash -lc'));
      expect(
        preflight,
        contains(r'export PATH="$HOME/.local/bin:$HOME/bin:$PATH"'),
      );
      expect(preflight, contains(r'[ ! -x "$NPX_COMMAND" ]'));
      expect(preflight, contains('command -v npx'));
      expect(preflight, contains('exit 127'));
    });

    test('update preflight can fail before stop command runs', () {
      final command = SshStartupService.updateCommandForTest;
      final preflight = SshStartupService.startPreflightCommandForTest;
      final preflightIndex = command.indexOf('command -v npx');
      final stopIndex = command.indexOf('systemctl --user stop');

      expect(preflightIndex, isNonNegative);
      expect(stopIndex, isNonNegative);
      expect(preflightIndex, lessThan(stopIndex));
      expect(preflight, isNot(contains('bootout')));
      expect(preflight, isNot(contains('systemctl --user stop')));
    });
  });

  group('SshStartupService connection routing', () {
    test(
      'uses the direct SSH route when jump host is not configured',
      () async {
        final manager = await createManager(
          const Machine(
            id: 'm1',
            host: 'target.example.com',
            sshEnabled: true,
            sshUsername: 'target-user',
            sshPort: 2200,
          ),
        );
        final gateway = _RecordingConnectionGateway();
        final service = SshStartupService(manager, connectionGateway: gateway);

        final result = await service.testConnection('m1', password: 'pw');

        expect(result.success, isTrue);
        expect(gateway.calls, hasLength(1));
        expect(gateway.calls.single.host, 'target.example.com');
        expect(gateway.calls.single.port, 2200);
        expect(gateway.calls.single.username, 'target-user');
        expect(gateway.calls.single.password, 'pw');
        expect(gateway.calls.single.jump, isNull);
        expect(gateway.clients.single.closed, isTrue);
      },
    );

    test('passes jump host settings through the shared SSH route', () async {
      final manager = await createManager(
        const Machine(
          id: 'm2',
          host: 'target.internal',
          sshEnabled: true,
          sshUsername: 'target-user',
          sshPort: 22,
          sshJumpHost: 'jump.example.com',
          sshJumpPort: 2222,
          sshJumpUsername: 'jump-user',
        ),
      );
      final gateway = _RecordingConnectionGateway();
      final service = SshStartupService(manager, connectionGateway: gateway);

      final result = await service.testConnection('m2', password: 'pw');

      expect(result.success, isTrue);
      expect(gateway.calls, hasLength(1));
      final jump = gateway.calls.single.jump;
      expect(jump, isNotNull);
      expect(jump!.host, 'jump.example.com');
      expect(jump.port, 2222);
      expect(jump.username, 'jump-user');
      expect(jump.authType, SshAuthType.password);
      expect(jump.jumpPassword, 'pw');
      expect(gateway.clients.single.closed, isTrue);
    });

    test('passes separate jump host credentials when saved', () async {
      final manager = await createManager(
        const Machine(
          id: 'm5',
          host: 'target.internal',
          sshEnabled: true,
          sshUsername: 'target-user',
          sshJumpHost: 'jump.example.com',
          sshJumpUsername: 'jump-user',
          sshJumpAuthType: SshAuthType.password,
        ),
        sshJumpPassword: 'jump-pw',
      );
      final gateway = _RecordingConnectionGateway();
      final service = SshStartupService(manager, connectionGateway: gateway);

      final result = await service.testConnection('m5', password: 'target-pw');

      expect(result.success, isTrue);
      final jump = gateway.calls.single.jump;
      expect(jump, isNotNull);
      expect(jump!.authType, SshAuthType.password);
      expect(jump.jumpPassword, 'jump-pw');
    });

    test('start, stop, and update use the shared SSH route', () async {
      final manager = await createManager(
        const Machine(
          id: 'm3',
          host: 'target.internal',
          sshEnabled: true,
          sshUsername: 'target-user',
          sshJumpHost: 'jump.example.com',
          sshJumpUsername: 'jump-user',
        ),
      );
      final gateway = _RecordingConnectionGateway();
      final service = SshStartupService(manager, connectionGateway: gateway);

      expect(
        (await service.startBridgeServer('m3', password: 'pw')).success,
        isTrue,
      );
      expect(
        (await service.stopBridgeServer('m3', password: 'pw')).success,
        isTrue,
      );
      expect(
        (await service.updateBridgeServer('m3', password: 'pw')).success,
        isTrue,
      );

      expect(gateway.calls, hasLength(3));
      expect(gateway.calls.map((call) => call.jump?.host), [
        'jump.example.com',
        'jump.example.com',
        'jump.example.com',
      ]);
    });

    test('start, stop, and update use saved private key credentials', () async {
      final manager = await createManager(
        const Machine(
          id: 'm7',
          host: 'target.internal',
          sshEnabled: true,
          sshUsername: 'target-user',
          sshAuthType: SshAuthType.privateKey,
        ),
      );
      final gateway = _RecordingConnectionGateway();
      final service = SshStartupService(manager, connectionGateway: gateway);

      expect((await service.startBridgeServer('m7')).success, isTrue);
      expect((await service.stopBridgeServer('m7')).success, isTrue);
      expect((await service.updateBridgeServer('m7')).success, isTrue);

      expect(gateway.calls, hasLength(3));
      expect(
        gateway.calls.map((call) => call.authType),
        everyElement(SshAuthType.privateKey),
      );
      expect(gateway.calls.map((call) => call.password), everyElement(isNull));
      expect(
        gateway.calls.map((call) => call.privateKey),
        everyElement('private-key'),
      );
    });

    test(
      'passes target private key through jump host when credentials inherit',
      () async {
        final manager = await createManager(
          const Machine(
            id: 'm8',
            host: 'target.internal',
            sshEnabled: true,
            sshUsername: 'target-user',
            sshAuthType: SshAuthType.privateKey,
            sshJumpHost: 'jump.example.com',
            sshJumpUsername: 'jump-user',
          ),
        );
        final gateway = _RecordingConnectionGateway();
        final service = SshStartupService(manager, connectionGateway: gateway);

        final result = await service.startBridgeServer('m8');

        expect(result.success, isTrue);
        final jump = gateway.calls.single.jump;
        expect(jump, isNotNull);
        expect(jump!.authType, SshAuthType.privateKey);
        expect(jump.jumpPassword, isNull);
        expect(jump.jumpPrivateKey, 'private-key');
      },
    );

    test(
      'inline credential test fails before opening SSH when password missing',
      () async {
        final manager = await createManager(
          const Machine(
            id: 'm4',
            host: 'target.example.com',
            sshEnabled: true,
            sshUsername: 'target-user',
          ),
        );
        final gateway = _RecordingConnectionGateway();
        final service = SshStartupService(manager, connectionGateway: gateway);

        final result = await service.testConnectionWithCredentials(
          host: 'target.example.com',
          sshPort: 22,
          username: 'target-user',
          authType: SshAuthType.password,
        );

        expect(result.success, isFalse);
        expect(result.error, 'Password required');
        expect(gateway.calls, isEmpty);
      },
    );

    test('inline credential test passes separate jump password', () async {
      final manager = await createManager(
        const Machine(
          id: 'm6',
          host: 'target.example.com',
          sshEnabled: true,
          sshUsername: 'target-user',
        ),
      );
      final gateway = _RecordingConnectionGateway();
      final service = SshStartupService(manager, connectionGateway: gateway);

      final result = await service.testConnectionWithCredentials(
        host: 'target.example.com',
        sshPort: 22,
        username: 'target-user',
        authType: SshAuthType.password,
        password: 'target-pw',
        jumpHost: 'jump.example.com',
        jumpUsername: 'jump-user',
        jumpAuthType: SshAuthType.password,
        jumpPassword: 'jump-pw',
      );

      expect(result.success, isTrue);
      final jump = gateway.calls.single.jump;
      expect(jump, isNotNull);
      expect(jump!.username, 'jump-user');
      expect(jump.jumpPassword, 'jump-pw');
    });

    test('inline credential test passes separate jump private key', () async {
      final manager = await createManager(
        const Machine(
          id: 'm9',
          host: 'target.example.com',
          sshEnabled: true,
          sshUsername: 'target-user',
        ),
      );
      final gateway = _RecordingConnectionGateway();
      final service = SshStartupService(manager, connectionGateway: gateway);

      final result = await service.testConnectionWithCredentials(
        host: 'target.example.com',
        sshPort: 22,
        username: 'target-user',
        authType: SshAuthType.privateKey,
        privateKey: 'target-key',
        jumpHost: 'jump.example.com',
        jumpUsername: 'jump-user',
        jumpAuthType: SshAuthType.privateKey,
        jumpPrivateKey: 'jump-key',
      );

      expect(result.success, isTrue);
      final call = gateway.calls.single;
      expect(call.password, isNull);
      expect(call.privateKey, 'target-key');
      final jump = call.jump;
      expect(jump, isNotNull);
      expect(jump!.username, 'jump-user');
      expect(jump.authType, SshAuthType.privateKey);
      expect(jump.jumpPassword, isNull);
      expect(jump.jumpPrivateKey, 'jump-key');
    });
  });
}
