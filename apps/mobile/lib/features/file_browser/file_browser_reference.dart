import 'package:flutter/material.dart';

import '../../services/bridge_service.dart';

/// Callbacks are owned by a live composer, never by the selected global session.
class FileBrowserReferences {
  static final _callbacks = Expando<Map<String, ValueChanged<String>>>();

  static void Function() register(
    BridgeService bridge,
    String sessionId,
    ValueChanged<String> callback,
  ) {
    final map = _callbacks[bridge] ??= {};
    map[sessionId] = callback;
    return () {
      if (identical(map[sessionId], callback)) map.remove(sessionId);
    };
  }

  static ValueChanged<String>? capture(
    BridgeService bridge,
    String? sessionId,
  ) {
    final map = _callbacks[bridge];
    final callback = map?[sessionId];
    if (callback == null) return null;
    return (path) {
      if (identical(map?[sessionId], callback)) callback(path);
    };
  }
}
