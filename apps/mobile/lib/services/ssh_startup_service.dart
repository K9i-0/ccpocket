import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';

import '../constants/app_constants.dart';
import '../models/machine.dart';
import 'machine_manager_service.dart';

/// Result of an SSH operation
class SshResult {
  final bool success;
  final String? output;
  final String? error;

  const SshResult({required this.success, this.output, this.error});

  factory SshResult.success([String? output]) =>
      SshResult(success: true, output: output);

  factory SshResult.failure(String error) =>
      SshResult(success: false, error: error);
}

/// Handles SSH connections and remote Bridge Server startup.
class SshStartupService {
  final MachineManagerService _machineManager;

  /// Timeout for SSH connection
  static const _connectionTimeout = Duration(seconds: 10);

  /// Timeout for command execution
  static const _commandTimeout = Duration(seconds: 30);

  /// launchctl commands for Bridge Server
  static const _startCommand = 'launchctl start com.ccpocket.bridge';
  static const _stopCommand = 'launchctl stop com.ccpocket.bridge';

  SshStartupService(this._machineManager);

  /// Start Bridge Server on a remote machine.
  ///
  /// If [promptForPassword] is provided, it will be called when password is needed
  /// but not saved (returns the password to use).
  Future<SshResult> startBridgeServer(
    String machineId, {
    String? password,
    Future<String?> Function()? promptForPassword,
  }) async {
    final machine = _machineManager.getMachine(machineId);
    if (machine == null) {
      return SshResult.failure('Machine not found');
    }

    if (!machine.canStartRemotely) {
      return SshResult.failure('SSH not configured for this machine');
    }

    // Get credentials
    var sshPassword = password;
    String? sshPrivateKey;

    if (machine.sshAuthType == SshAuthType.password) {
      sshPassword ??= await _machineManager.getSshPassword(machineId);
      if (sshPassword == null || sshPassword.isEmpty) {
        if (promptForPassword != null) {
          sshPassword = await promptForPassword();
        }
        if (sshPassword == null || sshPassword.isEmpty) {
          return SshResult.failure('Password required');
        }
      }
    } else {
      sshPrivateKey = await _machineManager.getSshPrivateKey(machineId);
      if (sshPrivateKey == null || sshPrivateKey.isEmpty) {
        return SshResult.failure('Private key required');
      }
    }

    try {
      final result = await _executeCommand(
        machine,
        _startCommand,
        password: sshPassword,
        privateKey: sshPrivateKey,
        background: true,
      );
      return result;
    } catch (e) {
      return SshResult.failure(e.toString());
    }
  }

  /// Stop Bridge Server on a remote machine.
  Future<SshResult> stopBridgeServer(
    String machineId, {
    String? password,
  }) async {
    final machine = _machineManager.getMachine(machineId);
    if (machine == null) {
      return SshResult.failure('Machine not found');
    }

    if (!machine.canStartRemotely) {
      return SshResult.failure('SSH not configured for this machine');
    }

    // Get credentials
    var sshPassword = password;
    String? sshPrivateKey;

    if (machine.sshAuthType == SshAuthType.password) {
      sshPassword ??= await _machineManager.getSshPassword(machineId);
    } else {
      sshPrivateKey = await _machineManager.getSshPrivateKey(machineId);
    }

    try {
      return await _executeCommand(
        machine,
        _stopCommand,
        password: sshPassword,
        privateKey: sshPrivateKey,
        background: true,
      );
    } catch (e) {
      return SshResult.failure(e.toString());
    }
  }

  /// Test SSH connection without running commands.
  Future<SshResult> testConnection(
    String machineId, {
    String? password,
    String? privateKey,
  }) async {
    final machine = _machineManager.getMachine(machineId);
    if (machine == null) {
      return SshResult.failure('Machine not found');
    }

    if (machine.sshUsername == null) {
      return SshResult.failure('SSH username not configured');
    }

    try {
      final socket = await SSHSocket.connect(
        machine.host,
        machine.sshPort,
        timeout: _connectionTimeout,
      );

      final client = await _authenticate(
        socket,
        machine,
        password: password,
        privateKey: privateKey,
      );

      // Run a simple command to verify connection
      final result = await client.run('echo "Connection successful"');
      client.close();

      final output = utf8.decode(result);
      if (output.contains('Connection successful')) {
        return SshResult.success('SSH connection test passed');
      } else {
        return SshResult.failure('Unexpected response: $output');
      }
    } on SSHAuthFailError {
      return SshResult.failure('Authentication failed');
    } on SSHAuthAbortError {
      return SshResult.failure('Authentication aborted');
    } on TimeoutException {
      return SshResult.failure('Connection timeout');
    } catch (e) {
      return SshResult.failure('Connection failed: $e');
    }
  }

  /// Test SSH connection with inline credentials (for add/edit dialog)
  Future<SshResult> testConnectionWithCredentials({
    required String host,
    required int sshPort,
    required String username,
    required SshAuthType authType,
    String? password,
    String? privateKey,
  }) async {
    try {
      final socket = await SSHSocket.connect(
        host,
        sshPort,
        timeout: _connectionTimeout,
      );

      final SSHClient client;
      if (authType == SshAuthType.password) {
        if (password == null || password.isEmpty) {
          socket.close();
          return SshResult.failure('Password required');
        }
        client = SSHClient(
          socket,
          username: username,
          onPasswordRequest: () => password,
        );
      } else {
        if (privateKey == null || privateKey.isEmpty) {
          socket.close();
          return SshResult.failure('Private key required');
        }
        client = SSHClient(
          socket,
          username: username,
          identities: [...SSHKeyPair.fromPem(privateKey)],
        );
      }

      // Run a simple command to verify connection
      final result = await client.run('echo "Connection successful"');
      client.close();

      final output = utf8.decode(result);
      if (output.contains('Connection successful')) {
        return SshResult.success('SSH connection test passed');
      } else {
        return SshResult.failure('Unexpected response: $output');
      }
    } on SSHAuthFailError {
      return SshResult.failure('Authentication failed');
    } on SSHAuthAbortError {
      return SshResult.failure('Authentication aborted');
    } on TimeoutException {
      return SshResult.failure('Connection timeout');
    } catch (e) {
      return SshResult.failure('Connection failed: $e');
    }
  }

  /// Update Bridge Server on a remote machine via SSH.
  ///
  /// Steps:
  /// 1. cd to project directory
  /// 2. git pull
  /// 3. npm run bridge:build
  /// 4. launchctl stop/start (restart)
  Future<SshResult> updateBridgeServer(
    String machineId, {
    String? password,
    Future<String?> Function()? promptForPassword,
  }) async {
    final machine = _machineManager.getMachine(machineId);
    if (machine == null) {
      return SshResult.failure('Machine not found');
    }

    if (!machine.canStartRemotely) {
      return SshResult.failure('SSH not configured for this machine');
    }

    // Get credentials
    var sshPassword = password;
    String? sshPrivateKey;

    if (machine.sshAuthType == SshAuthType.password) {
      sshPassword ??= await _machineManager.getSshPassword(machineId);
      if (sshPassword == null || sshPassword.isEmpty) {
        if (promptForPassword != null) {
          sshPassword = await promptForPassword();
        }
        if (sshPassword == null || sshPassword.isEmpty) {
          return SshResult.failure('Password required');
        }
      }
    } else {
      sshPrivateKey = await _machineManager.getSshPrivateKey(machineId);
      if (sshPrivateKey == null || sshPrivateKey.isEmpty) {
        return SshResult.failure('Private key required');
      }
    }

    // Build update command
    final updateCommand =
        '''
cd ${AppConstants.defaultProjectPath} && \\
git pull && \\
npm run bridge:build && \\
launchctl stop com.ccpocket.bridge && \\
sleep 1 && \\
launchctl start com.ccpocket.bridge
''';

    try {
      return await _executeCommand(
        machine,
        updateCommand,
        password: sshPassword,
        privateKey: sshPrivateKey,
      );
    } catch (e) {
      return SshResult.failure(e.toString());
    }
  }

  /// Execute a command on the remote machine.
  ///
  /// If [background] is true, the command is started and we return immediately
  /// without waiting for completion (used for launchctl start/stop).
  Future<SshResult> _executeCommand(
    Machine machine,
    String command, {
    String? password,
    String? privateKey,
    bool background = false,
  }) async {
    try {
      final socket = await SSHSocket.connect(
        machine.host,
        machine.sshPort,
        timeout: _connectionTimeout,
      );

      final client = await _authenticate(
        socket,
        machine,
        password: password,
        privateKey: privateKey,
      );

      try {
        if (background) {
          // Execute in background and return immediately
          final session = await client.execute(command);
          // Don't wait for exit, just give it a moment to start
          await Future.delayed(const Duration(milliseconds: 500));
          session.close();
          client.close();
          return SshResult.success('Command started');
        }

        // For other commands, wait for completion
        final result = await client.run(command).timeout(_commandTimeout);

        client.close();

        final output = utf8.decode(result);
        return SshResult.success(output);
      } finally {
        client.close();
      }
    } on SSHAuthFailError {
      return SshResult.failure('Authentication failed');
    } on SSHAuthAbortError {
      return SshResult.failure('Authentication aborted');
    } on TimeoutException {
      return SshResult.failure('Command timeout');
    } catch (e) {
      return SshResult.failure('SSH error: $e');
    }
  }

  /// Authenticate SSH connection
  Future<SSHClient> _authenticate(
    SSHSocket socket,
    Machine machine, {
    String? password,
    String? privateKey,
  }) async {
    if (machine.sshAuthType == SshAuthType.password) {
      if (password == null || password.isEmpty) {
        throw SSHAuthAbortError('Password required');
      }
      return SSHClient(
        socket,
        username: machine.sshUsername!,
        onPasswordRequest: () => password,
      );
    } else {
      if (privateKey == null || privateKey.isEmpty) {
        throw SSHAuthAbortError('Private key required');
      }
      return SSHClient(
        socket,
        username: machine.sshUsername!,
        identities: [...SSHKeyPair.fromPem(privateKey)],
      );
    }
  }
}
