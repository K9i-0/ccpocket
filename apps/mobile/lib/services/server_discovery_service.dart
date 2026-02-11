import 'dart:async';

import 'package:flutter/foundation.dart';

import 'server_discovery_impl_stub.dart'
    if (dart.library.io) 'server_discovery_impl_io.dart'
    as impl;

class DiscoveredServer {
  final String name;
  final String host;
  final int port;
  final bool authRequired;

  const DiscoveredServer({
    required this.name,
    required this.host,
    required this.port,
    required this.authRequired,
  });

  String get wsUrl => 'ws://$host:$port';

  @override
  bool operator ==(Object other) =>
      other is DiscoveredServer && host == other.host && port == other.port;

  @override
  int get hashCode => Object.hash(host, port);
}

class ServerDiscoveryService {
  final _serversController =
      StreamController<List<DiscoveredServer>>.broadcast();
  final Map<String, DiscoveredServer> _servers = {};
  Object? _discovery;

  Stream<List<DiscoveredServer>> get servers => _serversController.stream;

  Future<void> startDiscovery() async {
    try {
      await stopDiscovery();
      _discovery = await impl.startDiscovery(
        onResolved: (name, host, port, authRequired) {
          final server = DiscoveredServer(
            name: name,
            host: host,
            port: port,
            authRequired: authRequired,
          );
          _servers['$host:$port'] = server;
          _emit();
        },
        onLost: (host, port) {
          _servers.remove('$host:$port');
          _emit();
        },
      );
    } catch (e) {
      debugPrint('[discovery] Failed to start: $e');
    }
  }

  Future<void> stopDiscovery() async {
    if (_discovery != null) {
      await impl.stopDiscovery(_discovery);
      _discovery = null;
    }
  }

  void dispose() {
    stopDiscovery();
    _servers.clear();
    _serversController.close();
  }

  void _emit() {
    if (!_serversController.isClosed) {
      _serversController.add(_servers.values.toList());
    }
  }
}
