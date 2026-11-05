import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

import '../core/reflex/reflex_node.dart';
import '../core/reflex/reflex_registry.dart';

/// Debug-only access to Reflex nodes: read screen state and run actions
/// without widget keys or screenshots. See docs/reflex-prototype.md.
void registerReflexExtensions() {
  if (kReleaseMode) return;

  registerMarionetteExtension(
    name: 'ccpocket.reflex.tree',
    description:
        'List Reflex nodes with their state JSON and accepted actions. '
        'Optional param: node (name) to return a single node.',
    callback: (params) async {
      final name = params['node'];
      if (name != null && name.isNotEmpty) {
        final node = ReflexRegistry.lookup(name);
        if (node == null) {
          return MarionetteExtensionResult.error(1, 'Unknown node: $name');
        }
        return MarionetteExtensionResult.success(node.toJson());
      }
      return MarionetteExtensionResult.success({
        'nodes': [for (final node in ReflexRegistry.nodes) node.toJson()],
      });
    },
  );

  registerMarionetteExtension(
    name: 'ccpocket.reflex.dispatch',
    description:
        'Run an action on a Reflex node and return its new state. '
        'Params: node, action, args (JSON object string, optional).',
    callback: (params) async {
      final name = params['node'];
      final action = params['action'];
      if (name == null || action == null) {
        return MarionetteExtensionResult.invalidParams(
          'Required parameters: node, action',
        );
      }
      final node = ReflexRegistry.lookup(name);
      if (node == null) {
        return MarionetteExtensionResult.error(1, 'Unknown node: $name');
      }
      final Map<String, Object?> args;
      try {
        final raw = params['args'];
        args = raw == null || raw.isEmpty
            ? const {}
            : (jsonDecode(raw) as Map).cast<String, Object?>();
      } on Object {
        return MarionetteExtensionResult.invalidParams(
          'args must be a JSON object string',
        );
      }
      try {
        await node.dispatch(action, args);
      } on ReflexException catch (e) {
        return MarionetteExtensionResult.error(2, e.message);
      }
      return MarionetteExtensionResult.success({
        'node': name,
        'action': action,
        'state': node.stateJson(),
      });
    },
  );
}
