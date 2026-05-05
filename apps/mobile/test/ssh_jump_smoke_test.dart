import 'dart:convert';
import 'dart:io';

import 'package:ccpocket/models/machine.dart';
import 'package:ccpocket/services/ssh_startup_service.dart';
import 'package:flutter_test/flutter_test.dart';

void _printSshDebugOnFailure(String? message) {
  if (message != null) {
    printOnFailure(message);
  }
}

void main() {
  final enabled = Platform.environment['CCPOCKET_SSH_JUMP_SMOKE'] == '1';

  group('SSH jump host smoke', skip: enabled ? null : 'smoke env not set', () {
    test('direct target connection fails but jump route succeeds', () async {
      final targetHost =
          Platform.environment['CCPOCKET_SSH_TARGET_HOST'] ?? 'target-sshd';
      final targetPort = int.parse(
        Platform.environment['CCPOCKET_SSH_TARGET_PORT'] ?? '22',
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
      const gateway = DartSshConnectionGateway(
        connectionTimeout: Duration(seconds: 5),
        debugLog: _printSshDebugOnFailure,
      );

      await expectLater(
        gateway.connect(
          host: targetHost,
          port: targetPort,
          username: username,
          authType: SshAuthType.password,
          password: password,
        ),
        throwsA(anything),
      );

      final connection = await gateway.connect(
        host: targetHost,
        port: targetPort,
        username: username,
        authType: SshAuthType.password,
        password: password,
        jump: SshJumpConfig(host: jumpHost, port: jumpPort, username: username),
      );

      try {
        final output = utf8.decode(
          await connection.client.run('echo "Connection successful"'),
        );
        expect(output, contains('Connection successful'));
      } finally {
        connection.close();
      }
    });
  });
}
