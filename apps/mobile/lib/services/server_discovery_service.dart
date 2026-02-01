import 'dart:async';

import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart';

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
  BonsoirDiscovery? _discovery;
  final _serversController =
      StreamController<List<DiscoveredServer>>.broadcast();
  final Map<String, DiscoveredServer> _servers = {};

  Stream<List<DiscoveredServer>> get servers => _serversController.stream;

  Future<void> startDiscovery() async {
    try {
      await stopDiscovery();

      _discovery = BonsoirDiscovery(type: '_ccpocket._tcp');
      await _discovery!.initialize();

      _discovery!.eventStream?.listen((event) {
        switch (event) {
          case BonsoirDiscoveryServiceResolvedEvent():
            final service = event.service;
            final host = service.host ?? service.name;
            final server = DiscoveredServer(
              name: service.name,
              host: host,
              port: service.port,
              authRequired: service.attributes['auth'] == 'required',
            );
            _servers[_key(host, service.port)] = server;
            _emit();
          case BonsoirDiscoveryServiceLostEvent():
            final service = event.service;
            final host = service.host ?? service.name;
            _servers.remove(_key(host, service.port));
            _emit();
          default:
            break;
        }
      });

      await _discovery!.start();
      debugPrint('[discovery] Started scanning for _ccpocket._tcp');
    } catch (e) {
      debugPrint('[discovery] Failed to start: $e');
    }
  }

  Future<void> stopDiscovery() async {
    if (_discovery != null && !_discovery!.isStopped) {
      await _discovery!.stop();
    }
    _discovery = null;
  }

  void dispose() {
    stopDiscovery();
    _servers.clear();
    _serversController.close();
  }

  String _key(String host, int port) => '$host:$port';

  void _emit() {
    if (!_serversController.isClosed) {
      _serversController.add(_servers.values.toList());
    }
  }
}
