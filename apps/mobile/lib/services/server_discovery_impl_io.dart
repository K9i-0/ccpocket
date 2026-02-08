import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart';

Future<BonsoirDiscovery> startDiscovery({
  required void Function(String name, String host, int port, bool authRequired)
      onResolved,
  required void Function(String host, int port) onLost,
}) async {
  final discovery = BonsoirDiscovery(type: '_ccpocket._tcp');
  await discovery.initialize();

  discovery.eventStream?.listen((event) {
    switch (event) {
      case BonsoirDiscoveryServiceResolvedEvent():
        final service = event.service;
        final host = service.host ?? service.name;
        onResolved(
          service.name,
          host,
          service.port,
          service.attributes['auth'] == 'required',
        );
      case BonsoirDiscoveryServiceLostEvent():
        final service = event.service;
        final host = service.host ?? service.name;
        onLost(host, service.port);
      default:
        break;
    }
  });

  await discovery.start();
  debugPrint('[discovery] Started scanning for _ccpocket._tcp');
  return discovery;
}

Future<void> stopDiscovery(dynamic discovery) async {
  if (discovery is BonsoirDiscovery && !discovery.isStopped) {
    await discovery.stop();
  }
}
