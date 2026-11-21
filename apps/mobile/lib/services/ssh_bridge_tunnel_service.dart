import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../models/machine.dart';
import 'machine_manager_service.dart';

/// Maintains local TCP forwards for Bridge HTTP/WebSocket traffic that must
/// traverse an SSH jump host.
class SshBridgeTunnelService {
  final MachineManagerService _machineManager;
  final Duration connectionTimeout;
  final void Function(String?)? debugLog;
  final Map<String, _BridgeTunnel> _tunnels = {};

  SshBridgeTunnelService(
    this._machineManager, {
    this.connectionTimeout = const Duration(seconds: 10),
    this.debugLog,
  });

  Future<String> buildWsUrl(
    Machine machine, {
    String? password,
    Future<String?> Function()? promptForPassword,
  }) async {
    final tunnel = await _ensureTunnel(
      machine,
      password: password,
      promptForPassword: promptForPassword,
    );
    if (tunnel == null) return machine.wsUrl;
    return '${machine.useSsl ? 'wss' : 'ws'}://127.0.0.1:${tunnel.localPort}';
  }

  Future<String> buildHttpBaseUrl(
    Machine machine, {
    String? password,
    Future<String?> Function()? promptForPassword,
  }) async {
    final tunnel = await _ensureTunnel(
      machine,
      password: password,
      promptForPassword: promptForPassword,
    );
    if (tunnel == null) return machine.httpUrl;
    return '${machine.useSsl ? 'https' : 'http'}://127.0.0.1:${tunnel.localPort}';
  }

  Future<void> closeForMachine(String machineId) async {
    final tunnel = _tunnels.remove(machineId);
    await tunnel?.close();
  }

  Future<void> closeAllExcept(String machineId) async {
    final machineIds = _tunnels.keys.where((id) => id != machineId).toList();
    for (final id in machineIds) {
      await closeForMachine(id);
    }
  }

  Future<void> closeAll() async {
    final tunnels = _tunnels.values.toList();
    _tunnels.clear();
    for (final tunnel in tunnels) {
      await tunnel.close();
    }
  }

  /// Drops every jump connection but keeps the local ports, as a network
  /// change would.
  @visibleForTesting
  void dropJumpConnectionsForTesting() {
    for (final tunnel in _tunnels.values) {
      tunnel.dropJumpConnectionForTesting();
    }
  }

  Future<_BridgeTunnel?> _ensureTunnel(
    Machine machine, {
    String? password,
    Future<String?> Function()? promptForPassword,
  }) async {
    final jumpHost = machine.sshJumpHost?.trim();
    if (jumpHost == null || jumpHost.isEmpty) return null;
    if (machine.useSsl) {
      throw UnsupportedError(
        'SSH jump host Bridge tunneling does not support SSL machines yet',
      );
    }
    if (!machine.sshEnabled || machine.sshUsername?.trim().isEmpty != false) {
      throw StateError('SSH username is required for Bridge tunneling');
    }

    final signature = _tunnelSignature(machine);
    final existing = _tunnels[machine.id];
    if (existing != null && existing.signature == signature) {
      return existing;
    }

    await closeForMachine(machine.id);

    final credentials = await _resolveJumpCredentials(
      machine,
      targetPassword: password,
      promptForPassword: promptForPassword,
    );
    final tunnel = await _BridgeTunnel.start(
      machineId: machine.id,
      signature: signature,
      jumpHost: jumpHost,
      jumpPort: machine.sshJumpPort,
      jumpUsername: machine.sshJumpUsername?.trim().isNotEmpty == true
          ? machine.sshJumpUsername!.trim()
          : machine.sshUsername!.trim(),
      authType: credentials.authType,
      password: credentials.password,
      privateKey: credentials.privateKey,
      targetHost: machine.host,
      targetPort: machine.port,
      connectionTimeout: connectionTimeout,
      debugLog: debugLog,
    );
    _tunnels[machine.id] = tunnel;
    return tunnel;
  }

  Future<_JumpCredentials> _resolveJumpCredentials(
    Machine machine, {
    String? targetPassword,
    Future<String?> Function()? promptForPassword,
  }) async {
    if (machine.hasJumpCredentials) {
      if (machine.sshJumpAuthType == SshAuthType.password) {
        final password = await _readPassword(
          () => _machineManager.getSshJumpPassword(machine.id),
          providedPassword: null,
          promptForPassword: promptForPassword,
        );
        return _JumpCredentials(
          authType: SshAuthType.password,
          password: password,
        );
      }

      final privateKey = await _machineManager.getSshJumpPrivateKey(machine.id);
      if (privateKey == null || privateKey.isEmpty) {
        throw SSHAuthAbortError('Jump host private key required');
      }
      return _JumpCredentials(
        authType: SshAuthType.privateKey,
        privateKey: privateKey,
      );
    }

    if (machine.sshAuthType == SshAuthType.password) {
      final password = await _readPassword(
        () => _machineManager.getSshPassword(machine.id),
        providedPassword: targetPassword,
        promptForPassword: promptForPassword,
      );
      return _JumpCredentials(
        authType: SshAuthType.password,
        password: password,
      );
    }

    final privateKey = await _machineManager.getSshPrivateKey(machine.id);
    if (privateKey == null || privateKey.isEmpty) {
      throw SSHAuthAbortError('Private key required');
    }
    return _JumpCredentials(
      authType: SshAuthType.privateKey,
      privateKey: privateKey,
    );
  }

  Future<String> _readPassword(
    Future<String?> Function() readStoredPassword, {
    required String? providedPassword,
    Future<String?> Function()? promptForPassword,
  }) async {
    var password = providedPassword;
    password ??= await readStoredPassword();
    if ((password == null || password.isEmpty) && promptForPassword != null) {
      password = await promptForPassword();
    }
    if (password == null || password.isEmpty) {
      throw SSHAuthAbortError('Password required');
    }
    return password;
  }

  String _tunnelSignature(Machine machine) => [
    machine.id,
    machine.host,
    machine.port,
    machine.useSsl,
    machine.sshJumpHost,
    machine.sshJumpPort,
    machine.sshJumpUsername,
    machine.sshJumpAuthType.name,
    machine.hasJumpCredentials,
    machine.sshUsername,
    machine.sshAuthType.name,
  ].join('\n');
}

class _JumpCredentials {
  final SshAuthType authType;
  final String? password;
  final String? privateKey;

  const _JumpCredentials({
    required this.authType,
    this.password,
    this.privateKey,
  });
}

class _BridgeTunnel {
  final String machineId;
  final String signature;
  final String _jumpHost;
  final int _jumpPort;
  final String _jumpUsername;
  final SshAuthType _authType;
  final String? _password;
  final String? _privateKey;
  final String _targetHost;
  final int _targetPort;
  final Duration _connectionTimeout;
  final void Function(String?)? _debugLog;
  SSHClient _jumpClient;
  Future<SSHClient>? _redial;
  late final ServerSocket _server;
  late final StreamSubscription<Socket> _serverSubscription;
  final Set<Socket> _localSockets = {};
  final Set<SSHSocket> _remoteSockets = {};
  Timer? _healthTimer;
  bool _checkingHealth = false;
  bool _closed = false;

  /// How often an open tunnel checks that the jump host still answers. A
  /// connection that silently stopped answering (for example after a network
  /// change) is closed, so the Bridge client notices and reconnects.
  static const _healthCheckInterval = Duration(seconds: 15);

  /// How long a quick liveness probe waits before treating the jump
  /// connection as dead.
  static const _probeTimeout = Duration(seconds: 5);

  _BridgeTunnel._({
    required this.machineId,
    required this.signature,
    required String jumpHost,
    required int jumpPort,
    required String jumpUsername,
    required SshAuthType authType,
    required String? password,
    required String? privateKey,
    required String targetHost,
    required int targetPort,
    required Duration connectionTimeout,
    required void Function(String?)? debugLog,
    required SSHClient jumpClient,
  }) : _jumpHost = jumpHost,
       _jumpPort = jumpPort,
       _jumpUsername = jumpUsername,
       _authType = authType,
       _password = password,
       _privateKey = privateKey,
       _targetHost = targetHost,
       _targetPort = targetPort,
       _connectionTimeout = connectionTimeout,
       _debugLog = debugLog,
       _jumpClient = jumpClient;

  int get localPort => _server.port;

  static Future<_BridgeTunnel> start({
    required String machineId,
    required String signature,
    required String jumpHost,
    required int jumpPort,
    required String jumpUsername,
    required SshAuthType authType,
    required String? password,
    required String? privateKey,
    required String targetHost,
    required int targetPort,
    required Duration connectionTimeout,
    required void Function(String?)? debugLog,
  }) async {
    final jumpClient = await _connectJumpClient(
      host: jumpHost,
      port: jumpPort,
      username: jumpUsername,
      authType: authType,
      password: password,
      privateKey: privateKey,
      timeout: connectionTimeout,
      debugLog: debugLog,
    );
    final tunnel = _BridgeTunnel._(
      machineId: machineId,
      signature: signature,
      jumpHost: jumpHost,
      jumpPort: jumpPort,
      jumpUsername: jumpUsername,
      authType: authType,
      password: password,
      privateKey: privateKey,
      targetHost: targetHost,
      targetPort: targetPort,
      connectionTimeout: connectionTimeout,
      debugLog: debugLog,
      jumpClient: jumpClient,
    );
    try {
      tunnel._server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      tunnel._serverSubscription = tunnel._server.listen(
        tunnel._handleLocalSocket,
      );
      tunnel._healthTimer = Timer.periodic(
        _healthCheckInterval,
        (_) => unawaited(tunnel._checkJumpHealth()),
      );
      return tunnel;
    } catch (_) {
      _closeQuietly(jumpClient);
      rethrow;
    }
  }

  static Future<SSHClient> _connectJumpClient({
    required String host,
    required int port,
    required String username,
    required SshAuthType authType,
    required String? password,
    required String? privateKey,
    required Duration timeout,
    required void Function(String?)? debugLog,
  }) async {
    final socket = await SSHSocket.connect(host, port, timeout: timeout);
    final client = _createClient(
      socket,
      username: username,
      authType: authType,
      password: password,
      privateKey: privateKey,
      debugLog: debugLog,
    );
    try {
      await client.ping().timeout(timeout);
      return client;
    } catch (_) {
      _closeQuietly(client);
      rethrow;
    }
  }

  /// Closes [client] without waiting; a dead connection may fail to close
  /// cleanly, which is not an error here.
  static void _closeQuietly(SSHClient client) {
    unawaited(client.close().catchError((Object _) {}));
  }

  static Future<bool> _responds(SSHClient client, Duration timeout) async {
    try {
      await client.ping().timeout(timeout);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _checkJumpHealth() async {
    if (_closed || _checkingHealth || _redial != null) return;
    _checkingHealth = true;
    try {
      final client = _jumpClient;
      if (client.isClosed) return;
      if (await _responds(client, _connectionTimeout)) return;
      if (_closed || !identical(client, _jumpClient)) return;
      _debugLog?.call('Bridge tunnel: jump host stopped answering');
      _closeQuietly(client);
    } finally {
      _checkingHealth = false;
    }
  }

  static SSHClient _createClient(
    SSHSocket socket, {
    required String username,
    required SshAuthType authType,
    required String? password,
    required String? privateKey,
    required void Function(String?)? debugLog,
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

    if (privateKey == null || privateKey.isEmpty) {
      throw SSHAuthAbortError('Private key required');
    }
    return SSHClient(
      socket,
      username: username,
      identities: SSHKeyPair.fromPem(privateKey),
      printDebug: debugLog,
    );
  }

  Future<void> _handleLocalSocket(Socket localSocket) async {
    _localSockets.add(localSocket);

    try {
      final remoteSocket = await _openForward();
      if (_closed) {
        remoteSocket.destroy();
        throw StateError('Bridge tunnel closed');
      }
      _remoteSockets.add(remoteSocket);

      localSocket.listen(
        remoteSocket.sink.add,
        onError: remoteSocket.sink.addError,
        onDone: () => unawaited(remoteSocket.sink.close()),
        cancelOnError: true,
      );
      remoteSocket.stream.listen(
        localSocket.add,
        onError: localSocket.addError,
        onDone: () => unawaited(localSocket.close()),
        cancelOnError: true,
      );

      void removeSockets() {
        _localSockets.remove(localSocket);
        _remoteSockets.remove(remoteSocket);
      }

      unawaited(localSocket.done.whenComplete(removeSockets));
      unawaited(remoteSocket.done.whenComplete(removeSockets));
    } catch (_) {
      _localSockets.remove(localSocket);
      localSocket.destroy();
    }
  }

  /// Opens a channel to the Bridge through the jump host.
  ///
  /// The jump connection can die without notice when the device changes
  /// networks or sleeps: the local port stays open, but nothing behind it
  /// answers, so every automatic Bridge reconnect to the same local URL would
  /// fail. When the connection is closed, or opening the channel times out
  /// and the jump host no longer answers, reconnect to the jump host once and
  /// retry. Errors from a jump host that still answers (for example while the
  /// Bridge restarts, or on a slow network) are passed through as is.
  Future<SSHSocket> _openForward() async {
    final client = _jumpClient;
    if (!client.isClosed) {
      try {
        return await client
            .forwardLocal(_targetHost, _targetPort)
            .timeout(_connectionTimeout);
      } on TimeoutException {
        if (await _responds(client, _probeTimeout)) rethrow;
        _debugLog?.call('Bridge tunnel: jump host did not answer');
      } catch (_) {
        if (!client.isClosed) rethrow;
      }
    }
    final fresh = await _replaceJumpClient(client);
    return fresh
        .forwardLocal(_targetHost, _targetPort)
        .timeout(_connectionTimeout);
  }

  /// Replaces [stale] with a new jump connection. Local sockets that fail at
  /// the same time share one reconnect.
  Future<SSHClient> _replaceJumpClient(SSHClient stale) {
    if (_closed) {
      return Future.error(StateError('Bridge tunnel closed'));
    }
    if (!identical(_jumpClient, stale)) return Future.value(_jumpClient);
    return _redial ??= () async {
      try {
        _closeQuietly(stale);
        final next = await _connectJumpClient(
          host: _jumpHost,
          port: _jumpPort,
          username: _jumpUsername,
          authType: _authType,
          password: _password,
          privateKey: _privateKey,
          timeout: _connectionTimeout,
          debugLog: _debugLog,
        );
        if (_closed) {
          _closeQuietly(next);
          throw StateError('Bridge tunnel closed');
        }
        _jumpClient = next;
        _debugLog?.call('Bridge tunnel: reconnected to the jump host');
        return next;
      } finally {
        _redial = null;
      }
    }();
  }

  /// Closes the jump connection but keeps the local port, as when the
  /// network drops.
  void dropJumpConnectionForTesting() => _closeQuietly(_jumpClient);

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _healthTimer?.cancel();
    await _serverSubscription.cancel();
    await _server.close();
    for (final socket in _localSockets.toList()) {
      socket.destroy();
    }
    for (final socket in _remoteSockets.toList()) {
      socket.destroy();
    }
    _closeQuietly(_jumpClient);
  }
}
