import 'dart:collection';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';

import 'app_router.dart';
import '../features/workspace/state/workspace_destination.dart';

@immutable
class SessionRouteIdentity {
  final String sessionId;
  final String provider;

  const SessionRouteIdentity({required this.sessionId, required this.provider});

  bool matches({required String sessionId, required String provider}) {
    return this.sessionId == sessionId && this.provider == provider;
  }
}

class SessionRouteRegistry {
  SessionRouteRegistry._();

  static final SessionRouteRegistry instance = SessionRouteRegistry._();

  final Map<Object, ({Object owner, SessionRouteIdentity identity})> _routes =
      HashMap.identity();

  final Map<
    Object,
    ({
      Object owner,
      void Function() reveal,
      void Function(WorkspaceSessionSelection) open,
    })
  >
  _workspaces = HashMap.identity();

  void registerWorkspace({
    required Object routeIdentity,
    required Object owner,
    required void Function() reveal,
    required void Function(WorkspaceSessionSelection) open,
  }) {
    _workspaces[routeIdentity] = (owner: owner, reveal: reveal, open: open);
  }

  void unregisterWorkspace(Object routeIdentity, Object owner) {
    if (identical(_workspaces[routeIdentity]?.owner, owner)) {
      _workspaces.remove(routeIdentity);
      remove(routeIdentity: routeIdentity, owner: owner);
    }
  }

  void update({
    required Object routeIdentity,
    required Object owner,
    required String sessionId,
    required String provider,
  }) {
    _routes[routeIdentity] = (
      owner: owner,
      identity: SessionRouteIdentity(sessionId: sessionId, provider: provider),
    );
  }

  void remove({required Object routeIdentity, required Object owner}) {
    final registered = _routes[routeIdentity];
    if (registered != null && identical(registered.owner, owner)) {
      _routes.remove(routeIdentity);
    }
  }

  SessionRouteIdentity? identityFor(Object routeIdentity) {
    return _routes[routeIdentity]?.identity;
  }

  @visibleForTesting
  void clear() {
    _routes.clear();
    _workspaces.clear();
  }
}

class SessionStackNavigation {
  const SessionStackNavigation._();

  static bool revealStackedSession(
    StackRouter router, {
    required String sessionId,
    required String provider,
  }) {
    final rootRouter = router.root;
    final targetIndex = rootRouter.stack.indexWhere(
      (page) => matchesDestination(
        routeIdentity: page,
        routeName: page.routeData.name,
        arguments: page.routeData.args,
        sessionId: sessionId,
        provider: provider,
      ),
    );
    if (targetIndex == -1 || rootRouter.navigatorKey.currentState == null) {
      return false;
    }

    final targetPage = rootRouter.stack[targetIndex];
    SessionRouteRegistry.instance._workspaces[targetPage]?.reveal();
    rootRouter.popUntil((route) => identical(route.settings, targetPage));
    return true;
  }

  static bool openWorkspaceSession(
    StackRouter router,
    WorkspaceSessionSelection selection,
  ) {
    final rootRouter = router.root;
    for (final page in rootRouter.stack.reversed) {
      final workspace = SessionRouteRegistry.instance._workspaces[page];
      if (workspace == null) continue;
      workspace.open(selection);
      rootRouter.popUntil((route) => identical(route.settings, page));
      return true;
    }
    return false;
  }

  @visibleForTesting
  static bool matchesDestination({
    required Object routeIdentity,
    required String routeName,
    required Object? arguments,
    required String sessionId,
    required String provider,
  }) {
    final liveIdentity = SessionRouteRegistry.instance.identityFor(
      routeIdentity,
    );
    if (liveIdentity != null) {
      return liveIdentity.matches(sessionId: sessionId, provider: provider);
    }
    if (routeName == ClaudeSessionRoute.name &&
        provider == 'claude' &&
        arguments is ClaudeSessionRouteArgs) {
      return arguments.sessionId == sessionId;
    }
    if (routeName == CodexSessionRoute.name &&
        provider == 'codex' &&
        arguments is CodexSessionRouteArgs) {
      return arguments.sessionId == sessionId;
    }
    return false;
  }
}
