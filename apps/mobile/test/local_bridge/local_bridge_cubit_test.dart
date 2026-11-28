import 'package:ccpocket/features/local_bridge/data/local_bridge_client.dart';
import 'package:ccpocket/features/local_bridge/data/local_bridge_launcher.dart';
import 'package:ccpocket/features/local_bridge/state/local_bridge_cubit.dart';
import 'package:ccpocket/features/local_bridge/state/local_bridge_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'local_bridge_fakes.dart';

LocalBridgeCubit cubitFor(FakeLocalBridge bridge, {FakeLauncher? launcher}) =>
    LocalBridgeCubit(
      clientFactory: bridge.client,
      launcher: launcher ?? FakeLauncher(bridge, available: false),
      startTimeout: const Duration(milliseconds: 200),
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

  test('follows a saved port change across the restart', () async {
    final bridge = FakeLocalBridge()..envSettings = {};
    final cubit = cubitFor(bridge);
    await cubit.load();
    cubit.edit('port', 8770);
    expect(await cubit.save(), isTrue);
    expect(await cubit.restart(), isTrue);
    expect(cubit.state.port, 8770);
    expect(cubit.state.status!.port, 8770);
    expect(cubit.state.phase, LocalBridgePhase.ready);
    await cubit.close();
  });

  group('launcher', () {
    test('overlapping permission checks share one helper request', () async {
      final bridge = FakeLocalBridge();
      final launcher = FakeLauncher(bridge)
        ..registration = LauncherRegistration.enabled
        ..permissions = const LauncherPermissions(fullDiskAccess: false);
      final cubit = cubitFor(bridge, launcher: launcher);
      await cubit.load();
      await settle();
      expect(cubit.state.permissionsNeedAttention, isTrue);

      launcher
        ..actions.clear()
        ..delay = const Duration(milliseconds: 20)
        ..permissions = const LauncherPermissions(fullDiskAccess: true);
      // The card on the screen and the one in the dialog both ask.
      await Future.wait([
        cubit.refreshPermissions(),
        cubit.refreshPermissions(),
      ]);
      expect(launcher.actions, ['status']);
      expect(cubit.state.launcherPermissions?.fullDiskAccess, isTrue);
      expect(cubit.state.permissionsNeedAttention, isFalse);
      await cubit.close();
    });

    test('starts the Bridge from the app and can stop it again', () async {
      final bridge = FakeLocalBridge()..running = false;
      final launcher = FakeLauncher(bridge);
      final cubit = cubitFor(bridge, launcher: launcher);
      await cubit.load();
      expect(cubit.state.phase, LocalBridgePhase.notRunning);
      expect(cubit.state.canStart, isTrue);
      expect(cubit.state.managedByApp, isFalse);

      expect(await cubit.start(), isTrue);
      expect(cubit.state.phase, LocalBridgePhase.ready);
      expect(cubit.state.managedByApp, isTrue);
      expect(cubit.state.busy, LocalBridgeBusy.none);

      expect(await cubit.stop(), isTrue);
      expect(cubit.state.phase, LocalBridgePhase.notRunning);
      expect(cubit.state.managedByApp, isFalse);
      expect(launcher.actions, containsAllInOrder(['register', 'unregister']));
      await cubit.close();
    });

    test('reports a missing Node instead of waiting', () async {
      final bridge = FakeLocalBridge()..running = false;
      final launcher = FakeLauncher(bridge)
        ..problemOnStart = LauncherStatus(
          state: 'node_missing',
          updatedAt: DateTime(2026),
        );
      final cubit = cubitFor(bridge, launcher: launcher);
      await cubit.load();
      expect(await cubit.start(), isFalse);
      expect(cubit.state.launcherProblem, LauncherProblem.nodeMissing);
      expect(cubit.state.startFailed, isFalse);
      await cubit.close();
    });

    test('reports a failed npm install as a launcher problem', () async {
      final bridge = FakeLocalBridge()..running = false;
      final launcher = FakeLauncher(bridge)
        ..problemOnStart = LauncherStatus(
          state: 'install_failed',
          updatedAt: DateTime(2026),
        );
      final cubit = cubitFor(bridge, launcher: launcher);
      await cubit.load();
      expect(await cubit.start(), isFalse);
      expect(cubit.state.launcherProblem, LauncherProblem.installFailed);
      expect(cubit.state.startFailed, isFalse);
      await cubit.close();
    });

    test('asks for approval when the login item is turned off', () async {
      final bridge = FakeLocalBridge()..running = false;
      final launcher = FakeLauncher(bridge)..approvalRequired = true;
      final cubit = cubitFor(bridge, launcher: launcher);
      await cubit.load();
      expect(await cubit.start(), isFalse);
      expect(
        cubit.state.launcherRegistration,
        LauncherRegistration.requiresApproval,
      );
      expect(cubit.state.startFailed, isFalse);
      await cubit.close();
    });

    test('does not offer to start where the launcher is unavailable', () async {
      final bridge = FakeLocalBridge()..running = false;
      final cubit = cubitFor(bridge);
      await cubit.load();
      expect(cubit.state.canStart, isFalse);
      await cubit.close();
    });

    test('only offers to start on the port the launcher uses', () async {
      final bridge = FakeLocalBridge()..running = false;
      final cubit = cubitFor(bridge, launcher: FakeLauncher(bridge));
      await cubit.load();
      expect(cubit.state.canStart, isTrue);
      await cubit.setPort(8790);
      expect(cubit.state.canStart, isFalse);
      await cubit.close();
    });

    test('manages the port saved in the config file', () async {
      final bridge = FakeLocalBridge();
      final launcher = FakeLauncher(bridge)..savedPort = 8790;
      final cubit = cubitFor(bridge, launcher: launcher);
      await cubit.load();
      expect(cubit.state.port, 8790);
      expect(cubit.state.status!.port, 8790);
      await cubit.close();
    });
  });
}
