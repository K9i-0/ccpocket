import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/messages.dart';
import '../services/bridge_service.dart';

/// Singleton BridgeService instance managed by Riverpod.
final bridgeServiceProvider = Provider<BridgeService>((ref) {
  final bridge = BridgeService();
  ref.onDispose(() => bridge.dispose());
  return bridge;
});

/// Stream of connection state changes from the bridge.
final connectionStateProvider = StreamProvider<BridgeConnectionState>((ref) {
  return ref.watch(bridgeServiceProvider).connectionStatus;
});

/// Stream of currently running sessions.
final sessionListProvider = StreamProvider<List<SessionInfo>>((ref) {
  return ref.watch(bridgeServiceProvider).sessionList;
});

/// Stream of recent (historical) sessions.
final recentSessionsProvider = StreamProvider<List<RecentSession>>((ref) {
  return ref.watch(bridgeServiceProvider).recentSessionsStream;
});
