import 'package:flutter/foundation.dart';

import '../../services/bridge_service.dart';

/// Shared by all browsing entry points, isolated by server and worktree.
class FileBrowserHistory extends ValueNotifier<List<String>> {
  FileBrowserHistory() : super(const []);
  static final _stores = Expando<Map<String, FileBrowserHistory>>();

  static FileBrowserHistory forProject(BridgeService bridge, String project) {
    final stores = _stores[bridge] ??= {};
    return stores.putIfAbsent(
      '${bridge.lastUrl ?? ''}\u0000$project',
      FileBrowserHistory.new,
    );
  }

  void record(String path) {
    value = List.unmodifiable(
      [path, ...value.where((p) => p != path)].take(30),
    );
  }

  void seed(Iterable<String> paths) {
    value = List.unmodifiable({...value, ...paths}.take(30));
  }
}
