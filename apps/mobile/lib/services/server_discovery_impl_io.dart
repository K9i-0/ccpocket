import 'dart:io';

import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart';

import '../core/logger.dart';

/// Picks the host used to connect to a discovered service.
///
/// bonsoir 7 split the old `host` field into `hostname` (the mDNS name) and
/// `hostAddresses` (resolved IPs). bonsoir 6 reported the mDNS name everywhere
/// except Android, which reported an IP, so the same preference is kept here
/// to leave discovered endpoints (and their identity keys) unchanged.
@visibleForTesting
String selectDiscoveryHost({
  required String name,
  required String? hostname,
  required List<String> hostAddresses,
  required bool preferAddress,
}) {
  // IPv6 results are often link-local and unusable without a zone id.
  final address =
      hostAddresses.where((a) => !a.contains(':')).firstOrNull ??
      hostAddresses.firstOrNull;
  final candidates = preferAddress ? [address, hostname] : [hostname, address];
  return candidates
          .whereType<String>()
          .where((h) => h.isNotEmpty)
          .firstOrNull ??
      name;
}

String _hostOf(BonsoirService service) => selectDiscoveryHost(
  name: service.name,
  hostname: service.hostname,
  hostAddresses: service.hostAddresses,
  preferAddress: Platform.isAndroid,
);

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
        final host = _hostOf(service);
        onResolved(
          service.name,
          host,
          service.port,
          service.attributes['auth'] == 'required',
        );
      case BonsoirDiscoveryServiceLostEvent():
        final service = event.service;
        final host = _hostOf(service);
        onLost(host, service.port);
      default:
        break;
    }
  });

  await discovery.start();
  logger.info('[discovery] Started scanning for _ccpocket._tcp');
  return discovery;
}

Future<void> stopDiscovery(dynamic discovery) async {
  if (discovery is BonsoirDiscovery && !discovery.isStopped) {
    await discovery.stop();
  }
}
