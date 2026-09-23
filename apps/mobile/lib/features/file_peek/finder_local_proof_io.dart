import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// A one-shot listener accessible only on this machine, never the LAN.
class FinderLocalProof {
  final ServerSocket _server;
  final String token;
  late final StreamSubscription<Socket> _subscription;
  Socket? _socket;

  int get port => _server.port;

  FinderLocalProof._(this._server, this.token) {
    _subscription = _server.listen((socket) {
      if (_socket != null) {
        socket.destroy();
        return;
      }
      _socket = socket;
      unawaited(_server.close());
      unawaited(_respond(socket));
    });
  }

  Future<void> _respond(Socket socket) async {
    try {
      socket.add(ascii.encode(token));
      await socket.close();
    } catch (_) {
      socket.destroy();
    }
  }

  static Future<FinderLocalProof> create() async {
    final random = Random.secure();
    final token = List.generate(
      32,
      (_) => random.nextInt(256),
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    return FinderLocalProof._(server, token);
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    await _server.close();
    _socket?.destroy();
  }
}
