import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';

import '../models/messages.dart';
import '../providers/bridge_cubits.dart';
import 'app_router.dart';

/// Adapts [ConnectionCubit] (a StreamCubit) to [ChangeNotifier] so it can be
/// used as auto_route's `reevaluateListenable`.
///
/// When the connection state changes the guard is automatically re-evaluated,
/// redirecting to [ConnectionRoute] on disconnect or allowing through on
/// reconnect.
class ConnectionChangeNotifier extends ChangeNotifier {
  StreamSubscription<BridgeConnectionState>? _sub;
  BridgeConnectionState _state = BridgeConnectionState.disconnected;

  BridgeConnectionState get state => _state;

  void listen(ConnectionCubit cubit) {
    _state = cubit.state;
    _sub = cubit.stream.listen((newState) {
      if (_state != newState) {
        _state = newState;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Route guard that redirects to the connection screen when the bridge is
/// not connected. Uses [ConnectionChangeNotifier] as `reevaluateListenable`
/// to automatically re-check on connection state changes.
class ConnectionGuard extends AutoRouteGuard {
  final ConnectionChangeNotifier notifier;

  ConnectionGuard(this.notifier);

  @override
  void onNavigation(NavigationResolver resolver, StackRouter router) {
    final isConnected =
        notifier.state == BridgeConnectionState.connected ||
        notifier.state == BridgeConnectionState.reconnecting;

    if (isConnected) {
      resolver.next();
    } else {
      // Only push ConnectionRoute if we're not already showing it.
      // Without this check, reevaluateListenable would repeatedly push
      // ConnectionRoute, wiping out any routes pushed from ConnectionScreen
      // (e.g. SettingsRoute).
      final currentPath = router.current.name;
      if (currentPath != ConnectionRoute.name) {
        router.push(ConnectionRoute());
      }
      resolver.next(false);
    }
  }
}
