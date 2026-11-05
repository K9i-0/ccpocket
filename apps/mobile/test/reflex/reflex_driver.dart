/// Drives a [ReflexNode] the way the article's test SDK does: `act` sends an
/// action, `precondition` waits (without sleeps of a fixed length) until the
/// state satisfies a predicate and reports the last state on timeout.
library;

import 'dart:convert';

import 'package:ccpocket/core/reflex/reflex_node.dart';
import 'package:flutter_test/flutter_test.dart';

class ReflexDriver {
  ReflexDriver(this.node);

  final ReflexNode node;

  Map<String, Object?> get state => node.stateJson();

  Future<void> act(String action, [Map<String, Object?> args = const {}]) =>
      node.dispatch(action, args);

  Future<Map<String, Object?>> precondition(
    String description,
    bool Function(Map<String, Object?> state) check, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (true) {
      final current = state;
      if (check(current)) return current;
      if (DateTime.now().isAfter(deadline)) {
        fail(
          'precondition "$description" not met within $timeout.\n'
          'Last ${node.name} state:\n'
          '${const JsonEncoder.withIndent('  ').convert(current)}',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
  }

  static List<String> sessionIds(Map<String, Object?> state) => [
    for (final s in state['sessions']! as List) (s as Map)['id'] as String,
  ];
}
