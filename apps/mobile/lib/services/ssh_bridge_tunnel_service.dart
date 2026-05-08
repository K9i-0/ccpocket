import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';

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
  final SSHClient _jumpClient;
  final ServerSocket _server;
  final StreamSubscription<Socket> _serverSubscription;
  final Set<Socket> _localSockets = {};
  final Set<SSHSocket> _remoteSockets = {};

  _BridgeTunnel._({
    required this.machineId,
    required this.signature,
    required SSHClient jumpClient,
    required ServerSocket server,
    required StreamSubscription<Socket> serverSubscription,
  }) : _jumpClient = jumpClient,
       _server = server,
       _serverSubscription = serverSubscription;

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
    final jumpSocket = await SSHSocket.connect(
      jumpHost,
      jumpPort,
      timeout: connectionTimeout,
    );
    final jumpClient = _createClient(
      jumpSocket,
      username: jumpUsername,
      authType: authType,
      password: password,
      privateKey: privateKey,
      debugLog: debugLog,
    );

    try {
      await jumpClient.ping().timeout(connectionTimeout);
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      late final _BridgeTunnel tunnel;
      final subscription = server.listen((localSocket) async {
        tunnel._handleLocalSocket(
          localSocket,
          targetHost: targetHost,
          targetPort: targetPort,
          connectionTimeout: connectionTimeout,
        );
      });
      tunnel = _BridgeTunnel._(
        machineId: machineId,
        signature: signature,
        jumpClient: jumpClient,
        server: server,
        serverSubscription: subscription,
      );
      return tunnel;
    } catch (_) {
      jumpClient.close();
      rethrow;
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

  Future<void> _handleLocalSocket(
    Socket localSocket, {
    required String targetHost,
    required int targetPort,
    required Duration connectionTimeout,
  }) async {
    _localSockets.add(localSocket);

    try {
      final remoteSocket = await _jumpClient
          .forwardLocal(targetHost, targetPort)
          .timeout(connectionTimeout);
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

  Future<void> close() async {
    await _serverSubscription.cancel();
    await _server.close();
    for (final socket in _localSockets.toList()) {
      socket.destroy();
    }
    for (final socket in _remoteSockets.toList()) {
      socket.destroy();
    }
    _jumpClient.close();
  }
}
