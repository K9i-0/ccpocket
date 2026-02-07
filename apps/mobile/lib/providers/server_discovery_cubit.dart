import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../services/server_discovery_service.dart';

class ServerDiscoveryCubit extends Cubit<List<DiscoveredServer>> {
  final ServerDiscoveryService _service;
  StreamSubscription<List<DiscoveredServer>>? _sub;

  ServerDiscoveryCubit()
      : _service = ServerDiscoveryService(),
        super(const []) {
    _service.startDiscovery();
    _sub = _service.servers.listen(emit);
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    _service.dispose();
    return super.close();
  }
}
