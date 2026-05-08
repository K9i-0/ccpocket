import 'dart:convert';
import 'dart:io';

import 'package:ccpocket/models/machine.dart';
import 'package:ccpocket/services/ssh_startup_service.dart';
import 'package:flutter_test/flutter_test.dart';

String _privateKey() {
  final inline = Platform.environment['CCPOCKET_SSH_PRIVATE_KEY'];
  if (inline != null && inline.isNotEmpty) {
    return inline.replaceAll(r'\n', '\n');
  }

  final file =
      Platform.environment['CCPOCKET_SSH_PRIVATE_KEY_FILE'] ??
      '../../tools/ssh-jump-smoke/generated/id_ed25519';
  return File(file).readAsStringSync();
}

void _printSshDebugOnFailure(String? message) {
  if (message != null) {
    printOnFailure(message);
  }
}

void main() {
  final enabled = Platform.environment['CCPOCKET_SSH_PRIVATE_KEY_SMOKE'] == '1';

  group(
    'SSH private key smoke',
    skip: enabled ? null : 'smoke env not set',
    () {
      test('connects to docker sshd with private key auth', () async {
        final host =
            Platform.environment['CCPOCKET_SSH_KEY_HOST'] ?? '127.0.0.1';
        final port = int.parse(
          Platform.environment['CCPOCKET_SSH_KEY_PORT'] ?? '22220',
        );
        final username =
            Platform.environment['CCPOCKET_SSH_USERNAME'] ?? 'ccpocket';
        final privateKey = _privateKey();
        const gateway = DartSshConnectionGateway(
          connectionTimeout: Duration(seconds: 5),
          debugLog: _printSshDebugOnFailure,
        );

        final connection = await gateway.connect(
          host: host,
          port: port,
          username: username,
          authType: SshAuthType.privateKey,
          privateKey: privateKey,
        );

        try {
          final output = utf8.decode(
            await connection.client.run('echo "Private key successful"'),
          );
          expect(output, contains('Private key successful'));
        } finally {
          connection.close();
        }
      });

      test(
        'connects to target through jump host with inherited private key',
        () async {
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
          final privateKey = _privateKey();
          const gateway = DartSshConnectionGateway(
            connectionTimeout: Duration(seconds: 5),
            debugLog: _printSshDebugOnFailure,
          );

          final connection = await gateway.connect(
            host: targetHost,
            port: targetPort,
            username: username,
            authType: SshAuthType.privateKey,
            privateKey: privateKey,
            jump: SshJumpConfig(
              host: jumpHost,
              port: jumpPort,
              username: username,
              authType: SshAuthType.privateKey,
              jumpPrivateKey: privateKey,
            ),
          );

          try {
            final output = utf8.decode(
              await connection.client.run('echo "Private key jump successful"'),
            );
            expect(output, contains('Private key jump successful'));
          } finally {
            connection.close();
          }
        },
      );
    },
  );
}
