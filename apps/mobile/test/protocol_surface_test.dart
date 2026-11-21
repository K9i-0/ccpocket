import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/protocol_surface.dart';

const _source = '''
class ClientMessage {
  ClientMessage._(Map<String, dynamic> json);

  factory ClientMessage.example(String path, {String? id, bool deep = false}) =>
      ClientMessage._({
        'type': 'example',
        'path': path,
        'id': ?id,
        if (deep) 'deep': true,
      });

  factory ClientMessage.built(String? note) {
    final json = <String, dynamic>{'type': 'built'};
    if (note != null) json['note'] = note;
    return ClientMessage._(json);
  }

  factory ClientMessage.clientCapabilities({
    List<String> supportedServerMessages = const ['one', 'two'],
  }) => ClientMessage._({
    'type': 'client_capabilities',
    'supportedServerMessages': supportedServerMessages,
  });
}

sealed class ServerMessage {
  factory ServerMessage.fromJson(Map<String, dynamic> json) {
    return switch (json['type'] as String) {
      'plain' => Plain(
        id: json['id'] as String,
        note: json['note'] as String?,
        count: json['count'] as int? ?? 0,
        item: json['item'] is Map ? Item(json['item'] as Map) : null,
      ),
      'first' || 'second' => Delegated.fromJson(json),
      _ => Unknown(),
    };
  }
}

class Delegated implements ServerMessage {
  factory Delegated.fromJson(Map<String, dynamic> data) =>
      Delegated(name: data['name'] as String, extra: data['extra']);
}
''';

void main() {
  group('extractProtocolSurface', () {
    final surface = extractProtocolSurface(messagesSource: _source);

    test('separates keys that are always sent from conditional ones', () {
      final example = surface.sent.singleWhere((s) => s.type == 'example');
      expect(example.from, 'ClientMessage.example');
      expect(example.always, {'type', 'path'});
      expect(example.sometimes, {'id', 'deep'});
      expect(example.unchecked, isEmpty);
    });

    test('treats keys assigned after the literal as conditional', () {
      final built = surface.sent.singleWhere((s) => s.type == 'built');
      expect(built.always, {'type'});
      expect(built.sometimes, {'note'});
    });

    test('reads the default opt-in list', () {
      expect(surface.supportedServerMessages, ['one', 'two']);
    });

    test('requires only keys cast to a non-null type without a guard', () {
      final plain = surface.read.singleWhere((r) => r.type == 'plain');
      expect(plain.required, {'id'});
      expect(plain.optional, {'note', 'count', 'item'});
    });

    test('follows fromJson and repeats a shared case for each type', () {
      for (final type in ['first', 'second']) {
        final shape = surface.read.singleWhere((r) => r.type == type);
        expect(shape.required, {'name'});
        expect(shape.optional, {'extra'});
        expect(shape.unchecked, isEmpty);
      }
    });

    test('reports a spread it cannot see into', () {
      final other = extractProtocolSurface(
        messagesSource: '''
class ClientMessage {
  factory ClientMessage.spread(Map<String, dynamic> rest) =>
      ClientMessage._({'type': 'spread', ...rest});
}
sealed class ServerMessage {
  factory ServerMessage.fromJson(Map<String, dynamic> json) {
    return switch (json['type'] as String) {
      'opaque' => parseElsewhere(json),
      _ => null,
    };
  }
}
''',
      );
      expect(other.sent.single.unchecked, ['spread rest']);
      expect(other.read.single.unchecked, [
        'passes the message to parseElsewhere',
      ]);
    });
  });

  test('the generated Bridge file matches the app sources', () {
    final generated = File(generatedPath).readAsStringSync();
    expect(
      generated,
      renderTypeScript(extractFromWorkingTree()),
      reason:
          'Run `dart run tool/protocol_surface.dart` in apps/mobile and '
          'commit $generatedPath.',
    );
  });
}
