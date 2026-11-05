/// Reflex introspection: a screen's state and actions as plain JSON.
///
/// A node exposes what a user can see (state) and do (actions) on one screen,
/// so tests and agents can drive the screen without pixels or widget keys.
/// Prototype; see docs/reflex-prototype.md.
library;

/// One operation a node accepts. [params] maps parameter names to a short
/// type description (for example `'string'` or `'enum(all|claude|codex)'`).
class ReflexAction {
  const ReflexAction(this.name, this.description, {this.params = const {}});

  final String name;
  final String description;
  final Map<String, String> params;

  Map<String, Object?> toJson() => {
    'name': name,
    'description': description,
    if (params.isNotEmpty) 'params': params,
  };
}

class ReflexException implements Exception {
  ReflexException(this.message);
  final String message;
  @override
  String toString() => 'ReflexException: $message';
}

abstract class ReflexNode {
  String get name;

  /// JSON-safe projection of what the user sees on this screen.
  Map<String, Object?> stateJson();

  List<ReflexAction> get actions;

  /// Runs [action]. Throws [ReflexException] for unknown actions or bad args.
  Future<void> dispatch(String action, [Map<String, Object?> args = const {}]);

  Map<String, Object?> toJson() => {
    'name': name,
    'state': stateJson(),
    'actions': [for (final a in actions) a.toJson()],
  };

  /// Reads a required string argument.
  static String stringArg(Map<String, Object?> args, String key) {
    final value = args[key];
    if (value is String) return value;
    throw ReflexException('Missing string argument "$key"');
  }
}
