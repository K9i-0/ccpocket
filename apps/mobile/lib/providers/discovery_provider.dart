import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/server_discovery_service.dart';

/// Stream of discovered servers on the local network.
final serverDiscoveryProvider = StreamProvider<List<DiscoveredServer>>((ref) {
  final discovery = ServerDiscoveryService();
  discovery.startDiscovery();
  ref.onDispose(() => discovery.dispose());
  return discovery.servers;
});
