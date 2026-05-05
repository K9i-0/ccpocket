import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';

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

class SshJumpConfig {
  final String host;
  final int port;
  final String? username;

  const SshJumpConfig({required this.host, required this.port, this.username});
}

class SshCommandResult {
  final int? exitCode;
  final String output;

  const SshCommandResult({required this.exitCode, required this.output});
}

abstract class SshRemoteClient {
  Future<Uint8List> run(String command);

  Future<SshCommandResult> execute(String command);

  void close();
}

class SshConnectionHandle {
  final SshRemoteClient client;
  final SshRemoteClient? jumpClient;

  const SshConnectionHandle(this.client, {this.jumpClient});

  void close() {
    client.close();
    jumpClient?.close();
  }
}

abstract class SshConnectionGateway {
  Future<SshConnectionHandle> connect({
    required String host,
    required int port,
    required String username,
    required SshAuthType authType,
    String? password,
    String? privateKey,
    SshJumpConfig? jump,
  });
}

class DartSshConnectionGateway implements SshConnectionGateway {
  final Duration connectionTimeout;
  final void Function(String?)? debugLog;

  const DartSshConnectionGateway({
    required this.connectionTimeout,
    this.debugLog,
  });

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
    final identities = _validateCredentials(authType, password, privateKey);
    if (jump == null) {
      final socket = await SSHSocket.connect(
        host,
        port,
        timeout: connectionTimeout,
      );
      final client = await _createReadyClient(
        socket,
        username: username,
        authType: authType,
        password: password,
        identities: identities,
      );
      return SshConnectionHandle(DartSshRemoteClient(client));
    }

    final jumpSocket = await SSHSocket.connect(
      jump.host,
      jump.port,
      timeout: connectionTimeout,
    );
    final jumpClient = _createClient(
      jumpSocket,
      username: jump.username ?? username,
      authType: authType,
      password: password,
      identities: identities,
    );

    try {
      final targetClient = await _connectTargetThroughJump(
        jumpClient,
        host: host,
        port: port,
        username: username,
        authType: authType,
        password: password,
        identities: identities,
      );
      return SshConnectionHandle(
        DartSshRemoteClient(targetClient),
        jumpClient: DartSshRemoteClient(jumpClient),
      );
    } catch (_) {
      jumpClient.close();
      rethrow;
    }
  }

  Future<SSHClient> _connectTargetThroughJump(
    SSHClient jumpClient, {
    required String host,
    required int port,
    required String username,
    required SshAuthType authType,
    String? password,
    List<SSHKeyPair>? identities,
  }) async {
    try {
      final targetSocket = await jumpClient
          .forwardLocal(host, port)
          .timeout(connectionTimeout);
      return await _createReadyClient(
        _BufferedSshSocket(targetSocket),
        username: username,
        authType: authType,
        password: password,
        identities: identities,
      );
    } on SSHError {
      final targetSocket = await _openNetcatSocket(
        jumpClient,
        host: host,
        port: port,
      ).timeout(connectionTimeout);
      return await _createReadyClient(
        targetSocket,
        username: username,
        authType: authType,
        password: password,
        identities: identities,
      );
    }
  }

  Future<SSHSocket> _openNetcatSocket(
    SSHClient jumpClient, {
    required String host,
    required int port,
  }) async {
    final session = await jumpClient.execute('nc ${_shellQuote(host)} $port');
    return _SshSessionSocket(session);
  }

  Future<SSHClient> _createReadyClient(
    SSHSocket socket, {
    required String username,
    required SshAuthType authType,
    String? password,
    List<SSHKeyPair>? identities,
  }) async {
    final client = _createClient(
      socket,
      username: username,
      authType: authType,
      password: password,
      identities: identities,
    );
    try {
      await client.ping().timeout(connectionTimeout);
      return client;
    } catch (_) {
      client.close();
      rethrow;
    }
  }

  SSHClient _createClient(
    SSHSocket socket, {
    required String username,
    required SshAuthType authType,
    String? password,
    List<SSHKeyPair>? identities,
  }) {
    if (authType == SshAuthType.password) {
      if (password == null || password.isEmpty) {
        throw SSHAuthAbortError('Password required');
      }
      return SSHClient(
        socket,
        username: username,
        onPasswordRequest: () => password,
        printDebug: debugLog,
      );
    }

    return SSHClient(
      socket,
      username: username,
      identities: identities!,
      printDebug: debugLog,
    );
  }

  List<SSHKeyPair>? _validateCredentials(
    SshAuthType authType,
    String? password,
    String? privateKey,
  ) {
    if (authType == SshAuthType.password) {
      if (password == null || password.isEmpty) {
        throw SSHAuthAbortError('Password required');
      }
      return null;
    }
    if (privateKey == null || privateKey.isEmpty) {
      throw SSHAuthAbortError('Private key required');
    }
    return SSHKeyPair.fromPem(privateKey);
  }

  String _shellQuote(String value) => "'${value.replaceAll("'", "'\"'\"'")}'";
}

class _BufferedSshSocket implements SSHSocket {
  final SSHSocket _delegate;
  final StreamController<Uint8List> _controller = StreamController();
  late final StreamSubscription<Uint8List> _subscription;

  _BufferedSshSocket(this._delegate) {
    _subscription = _delegate.stream.listen(
      _controller.add,
      onError: _controller.addError,
      onDone: _controller.close,
    );
  }

  @override
  Stream<Uint8List> get stream => _controller.stream;

  @override
  StreamSink<List<int>> get sink => _delegate.sink;

  @override
  Future<void> get done => _delegate.done;

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return _delegate.close();
  }

  @override
  void destroy() {
    unawaited(_subscription.cancel());
    _delegate.destroy();
  }
}

class _SshSessionSocket implements SSHSocket {
  final SSHSession _session;

  const _SshSessionSocket(this._session);

  @override
  Stream<Uint8List> get stream => _session.stdout;

  @override
  StreamSink<List<int>> get sink => _SshSessionSink(_session.stdin);

  @override
  Future<void> get done => _session.done;

  @override
  Future<void> close() {
    _session.close();
    return _session.done;
  }

  @override
  void destroy() {
    _session.close();
  }
}

class _SshSessionSink implements StreamSink<List<int>> {
  final StreamSink<Uint8List> _delegate;

  const _SshSessionSink(this._delegate);

  @override
  void add(List<int> data) {
    _delegate.add(Uint8List.fromList(data));
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    _delegate.addError(error, stackTrace);
  }

  @override
  Future<void> addStream(Stream<List<int>> stream) {
    return _delegate.addStream(
      stream.map((data) => data is Uint8List ? data : Uint8List.fromList(data)),
    );
  }

  @override
  Future<void> close() => _delegate.close();

  @override
  Future<void> get done => _delegate.done;
}

class DartSshRemoteClient implements SshRemoteClient {
  final SSHClient _client;

  const DartSshRemoteClient(this._client);

  @override
  Future<Uint8List> run(String command) => _client.run(command);

  @override
  Future<SshCommandResult> execute(String command) async {
    final session = await _client.execute(command);
    final output = BytesBuilder(copy: false);
    final stdoutDone = Completer<void>();
    final stderrDone = Completer<void>();

    session.stdout.listen(
      output.add,
      onDone: stdoutDone.complete,
      onError: stdoutDone.completeError,
    );
    session.stderr.listen(
      output.add,
      onDone: stderrDone.complete,
      onError: stderrDone.completeError,
    );

    await session.done;
    await stdoutDone.future;
    await stderrDone.future;

    return SshCommandResult(
      exitCode: session.exitCode,
      output: utf8.decode(output.takeBytes()),
    );
  }

  @override
  void close() {
    _client.close();
  }
}

/// Handles SSH connections and remote Bridge Server startup.
class SshStartupService {
  final MachineManagerService _machineManager;
  final SshConnectionGateway _connectionGateway;

  /// Timeout for SSH connection
  static const _connectionTimeout = Duration(seconds: 10);

  /// Timeout for command execution
  static const _commandTimeout = Duration(seconds: 30);

  /// Verify that the Bridge service can be started before touching it.
  ///
  /// The auto-start service runs Bridge through npx, so report PATH problems
  /// directly instead of waiting for a generic start timeout.
  ///
  /// macOS setup installs a launchd LaunchAgent, while Linux setup installs a
  /// systemd user service. Detect the remote init system at runtime because the
  /// mobile app only knows how to reach the machine over SSH.
  static const _startPreflightCommand = r'''
if command -v launchctl >/dev/null 2>&1; then
  LABEL=com.ccpocket.bridge
  PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
  if [ ! -f "$PLIST" ]; then
    echo "Bridge auto-start setup is required. Run: npx @ccpocket/bridge@latest setup" >&2
    exit 1
  fi
  if ! /bin/zsh -li -c 'command -v npx >/dev/null 2>&1'; then
    echo "npx is not available in the remote login shell. Bridge auto-start uses npx. Fix Node.js/npm PATH on the machine, then run: npx @ccpocket/bridge@latest setup" >&2
    exit 127
  fi
elif command -v systemctl >/dev/null 2>&1; then
  SERVICE="$HOME/.config/systemd/user/ccpocket-bridge.service"
  if [ ! -f "$SERVICE" ]; then
    echo "Bridge auto-start setup is required. Run: npx @ccpocket/bridge@latest setup" >&2
    exit 1
  fi
  EXEC_START=$(grep -E '^ExecStart=' "$SERVICE" | head -n 1 | sed 's/^ExecStart=//')
  NPX_COMMAND=${EXEC_START%% *}
  if [ -z "$NPX_COMMAND" ]; then
    echo "Bridge auto-start setup is invalid. Run: npx @ccpocket/bridge@latest setup" >&2
    exit 1
  fi
  if [ "${NPX_COMMAND#/}" != "$NPX_COMMAND" ]; then
    if [ ! -x "$NPX_COMMAND" ]; then
      echo "npx configured in the Bridge service is not executable: $NPX_COMMAND. Fix Node.js/npm PATH on the machine, then run: npx @ccpocket/bridge@latest setup" >&2
      exit 127
    fi
  elif ! command -v "$NPX_COMMAND" >/dev/null 2>&1; then
    echo "npx is not available in the remote SSH PATH. Bridge auto-start uses npx. Fix Node.js/npm PATH on the machine, then run: npx @ccpocket/bridge@latest setup" >&2
    exit 127
  fi
else
  echo "Neither launchctl nor systemctl is available" >&2
  exit 127
fi
''';

  /// Start the Bridge service installed by
  /// `npx @ccpocket/bridge@latest setup`.
  ///
  /// macOS setup installs a launchd LaunchAgent, while Linux setup installs a
  /// systemd user service. Detect the remote init system at runtime because the
  /// mobile app only knows how to reach the machine over SSH.
  static const _startServiceCommand = r'''
if command -v launchctl >/dev/null 2>&1; then
  LABEL=com.ccpocket.bridge
  UID_VALUE=$(id -u)
  PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
  if [ ! -f "$PLIST" ]; then
    echo "Bridge auto-start setup is required. Run: npx @ccpocket/bridge@latest setup" >&2
    exit 1
  fi
  MIGRATED=0
  if /usr/libexec/PlistBuddy -c "Print :ProgramArguments:3" "$PLIST" 2>/dev/null | grep -qx "exec npx @ccpocket/bridge@latest"; then
    /usr/libexec/PlistBuddy -c "Set :ProgramArguments:3 exec npx --yes @ccpocket/bridge@latest" "$PLIST"
    MIGRATED=1
  fi
  if [ "$MIGRATED" = "1" ]; then
    launchctl bootout "gui/$UID_VALUE/$LABEL" 2>/dev/null || true
    launchctl bootout "user/$UID_VALUE/$LABEL" 2>/dev/null || true
    launchctl unload "$PLIST" 2>/dev/null || true
  fi
  launchctl kickstart -k "gui/$UID_VALUE/$LABEL" 2>/dev/null || \
    launchctl kickstart -k "user/$UID_VALUE/$LABEL" 2>/dev/null || \
    (launchctl bootstrap "gui/$UID_VALUE" "$PLIST" 2>/dev/null || true; launchctl kickstart -k "gui/$UID_VALUE/$LABEL" 2>/dev/null) || \
    (launchctl bootstrap "user/$UID_VALUE" "$PLIST" 2>/dev/null || true; launchctl kickstart -k "user/$UID_VALUE/$LABEL" 2>/dev/null) || \
    (launchctl load -w "$PLIST" 2>/dev/null || true; launchctl start "$LABEL")
elif command -v systemctl >/dev/null 2>&1; then
  SERVICE="$HOME/.config/systemd/user/ccpocket-bridge.service"
  if [ ! -f "$SERVICE" ]; then
    echo "Bridge auto-start setup is required. Run: npx @ccpocket/bridge@latest setup" >&2
    exit 1
  fi
  if [ -f "$SERVICE" ] && grep -q "^ExecStart=.*npx @ccpocket/bridge@latest$" "$SERVICE"; then
    perl -0pi.bak -e 's#^ExecStart=(.*npx) \@ccpocket/bridge\@latest$#ExecStart=$1 --yes \@ccpocket/bridge\@latest#m' "$SERVICE"
    systemctl --user daemon-reload
  fi
  systemctl --user restart ccpocket-bridge
else
  echo "Neither launchctl nor systemctl is available" >&2
  exit 127
fi
''';

  @visibleForTesting
  static String get startCommandForTest => _startCommand;

  @visibleForTesting
  static const startPreflightCommandForTest = _startPreflightCommand;

  @visibleForTesting
  static String get updateCommandForTest => _updateCommand;

  static String get _startCommand =>
      '${_startPreflightCommand.trim()}\n\n$_startServiceCommand';

  /// Stop the Bridge service without removing the setup installed by npx.
  static const _stopCommand = r'''
if command -v launchctl >/dev/null 2>&1; then
  LABEL=com.ccpocket.bridge
  UID_VALUE=$(id -u)
  launchctl bootout "gui/$UID_VALUE/$LABEL" 2>/dev/null || \
    launchctl bootout "user/$UID_VALUE/$LABEL" 2>/dev/null || \
    launchctl unload "$HOME/Library/LaunchAgents/$LABEL.plist" 2>/dev/null || \
    launchctl stop "$LABEL"
elif command -v systemctl >/dev/null 2>&1; then
  systemctl --user stop ccpocket-bridge
else
  echo "Neither launchctl nor systemctl is available" >&2
  exit 127
fi
''';

  static String get _updateCommand =>
      '''
set -e
${_startPreflightCommand.trim()}
${_stopCommand.trim()} || true
sleep 1
${_startCommand.trim()}
''';

  SshStartupService(
    this._machineManager, {
    SshConnectionGateway? connectionGateway,
  }) : _connectionGateway =
           connectionGateway ??
           const DartSshConnectionGateway(
             connectionTimeout: _connectionTimeout,
           );

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
      final connection = await _connectMachine(
        machine,
        password: password,
        privateKey: privateKey,
      );

      try {
        // Run a simple command to verify connection
        final result = await connection.client.run(
          'echo "Connection successful"',
        );
        final output = utf8.decode(result);
        if (output.contains('Connection successful')) {
          return SshResult.success('SSH connection test passed');
        } else {
          return SshResult.failure('Unexpected response: $output');
        }
      } finally {
        connection.close();
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
    String? jumpHost,
    int jumpPort = 22,
    String? jumpUsername,
    String? password,
    String? privateKey,
  }) async {
    if (authType == SshAuthType.password &&
        (password == null || password.isEmpty)) {
      return SshResult.failure('Password required');
    }
    if (authType == SshAuthType.privateKey &&
        (privateKey == null || privateKey.isEmpty)) {
      return SshResult.failure('Private key required');
    }

    try {
      final connection = await _connectionGateway.connect(
        host: host,
        port: sshPort,
        username: username,
        authType: authType,
        password: password,
        privateKey: privateKey,
        jump: _inlineJumpConfig(
          host: jumpHost,
          port: jumpPort,
          username: jumpUsername,
        ),
      );

      try {
        // Run a simple command to verify connection
        final result = await connection.client.run(
          'echo "Connection successful"',
        );
        final output = utf8.decode(result);
        if (output.contains('Connection successful')) {
          return SshResult.success('SSH connection test passed');
        } else {
          return SshResult.failure('Unexpected response: $output');
        }
      } finally {
        connection.close();
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
  /// This only supports the auto-start service installed by
  /// `npx @ccpocket/bridge@latest setup`. Source checkouts are not
  /// updated from the app.
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

    try {
      return await _executeCommand(
        machine,
        _updateCommand,
        password: sshPassword,
        privateKey: sshPrivateKey,
      );
    } catch (e) {
      return SshResult.failure(e.toString());
    }
  }

  /// Execute a command on the remote machine.
  ///
  Future<SshResult> _executeCommand(
    Machine machine,
    String command, {
    String? password,
    String? privateKey,
  }) async {
    try {
      final connection = await _connectMachine(
        machine,
        password: password,
        privateKey: privateKey,
      );

      try {
        final result = await connection.client
            .execute(command)
            .timeout(_commandTimeout);

        final output = result.output.trim();
        if (result.exitCode == 0 || result.exitCode == null) {
          return SshResult.success(
            output.isEmpty ? 'Command completed' : output,
          );
        }

        return SshResult.failure(
          output.isEmpty
              ? 'Command failed with exit code ${result.exitCode}'
              : output,
        );
      } finally {
        connection.close();
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

  Future<SshConnectionHandle> _connectMachine(
    Machine machine, {
    String? password,
    String? privateKey,
  }) {
    return _connectionGateway.connect(
      host: machine.host,
      port: machine.sshPort,
      username: machine.sshUsername!,
      authType: machine.sshAuthType,
      password: password,
      privateKey: privateKey,
      jump: _machineJumpConfig(machine),
    );
  }

  SshJumpConfig? _machineJumpConfig(Machine machine) {
    return _inlineJumpConfig(
      host: machine.sshJumpHost,
      port: machine.sshJumpPort,
      username: machine.sshJumpUsername,
    );
  }

  SshJumpConfig? _inlineJumpConfig({
    required String? host,
    required int port,
    required String? username,
  }) {
    final trimmedHost = host?.trim();
    if (trimmedHost == null || trimmedHost.isEmpty) return null;
    final trimmedUsername = username?.trim();
    return SshJumpConfig(
      host: trimmedHost,
      port: port,
      username: trimmedUsername == null || trimmedUsername.isEmpty
          ? null
          : trimmedUsername,
    );
  }
}
