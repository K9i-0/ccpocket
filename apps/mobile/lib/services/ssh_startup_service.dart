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

  /// Setup launchd on a remote machine via SSH.
  ///
  /// Creates the plist file and registers it with launchctl.
  /// This is a one-time setup that enables start/stop via launchctl.
  Future<SshResult> setupLaunchd(
    String machineId, {
    String? password,
    Future<String?> Function()? promptForPassword,
    required String projectPath,
    String? apiKey,
    int bridgePort = 8765,
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

    // Build the setup script
    final setupScript = _buildSetupScript(
      projectPath: projectPath,
      bridgePort: bridgePort,
      apiKey: apiKey,
    );

    try {
      return await _executeCommand(
        machine,
        setupScript,
        password: sshPassword,
        privateKey: sshPrivateKey,
      );
    } catch (e) {
      return SshResult.failure(e.toString());
    }
  }

  /// Build the shell script for launchd setup.
  ///
  /// Kept as a separate method to avoid Dart string interpolation issues
  /// with shell variable syntax.
  static String _buildSetupScript({
    required String projectPath,
    required int bridgePort,
    String? apiKey,
  }) {
    // Build environment entries for plist
    final envLines = StringBuffer();
    envLines.writeln('        <key>BRIDGE_PORT</key>');
    envLines.writeln('        <string>$bridgePort</string>');
    envLines.writeln('        <key>BRIDGE_HOST</key>');
    envLines.writeln('        <string>0.0.0.0</string>');
    if (apiKey != null && apiKey.isNotEmpty) {
      envLines.writeln('        <key>BRIDGE_API_KEY</key>');
      envLines.writeln('        <string>$apiKey</string>');
    }
    final envBlock = envLines.toString().trimRight();

    // Expand ~ to \$HOME for the shell
    final expandedPath = projectPath.startsWith('~/')
        ? '\$HOME${projectPath.substring(1)}'
        : projectPath;

    return [
      'set -e',
      '',
      '# Detect node path',
      'NODE_PATH=\$(which node || true)',
      'if [ -z "\$NODE_PATH" ]; then',
      '  for p in /usr/local/bin/node /opt/homebrew/bin/node; do',
      '    if [ -x "\$p" ]; then NODE_PATH="\$p"; break; fi',
      '  done',
      'fi',
      'if [ -z "\$NODE_PATH" ]; then',
      '  echo "ERROR: node not found"',
      '  exit 1',
      'fi',
      'NODE_DIR=\$(dirname "\$NODE_PATH")',
      '',
      '# Project path',
      'PROJECT_PATH="$expandedPath"',
      '',
      '# Build if dist does not exist',
      'if [ ! -d "\$PROJECT_PATH/packages/bridge/dist" ]; then',
      '  cd "\$PROJECT_PATH" && npm run bridge:build',
      'fi',
      '',
      '# Generate plist',
      "cat > ~/Library/LaunchAgents/com.ccpocket.bridge.plist << 'PLIST_EOF'",
      '<?xml version="1.0" encoding="UTF-8"?>',
      '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">',
      '<plist version="1.0">',
      '<dict>',
      '    <key>Label</key>',
      '    <string>com.ccpocket.bridge</string>',
      '    <key>ProgramArguments</key>',
      '    <array>',
      '        <string>PLACEHOLDER_NODE</string>',
      '        <string>PLACEHOLDER_DIST</string>',
      '    </array>',
      '    <key>EnvironmentVariables</key>',
      '    <dict>',
      '        <key>PATH</key>',
      '        <string>PLACEHOLDER_PATH</string>',
      envBlock,
      '    </dict>',
      '    <key>RunAtLoad</key>',
      '    <false/>',
      '    <key>KeepAlive</key>',
      '    <false/>',
      '    <key>StandardOutPath</key>',
      '    <string>/tmp/ccpocket-bridge.log</string>',
      '    <key>StandardErrorPath</key>',
      '    <string>/tmp/ccpocket-bridge.err</string>',
      '</dict>',
      '</plist>',
      'PLIST_EOF',
      '',
      '# Replace placeholders with actual paths',
      r"""sed -i '' "s|PLACEHOLDER_NODE|$NODE_PATH|g" ~/Library/LaunchAgents/com.ccpocket.bridge.plist""",
      r"""sed -i '' "s|PLACEHOLDER_DIST|$PROJECT_PATH/packages/bridge/dist/index.js|g" ~/Library/LaunchAgents/com.ccpocket.bridge.plist""",
      r"""sed -i '' "s|PLACEHOLDER_PATH|$NODE_DIR:/usr/bin:/bin:/usr/sbin:/sbin|g" ~/Library/LaunchAgents/com.ccpocket.bridge.plist""",
      '',
      '# Register with launchctl',
      'launchctl unload ~/Library/LaunchAgents/com.ccpocket.bridge.plist 2>/dev/null || true',
      'launchctl load ~/Library/LaunchAgents/com.ccpocket.bridge.plist',
      '',
      'echo "Setup complete. Bridge Server registered with launchd."',
    ].join('\n');
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
