import 'package:flutter/widgets.dart';

import 'connection_url_parser.dart';

/// Exposes the app-level `ccpocket://connect` deep-link notifier to the
/// widget tree.
///
/// The app's initial route is created by auto_route without arguments, so the
/// notifier cannot be passed through the route constructor. Screens that
/// handle connect links (e.g. `SessionListScreen`) look it up from context
/// instead.
class ConnectDeepLinkScope extends InheritedWidget {
  const ConnectDeepLinkScope({
    super.key,
    required this.notifier,
    required super.child,
  });

  final ValueNotifier<ConnectionParams?> notifier;

  /// Returns the nearest notifier without registering a dependency, so it is
  /// safe to call from `initState`.
  static ValueNotifier<ConnectionParams?>? maybeOf(BuildContext context) {
    return context
        .getInheritedWidgetOfExactType<ConnectDeepLinkScope>()
        ?.notifier;
  }

  @override
  bool updateShouldNotify(ConnectDeepLinkScope oldWidget) =>
      notifier != oldWidget.notifier;
}
