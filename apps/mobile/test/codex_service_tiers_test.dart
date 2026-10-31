import 'dart:convert';

import 'package:ccpocket/models/messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('retains unknown service tier ids instead of displaying Standard', () {
    final speed = codexSpeedFromRaw('ultrafast');
    expect(speed.value, 'ultrafast');
    expect(speed, const CodexSpeed('ultrafast', 'Ultrafast'));
    expect(codexSpeedFromRaw('priority'), CodexSpeed.fast);
    expect(codexSpeedFromRaw(null), CodexSpeed.standard);
    expect(codexSpeedFromRaw('default'), CodexSpeed.standard);
  });

  test(
    'decodes returned labels and descriptions alongside legacy tier ids',
    () {
      final message = ServerMessage.fromJson(
        jsonDecode('''{
      "type":"session_list", "sessions":[],
      "protocolCapabilities":["codex_service_tiers_v1"],
      "codexModelServiceTiers":{"gpt-6-astra":["fast","ultrafast"]},
      "codexModelServiceTierMetadata":{"gpt-6-astra":[
        {"id":"priority","name":"Fast","description":"2x speed"},
        {"id":"ultrafast","name":"Ultrafast","description":"Fastest responses"}
      ]}
    }''') as Map<String, dynamic>,
      ) as SessionListMessage;
      expect(message.codexModelServiceTiers['gpt-6-astra'], [
        'fast',
        'ultrafast',
      ]);
      final tiers = message.codexModelServiceTierMetadata['gpt-6-astra']!;
      expect(tiers.first, CodexSpeed.fast);
      expect(tiers.last.value, 'ultrafast');
      expect(tiers.last.label, 'Ultrafast');
      expect(tiers.last.description, 'Fastest responses');
      expect(message.protocolCapabilities, contains('codex_service_tiers_v1'));
    },
  );

  test('old Bridge messages leave the extended catalog empty', () {
    final message = ServerMessage.fromJson({
      'type': 'session_list',
      'sessions': <dynamic>[],
    }) as SessionListMessage;
    expect(message.codexModelServiceTierMetadata, isEmpty);
    expect(message.protocolCapabilities, isEmpty);
  });

  test('new and resumed session requests retain the selected wire tier', () {
    final start = ClientMessage.start('/project', serviceTier: 'ultrafast');
    final resume = ClientMessage.resumeSession(
      'thread',
      '/project',
      serviceTier: 'ultrafast',
    );
    final change = ClientMessage.setCodexSpeed(
      'ultrafast',
      sessionId: 'thread',
    );
    for (final message in [start, resume, change]) {
      expect((jsonDecode(message.toJson()) as Map)['serviceTier'], 'ultrafast');
    }
  });
}
