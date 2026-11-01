import 'dart:async';

import 'package:ccpocket/models/machine.dart';
import 'package:ccpocket/services/bridge_endpoint_probe.dart';
import 'package:ccpocket/services/machine_manager_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('automatic mode detects a standard Bridge and stores WS', () async {
    final prefs = await SharedPreferences.getInstance();
    final probe = _StaticProbe(
      const BridgeEndpointProbeResult.reachable(BridgeTransport.standard, {
        'status': 'ok',
      }),
    );
    final manager = MachineManagerService(
      prefs,
      const FlutterSecureStorage(),
      endpointProbe: probe,
    );
    addTearDown(manager.dispose);

    await manager.addMachine(
      Machine(id: 'automatic', host: '127.0.0.1', port: 8765, useSsl: true),
    );

    final stored = manager.getMachine('automatic');
    expect(stored, isNotNull);
    expect(stored!.connectionMode, BridgeConnectionMode.automatic);
    expect(stored.hasResolvedTransport, isTrue);
    expect(stored.useSsl, isFalse);
    expect(stored.wsUrl, 'ws://127.0.0.1:8765');
    expect(manager.machinesWithStatus.single.status, MachineStatus.online);

    await manager.checkHealth('automatic');
    expect(probe.modes, [
      BridgeConnectionMode.automatic,
      BridgeConnectionMode.standardOnly,
    ]);
  });

  test('secure-only mode never downgrades to an available WS Bridge', () async {
    final prefs = await SharedPreferences.getInstance();
    final manager = MachineManagerService(prefs, const FlutterSecureStorage());
    addTearDown(manager.dispose);

    await manager.addMachine(
      Machine(
        id: 'secure-only',
        host: '127.0.0.1',
        port: 8765,
        useSsl: true,
        connectionMode: BridgeConnectionMode.secureOnly,
      ),
    );

    final status = manager.machinesWithStatus.single;
    expect(status.machine.useSsl, isTrue);
    expect(status.status, isNot(MachineStatus.online));
    expect(status.lastError, machineErrorSecureConnectionUnavailable);
  });

  test(
    'automatic mode never downgrades a previously secure endpoint',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final probe = _StaticProbe(const BridgeEndpointProbeResult.unreachable());
      final manager = MachineManagerService(
        prefs,
        const FlutterSecureStorage(),
        endpointProbe: probe,
      );
      addTearDown(manager.dispose);

      await manager.addMachine(
        const Machine(
          id: 'pinned-secure',
          host: 'bridge.example.com',
          useSsl: true,
          connectionMode: BridgeConnectionMode.automatic,
          hasResolvedTransport: true,
        ),
      );

      expect(probe.modes, [BridgeConnectionMode.secureOnly]);
      final status = manager.machinesWithStatus.single;
      expect(status.machine.useSsl, isTrue);
      expect(status.lastError, machineErrorSecureConnectionUnavailable);
    },
  );

  test(
    'an in-flight probe does not overwrite a newer connection policy',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final probe = _ControllableProbe();
      final manager = MachineManagerService(
        prefs,
        const FlutterSecureStorage(),
        endpointProbe: probe,
      );
      addTearDown(manager.dispose);

      await manager.addMachine(
        const Machine(id: 'race', host: 'bridge.example.com'),
      );
      probe.pauseNext();
      final checking = manager.checkHealth('race');
      await probe.started.future;

      await manager.recordConnection(
        host: 'bridge.example.com',
        port: 8765,
        useSsl: true,
        connectionMode: BridgeConnectionMode.secureOnly,
      );
      probe.release();
      await checking;

      final stored = manager.getMachine('race')!;
      expect(stored.connectionMode, BridgeConnectionMode.secureOnly);
      expect(stored.useSsl, isTrue);
    },
  );

  test(
    'markConnected clears a stale health-check error after WS connect',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final probe = _StaticProbe(const BridgeEndpointProbeResult.unreachable());
      final manager = MachineManagerService(
        prefs,
        const FlutterSecureStorage(),
        endpointProbe: probe,
      );
      addTearDown(manager.dispose);

      await manager.addMachine(
        const Machine(id: 'stale', host: 'bridge.example.com', port: 8765),
      );
      final failed = manager.machinesWithStatus.single;
      expect(failed.status, isNot(MachineStatus.online));
      expect(failed.lastError, isNotNull);

      manager.markConnected('Bridge.Example.com', 8765);

      final recovered = manager.machinesWithStatus.single;
      expect(recovered.status, MachineStatus.online);
      expect(recovered.lastError, isNull);
    },
  );

  test('markConnected ignores endpoints without a saved machine', () async {
    final prefs = await SharedPreferences.getInstance();
    final probe = _StaticProbe(const BridgeEndpointProbeResult.unreachable());
    final manager = MachineManagerService(
      prefs,
      const FlutterSecureStorage(),
      endpointProbe: probe,
    );
    addTearDown(manager.dispose);

    await manager.addMachine(
      const Machine(id: 'other', host: 'bridge.example.com', port: 8765),
    );

    manager.markConnected('bridge.example.com', 9999);

    final status = manager.machinesWithStatus.single;
    expect(status.status, isNot(MachineStatus.online));
    expect(status.lastError, isNotNull);
  });

  test('automatic mode uses WS inside an SSH jump-host tunnel', () async {
    final prefs = await SharedPreferences.getInstance();
    final manager = MachineManagerService(prefs, const FlutterSecureStorage());
    addTearDown(manager.dispose);

    await manager.addMachine(
      const Machine(
        id: 'ssh-jump',
        host: 'bridge.internal',
        useSsl: true,
        connectionMode: BridgeConnectionMode.automatic,
        sshEnabled: true,
        sshJumpHost: 'jump.example.com',
      ),
    );

    final stored = manager.getMachine('ssh-jump')!;
    expect(stored.useSsl, isFalse);
    expect(stored.hasResolvedTransport, isTrue);
  });
}

class _StaticProbe extends BridgeEndpointProbe {
  final BridgeEndpointProbeResult result;
  final modes = <BridgeConnectionMode>[];

  _StaticProbe(this.result);

  @override
  Future<BridgeEndpointProbeResult> probe({
    required String host,
    required int port,
    required BridgeConnectionMode mode,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    modes.add(mode);
    return result;
  }
}

class _ControllableProbe extends BridgeEndpointProbe {
  Completer<void>? _gate;
  Completer<void> started = Completer<void>();

  void pauseNext() {
    _gate = Completer<void>();
    started = Completer<void>();
  }

  void release() => _gate?.complete();

  @override
  Future<BridgeEndpointProbeResult> probe({
    required String host,
    required int port,
    required BridgeConnectionMode mode,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final gate = _gate;
    if (gate != null) {
      if (!started.isCompleted) started.complete();
      await gate.future;
      _gate = null;
    }
    return const BridgeEndpointProbeResult.reachable(BridgeTransport.standard, {
      'status': 'ok',
    });
  }
}
