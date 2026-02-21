import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';

import '../services/notification_service.dart';
import 'app_router.dart';

class SessionRouteObserver extends AutoRouterObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _syncActiveSession(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _syncActiveSession(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _syncActiveSession(newRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _syncActiveSession(previousRoute);
  }

  void _syncActiveSession(Route<dynamic>? route) {
    if (route == null) {
      NotificationService.instance.clearActiveSession();
      return;
    }

    final settings = route.settings;
    final name = settings.name;
    final sessionId = _extractSessionId(settings.arguments);

    if (sessionId == null || sessionId.isEmpty) {
      NotificationService.instance.clearActiveSession();
      return;
    }

    if (name == ClaudeSessionRoute.name) {
      NotificationService.instance.setActiveSession(
        sessionId: sessionId,
        provider: 'claude',
      );
      return;
    }
    if (name == CodexSessionRoute.name) {
      NotificationService.instance.setActiveSession(
        sessionId: sessionId,
        provider: 'codex',
      );
      return;
    }

    NotificationService.instance.clearActiveSession();
  }

  String? _extractSessionId(Object? arguments) {
    if (arguments == null) return null;

    if (arguments is Map) {
      return arguments['sessionId']?.toString();
    }

    try {
      final dynamic dynamicArgs = arguments;
      return dynamicArgs.sessionId?.toString();
    } catch (_) {
      return null;
    }
  }
}
