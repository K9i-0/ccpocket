import 'dart:async';

import 'package:ccpocket/models/machine.dart';
import 'package:ccpocket/providers/machine_manager_cubit.dart';
import 'package:ccpocket/services/machine_manager_service.dart';
import 'package:ccpocket/services/ssh_startup_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal mock for MachineManagerService.
class MockMachineManagerService implements MachineManagerService {
  final _controller = StreamController<List<MachineWithStatus>>.broadcast();
  final List<String> calls = [];

  bool initShouldFail = false;
  bool checkAllHealthShouldFail = false;
  bool addMachineShouldFail = false;
  bool updateMachineShouldFail = false;
  bool deleteMachineShouldFail = false;

  final Map<String, Machine> _machines = {};

  @override
  Stream<List<MachineWithStatus>> get machines => _controller.stream;

  void emitMachines(List<MachineWithStatus> list) => _controller.add(list);

  @override
  Future<void> init() async {
    calls.add('init');
    if (initShouldFail) throw Exception('init failed');
  }

  @override
  Future<void> checkAllHealth() async {
    calls.add('checkAllHealth');
    if (checkAllHealthShouldFail) throw Exception('checkAllHealth failed');
  }

  @override
  Future<MachineStatus> checkHealth(String machineId) async {
    calls.add('checkHealth:$machineId');
    return MachineStatus.online;
  }

  @override
  Future<Machine> recordConnection({
    required String host,
    required int port,
    String? apiKey,
    String? name,
  }) async {
    calls.add('recordConnection:$host:$port');
    return Machine(id: 'new-id', host: host, port: port, name: name);
  }

  @override
  Future<void> addMachine(
    Machine machine, {
    String? apiKey,
    String? sshPassword,
    String? sshPrivateKey,
  }) async {
    calls.add('addMachine:${machine.id}');
    if (addMachineShouldFail) throw Exception('addMachine failed');
    _machines[machine.id] = machine;
  }

  @override
  Future<void> updateMachine(
    Machine machine, {
    String? apiKey,
    String? sshPassword,
    String? sshPrivateKey,
    bool clearApiKey = false,
    bool clearCredentials = false,
  }) async {
    calls.add('updateMachine:${machine.id}');
    if (updateMachineShouldFail) throw Exception('updateMachine failed');
    _machines[machine.id] = machine;
  }

  @override
  Future<void> deleteMachine(String id) async {
    calls.add('deleteMachine:$id');
    if (deleteMachineShouldFail) throw Exception('deleteMachine failed');
    _machines.remove(id);
  }

  @override
  Future<void> toggleFavorite(String machineId) async {
    calls.add('toggleFavorite:$machineId');
  }

  @override
  Machine? getMachine(String id) => _machines[id];

  @override
  Future<String?> getApiKey(String machineId) async => null;

  @override
  Future<String?> getSshPassword(String machineId) async => null;

  @override
  Future<String?> getSshPrivateKey(String machineId) async => null;

  @override
  Future<String> buildWsUrl(String machineId) async => 'ws://mock:8765';

  @override
  Machine createNew({String? name, required String host, int port = 8765}) {
    return Machine(id: 'gen-id', name: name, host: host, port: port);
  }

  @override
  void startPeriodicHealthCheck({Duration? interval}) {
    calls.add('startPeriodicHealthCheck');
  }

  @override
  void stopPeriodicHealthCheck() {
    calls.add('stopPeriodicHealthCheck');
  }

  @override
  List<Machine> get currentMachines => _machines.values.toList();

  @override
  List<MachineWithStatus> get machinesWithStatus => [];

  @override
  Machine? findByHostPort(String host, int port) => null;

  @override
  void dispose() {
    _controller.close();
  }
}

/// Minimal mock for SshStartupService.
class MockSshStartupService implements SshStartupService {
  SshResult? startResult;
  SshResult? stopResult;
  SshResult? updateResult;
  SshResult? testResult;
  SshResult? testWithCredResult;

  @override
  Future<SshResult> startBridgeServer(
    String machineId, {
    String? password,
    Future<String?> Function()? promptForPassword,
  }) async {
    return startResult ?? SshResult.success();
  }

  @override
  Future<SshResult> stopBridgeServer(
    String machineId, {
    String? password,
  }) async {
    return stopResult ?? SshResult.success();
  }

  @override
  Future<SshResult> updateBridgeServer(
    String machineId, {
    String? password,
    Future<String?> Function()? promptForPassword,
  }) async {
    return updateResult ?? SshResult.success();
  }

  @override
  Future<SshResult> testConnection(
    String machineId, {
    String? password,
    String? privateKey,
  }) async {
    return testResult ?? SshResult.success();
  }

  @override
  Future<SshResult> testConnectionWithCredentials({
    required String host,
    required int sshPort,
    required String username,
    required SshAuthType authType,
    String? password,
    String? privateKey,
  }) async {
    return testWithCredResult ?? SshResult.success();
  }
}

void main() {
  late MockMachineManagerService mockService;
  late MockSshStartupService mockSsh;

  setUp(() {
    mockService = MockMachineManagerService();
    mockSsh = MockSshStartupService();
  });

  tearDown(() {
    mockService.dispose();
  });

  MachineManagerCubit createCubit({bool withSsh = true}) {
    return MachineManagerCubit(mockService, withSsh ? mockSsh : null);
  }

  group('MachineManagerCubit - initial state', () {
    test('has default empty state', () {
      final cubit = createCubit();
      addTearDown(cubit.close);

      expect(cubit.state.machines, isEmpty);
      // isLoading is true because the constructor calls init() which sets it
      expect(cubit.state.isLoading, true);
      expect(cubit.state.error, isNull);
      expect(cubit.state.startingMachineId, isNull);
      expect(cubit.state.updatingMachineId, isNull);
      expect(cubit.state.successMessage, isNull);
    });

    test('calls init on creation', () async {
      final cubit = createCubit();
      addTearDown(cubit.close);
      await Future.microtask(() {});

      expect(mockService.calls, contains('init'));
    });

    test('sshAvailable returns true when ssh service provided', () {
      final cubit = createCubit(withSsh: true);
      addTearDown(cubit.close);

      expect(cubit.sshAvailable, true);
    });

    test('sshAvailable returns false when ssh service is null', () {
      final cubit = createCubit(withSsh: false);
      addTearDown(cubit.close);

      expect(cubit.sshAvailable, false);
    });
  });

  group('MachineManagerCubit - stream updates', () {
    test('updates machines from service stream', () async {
      final cubit = createCubit();
      addTearDown(cubit.close);
      await Future.microtask(() {});

      final machine = Machine(id: 'm1', host: '192.168.1.1', port: 8765);
      mockService.emitMachines([MachineWithStatus(machine: machine)]);
      await Future.microtask(() {});

      expect(cubit.state.machines, hasLength(1));
      expect(cubit.state.machines.first.machine.id, 'm1');
      expect(cubit.state.isLoading, false);
    });
  });

  group('MachineManagerCubit - init', () {
    test('sets error on init failure', () async {
      mockService.initShouldFail = true;
      final cubit = createCubit();
      addTearDown(cubit.close);

      // Wait for the auto-init to complete
      await Future.delayed(const Duration(milliseconds: 50));

      expect(cubit.state.error, contains('init failed'));
      expect(cubit.state.isLoading, false);
    });
  });

  group('MachineManagerCubit - refreshAll', () {
    test('calls checkAllHealth', () async {
      final cubit = createCubit();
      addTearDown(cubit.close);
      await Future.microtask(() {});

      mockService.calls.clear();
      await cubit.refreshAll();

      expect(mockService.calls, contains('checkAllHealth'));
    });

    test('sets error on failure', () async {
      final cubit = createCubit();
      addTearDown(cubit.close);
      await Future.microtask(() {});

      mockService.checkAllHealthShouldFail = true;
      await cubit.refreshAll();

      expect(cubit.state.error, contains('checkAllHealth failed'));
    });
  });

  group('MachineManagerCubit - addMachine', () {
    test('adds machine successfully', () async {
      final cubit = createCubit();
      addTearDown(cubit.close);
      await Future.microtask(() {});

      final machine = Machine(id: 'm1', host: '10.0.0.1', port: 8765);
      await cubit.addMachine(machine);

      expect(cubit.state.successMessage, 'Machine added successfully');
      expect(cubit.state.error, isNull);
      expect(mockService.calls, contains('addMachine:m1'));
    });

    test('sets error on failure', () async {
      final cubit = createCubit();
      addTearDown(cubit.close);
      await Future.microtask(() {});

      mockService.addMachineShouldFail = true;
      final machine = Machine(id: 'm1', host: '10.0.0.1', port: 8765);
      await cubit.addMachine(machine);

      expect(cubit.state.error, contains('addMachine failed'));
      expect(cubit.state.successMessage, isNull);
    });
  });

  group('MachineManagerCubit - updateMachine', () {
    test('updates machine successfully', () async {
      final cubit = createCubit();
      addTearDown(cubit.close);
      await Future.microtask(() {});

      final machine = Machine(id: 'm1', host: '10.0.0.1', port: 8765);
      await cubit.updateMachine(machine);

      expect(cubit.state.successMessage, 'Machine updated successfully');
      expect(cubit.state.error, isNull);
    });

    test('sets error on failure', () async {
      final cubit = createCubit();
      addTearDown(cubit.close);
      await Future.microtask(() {});

      mockService.updateMachineShouldFail = true;
      final machine = Machine(id: 'm1', host: '10.0.0.1', port: 8765);
      await cubit.updateMachine(machine);

      expect(cubit.state.error, contains('updateMachine failed'));
    });
  });

  group('MachineManagerCubit - deleteMachine', () {
    test('deletes machine successfully', () async {
      final cubit = createCubit();
      addTearDown(cubit.close);
      await Future.microtask(() {});

      await cubit.deleteMachine('m1');

      expect(cubit.state.successMessage, 'Machine deleted');
      expect(mockService.calls, contains('deleteMachine:m1'));
    });

    test('sets error on failure', () async {
      final cubit = createCubit();
      addTearDown(cubit.close);
      await Future.microtask(() {});

      mockService.deleteMachineShouldFail = true;
      await cubit.deleteMachine('m1');

      expect(cubit.state.error, contains('deleteMachine failed'));
    });
  });

  group('MachineManagerCubit - clearMessages', () {
    test('clears error and success message', () async {
      final cubit = createCubit();
      addTearDown(cubit.close);
      await Future.microtask(() {});

      // Create an error state
      mockService.addMachineShouldFail = true;
      await cubit.addMachine(Machine(id: 'm1', host: '10.0.0.1', port: 8765));
      expect(cubit.state.error, isNotNull);

      cubit.clearMessages();

      expect(cubit.state.error, isNull);
      expect(cubit.state.successMessage, isNull);
    });
  });

  group('MachineManagerCubit - SSH operations without SSH service', () {
    test('startBridge returns false and sets error', () async {
      final cubit = createCubit(withSsh: false);
      addTearDown(cubit.close);
      await Future.microtask(() {});

      final result = await cubit.startBridge('m1');

      expect(result, false);
      expect(cubit.state.error, 'SSH not available on this platform');
    });

    test('stopBridge returns false and sets error', () async {
      final cubit = createCubit(withSsh: false);
      addTearDown(cubit.close);
      await Future.microtask(() {});

      final result = await cubit.stopBridge('m1');

      expect(result, false);
      expect(cubit.state.error, 'SSH not available on this platform');
    });

    test('updateBridge returns false and sets error', () async {
      final cubit = createCubit(withSsh: false);
      addTearDown(cubit.close);
      await Future.microtask(() {});

      final result = await cubit.updateBridge('m1');

      expect(result, false);
      expect(cubit.state.error, 'SSH not available on this platform');
    });

    test('testConnection returns failure result', () async {
      final cubit = createCubit(withSsh: false);
      addTearDown(cubit.close);

      final result = await cubit.testConnection('m1');

      expect(result.success, false);
      expect(result.error, 'SSH not available on this platform');
    });

    test('testConnectionWithCredentials returns failure result', () async {
      final cubit = createCubit(withSsh: false);
      addTearDown(cubit.close);

      final result = await cubit.testConnectionWithCredentials(
        host: '10.0.0.1',
        sshPort: 22,
        username: 'user',
        authType: SshAuthType.password,
      );

      expect(result.success, false);
      expect(result.error, 'SSH not available on this platform');
    });
  });

  group('MachineManagerCubit - recordConnection', () {
    test('delegates to service', () async {
      final cubit = createCubit();
      addTearDown(cubit.close);
      await Future.microtask(() {});

      final machine = await cubit.recordConnection(
        host: '10.0.0.1',
        port: 8765,
      );

      expect(machine.host, '10.0.0.1');
      expect(mockService.calls, contains('recordConnection:10.0.0.1:8765'));
    });
  });

  group('MachineManagerCubit - utility methods', () {
    test('getMachine delegates to service', () async {
      final cubit = createCubit();
      addTearDown(cubit.close);

      expect(cubit.getMachine('nonexistent'), isNull);
    });

    test('createNewMachine delegates to service', () async {
      final cubit = createCubit();
      addTearDown(cubit.close);

      final machine = cubit.createNewMachine(host: '10.0.0.1');

      expect(machine.host, '10.0.0.1');
      expect(machine.port, 8765);
    });

    test('startPeriodicHealthCheck delegates to service', () {
      final cubit = createCubit();
      addTearDown(cubit.close);

      cubit.startPeriodicHealthCheck();

      expect(mockService.calls, contains('startPeriodicHealthCheck'));
    });

    test('stopPeriodicHealthCheck delegates to service', () {
      final cubit = createCubit();
      addTearDown(cubit.close);

      cubit.stopPeriodicHealthCheck();

      expect(mockService.calls, contains('stopPeriodicHealthCheck'));
    });
  });
}
