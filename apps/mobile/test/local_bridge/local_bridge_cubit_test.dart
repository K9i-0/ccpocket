import 'package:ccpocket/features/local_bridge/data/local_bridge_client.dart';
import 'package:ccpocket/features/local_bridge/state/local_bridge_cubit.dart';
import 'package:ccpocket/features/local_bridge/state/local_bridge_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'local_bridge_fakes.dart';

LocalBridgeCubit cubitFor(FakeLocalBridge bridge) => LocalBridgeCubit(
  clientFactory: bridge.client,
  restartPollInterval: const Duration(milliseconds: 1),
  restartTimeout: const Duration(milliseconds: 200),
);

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 5));

void main() {
  test('loads status, settings, pairing and then tools', () async {
    final cubit = cubitFor(FakeLocalBridge());
    await cubit.load();
    await settle();
    expect(cubit.state.phase, LocalBridgePhase.ready);
    expect(cubit.state.status!.version, '1.120.0');
    expect(cubit.state.pairing!.connections, hasLength(2));
    expect(cubit.state.tools!.tools, hasLength(3));
    expect(cubit.state.toolsLoading, isFalse);
    await cubit.close();
  });

  test('maps failures to phases', () async {
    Future<LocalBridgePhase> phaseOf(FakeLocalBridge bridge) async {
      final cubit = cubitFor(bridge);
      await cubit.load();
      final phase = cubit.state.phase;
      await cubit.close();
      return phase;
    }

    expect(
      await phaseOf(FakeLocalBridge()..running = false),
      LocalBridgePhase.notRunning,
    );
    expect(
      await phaseOf(FakeLocalBridge()..hasSecret = false),
      LocalBridgePhase.secretUnavailable,
    );
    expect(
      await phaseOf(FakeLocalBridge()..adminSupported = false),
      LocalBridgePhase.updateRequired,
    );
  });

  test('marks tools unsupported on an older Bridge', () async {
    final cubit = cubitFor(FakeLocalBridge()..toolsSupported = false);
    await cubit.load();
    await settle();
    expect(cubit.state.phase, LocalBridgePhase.ready);
    expect(cubit.state.toolsUnsupported, isTrue);
    expect(cubit.state.tools, isNull);
    await cubit.close();
  });

  test('stages edits, ignores locked settings and drops no-op edits', () async {
    final bridge = FakeLocalBridge()
      ..fileSettings = {'host': '127.0.0.1'}
      ..loadedSettings = {'host': '127.0.0.1'};
    final cubit = cubitFor(bridge);
    await cubit.load();

    cubit.edit('port', 9000); // locked by env
    expect(cubit.state.hasEdits, isFalse);

    cubit.edit('host', '0.0.0.0');
    cubit.edit('allowedDirs', ['/a']);
    expect(cubit.state.edits, {
      'host': '0.0.0.0',
      'allowedDirs': ['/a'],
    });
    final host = cubit.state.config!.setting('host')!;
    expect(cubit.state.displayValue(host), '0.0.0.0');

    cubit.edit('host', '127.0.0.1'); // back to the saved value
    cubit.edit('allowedDirs', null); // not in the file anyway
    expect(cubit.state.hasEdits, isFalse);

    cubit.edit('host', null); // remove a saved value
    expect(cubit.state.edits, {'host': null});
    cubit.discardEdits();
    expect(cubit.state.hasEdits, isFalse);
    await cubit.close();
  });

  test('saves edits, then restarts to apply them', () async {
    final bridge = FakeLocalBridge();
    final cubit = cubitFor(bridge);
    await cubit.load();
    cubit.edit('allowClaudeOAuth', true);
    cubit.edit('antigravityApiKey', 'fixture-key');

    expect(await cubit.save(), isTrue);
    expect(cubit.state.hasEdits, isFalse);
    expect(cubit.state.restartRequired, isTrue);
    expect(bridge.fileSettings, {
      'allowClaudeOAuth': true,
      'antigravityApiKey': 'fixture-key',
    });

    expect(await cubit.restart(), isTrue);
    expect(cubit.state.busy, LocalBridgeBusy.none);
    expect(cubit.state.status!.pid, 101);
    expect(cubit.state.restartRequired, isFalse);
    expect(cubit.state.config!.setting('allowClaudeOAuth')!.value, isTrue);
    await cubit.close();
  });

  test('keeps edits and shows errors when the Bridge rejects them', () async {
    final bridge = FakeLocalBridge()..rejectSettings = {'host': 'bad'};
    final cubit = cubitFor(bridge);
    await cubit.load();
    cubit.edit('host', 'x');
    expect(await cubit.save(), isFalse);
    expect(cubit.state.edits, {'host': 'x'});
    expect(cubit.state.settingErrors, {'host': 'bad'});
    expect(cubit.state.actionFailure, LocalBridgeFailure.invalidSettings);

    cubit.edit('host', 'y');
    expect(cubit.state.settingErrors, isEmpty);
    await cubit.close();
  });

  test('reports a refused restart and a rotated API key', () async {
    final bridge = FakeLocalBridge()..supervised = false;
    final cubit = cubitFor(bridge);
    await cubit.load();
    expect(await cubit.restart(), isFalse);
    expect(cubit.state.actionFailure, LocalBridgeFailure.notSupervised);
    cubit.clearActionFailure();
    expect(cubit.state.actionFailure, isNull);

    expect(await cubit.rotateApiKey(), isTrue);
    expect(cubit.state.restartRequired, isTrue);
    await cubit.close();
  });

  test('switches to another port', () async {
    final bridge = FakeLocalBridge();
    final cubit = cubitFor(bridge);
    await cubit.load();
    cubit.edit('host', 'x');
    await cubit.setPort(8770);
    expect(cubit.state.port, 8770);
    expect(cubit.state.hasEdits, isFalse);
    expect(cubit.state.status!.port, 8770);
    await cubit.close();
  });
}
