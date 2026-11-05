import 'reflex_node.dart';

/// Live Reflex nodes, read by the debug-only `ccpocket.reflex.*` extensions.
class ReflexRegistry {
  ReflexRegistry._();

  static final Map<String, ReflexNode> _nodes = {};

  static Iterable<ReflexNode> get nodes => _nodes.values;

  static ReflexNode? lookup(String name) => _nodes[name];

  /// Registers [node], replacing any node with the same name.
  static void register(ReflexNode node) => _nodes[node.name] = node;

  static void unregister(ReflexNode node) {
    if (identical(_nodes[node.name], node)) _nodes.remove(node.name);
  }
}
