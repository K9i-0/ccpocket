import 'dart:convert';
import 'dart:io';

import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/models/protocol_version.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> fixture(String name) {
  final contents = File('../../test/fixtures/protocol/v1/$name.json')
      .readAsStringSync();
  return jsonDecode(contents) as Map<String, dynamic>;
}

void main() {
  group('protocol v1 contract fixtures', () {
    for (final name in ['legacy-session-list', 'current-session-list']) {
      test('accepts $name', () {
        final json = fixture(name);
        final compatibility = ProtocolCompatibility.fromBridgeJson(json);
        final message = ServerMessage.fromJson(json);

        expect(compatibility.isCompatible, isTrue);
        expect(compatibility.selectedVersion, 1);
        expect(message, isA<SessionListMessage>());
      });
    }

    for (final name in [
      'legacy-client-capabilities',
      'current-client-capabilities',
    ]) {
      test('keeps $name as a frozen client fixture', () {
        final json = fixture(name);

        expect(json['type'], 'client_capabilities');
        expect(json['supportedServerMessages'], isA<List<dynamic>>());
      });
    }
  });
}
