import 'package:ccpocket/features/local_bridge/data/local_bridge_client.dart';
import 'package:ccpocket/features/local_bridge/data/local_bridge_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'local_bridge_fakes.dart';

Matcher failsWith(LocalBridgeFailure failure) => throwsA(
  isA<LocalBridgeException>().having((e) => e.failure, 'failure', failure),
);

void main() {
  test('realHomeDirectory leaves the sandbox container', () {
    expect(
      realHomeDirectory({
        'HOME': '/Users/me/Library/Containers/com.k9i.ccpocket/Data',
      }),
      '/Users/me',
    );
    expect(realHomeDirectory({'HOME': '/Users/me'}), '/Users/me');
  });

  test('reads status, config and pairing with the pairing secret', () async {
    final bridge = FakeLocalBridge()
      ..loadedSettings = {'host': '127.0.0.1'}
      ..fileSettings = {'host': '127.0.0.1', 'antigravityApiKey': 'x'};
    final client = bridge.client(8765);

    final status = await client.status();
    expect(status.version, '1.120.0');
    expect(status.supervised, isTrue);
    expect(status.canRotateApiKey, isTrue);
    expect(status.restartRequired, isTrue);

    final config = await client.config();
    final port = config.setting('port')!;
    expect(port.lockedByEnv, isTrue);
    expect(port.effectiveValue, 8765);
    final host = config.setting('host')!;
    expect(host.source, LocalBridgeSettingSource.file);
    expect(host.effectiveValue, '127.0.0.1');
    final dirs = config.setting('allowedDirs')!;
    expect(dirs.type, LocalBridgeSettingType.dirs);
    expect(dirs.effectiveValue, ['/home/u']);
    expect(dirs.fileIsSet, isFalse);
    final secret = config.setting('antigravityApiKey')!;
    expect(secret.value, isNull);
    expect(secret.configured, isFalse);
    expect(secret.fileIsSet, isTrue);
    expect(config.setting('codexAppServerMode')!.values, hasLength(3));

    final pairing = await client.pairing();
    expect(pairing.authRequired, isTrue);
    expect(pairing.connections.map((c) => c.label), ['Tailscale', 'LAN']);
    expect(pairing.token, 'fixture-api-key');

    expect(
      bridge.requests.every(
        (r) =>
            r.headers[LocalBridgeClient.pairingSecretHeader] ==
                pairingFixture &&
            !r.headers.containsKey('Authorization'),
      ),
      isTrue,
    );
  });

  test('tells the failure modes apart', () async {
    final stopped = FakeLocalBridge()..running = false;
    await expectLater(
      stopped.client(8765).status(),
      failsWith(LocalBridgeFailure.notRunning),
    );
    expect(await stopped.client(8765).isRunning(), isFalse);

    final stoppedNoSecret = FakeLocalBridge()
      ..running = false
      ..hasSecret = false;
    await expectLater(
      stoppedNoSecret.client(8765).status(),
      failsWith(LocalBridgeFailure.notRunning),
    );

    final otherUser = FakeLocalBridge()..hasSecret = false;
    await expectLater(
      otherUser.client(8765).status(),
      failsWith(LocalBridgeFailure.secretUnavailable),
    );

    final old = FakeLocalBridge()..adminSupported = false;
    await expectLater(
      old.client(8765).status(),
      failsWith(LocalBridgeFailure.unsupported),
    );

    final manual = FakeLocalBridge()..supervised = false;
    await expectLater(
      manual.client(8765).restart(),
      failsWith(LocalBridgeFailure.notSupervised),
    );

    final envKey = FakeLocalBridge()..apiKeySource = 'configured';
    await expectLater(
      envKey.client(8765).rotateApiKey(),
      failsWith(LocalBridgeFailure.conflict),
    );
  });

  test('saves settings and reports rejected ones', () async {
    final bridge = FakeLocalBridge();
    final client = bridge.client(8765);
    final config = await client.saveSettings({
      'host': '127.0.0.1',
      'allowedDirs': ['/a'],
    });
    expect(config.restartRequired, isTrue);
    expect(config.setting('allowedDirs')!.fileValue, ['/a']);
    expect(bridge.fileSettings['host'], '127.0.0.1');

    bridge.rejectSettings = {'host': 'must be a single line'};
    await expectLater(
      client.saveSettings({'host': 'a\nb'}),
      throwsA(
        isA<LocalBridgeException>()
            .having(
              (e) => e.failure,
              'failure',
              LocalBridgeFailure.invalidSettings,
            )
            .having((e) => e.errors, 'errors', {
              'host': 'must be a single line',
            }),
      ),
    );
  });

  test('reads tools with the API key and logs with the secret', () async {
    final bridge = FakeLocalBridge();
    final client = bridge.client(8765);
    final tools = await client.tools(apiKey: 'fixture-api-key');
    expect(tools.ready, isFalse);
    expect(tools.tools.map((t) => t.id), ['node', 'codex', 'antigravity']);
    expect(tools.tools[0].installCommands.single.command, 'brew install node');
    expect(tools.tools[1].setupCommand, 'codex login');
    expect(tools.tools[1].requirement, LocalBridgeToolRequirement.agent);
    expect(tools.tools[2].installCommands, isEmpty);

    bridge.toolsSupported = false;
    await expectLater(
      client.tools(apiKey: 'fixture-api-key'),
      failsWith(LocalBridgeFailure.unsupported),
    );

    final logs = await client.logs();
    expect(logs.single.level, 'warn');
    expect(logs.single.message, 'careful');
  });
}
