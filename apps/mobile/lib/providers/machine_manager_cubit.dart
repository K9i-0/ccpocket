import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../constants/app_constants.dart';
import '../models/machine.dart';
import '../services/bridge_latest_version_service.dart';
import '../services/machine_manager_service.dart';
import '../services/ssh_startup_service.dart';

part 'machine_manager_cubit.freezed.dart';

/// State for the machine manager
@freezed
abstract class MachineManagerState with _$MachineManagerState {
  const factory MachineManagerState({
    /// List of machines with their current status
    @Default([]) List<MachineWithStatus> machines,

    /// Whether we're loading/refreshing
    @Default(false) bool isLoading,

    /// ID of machine currently being started
    String? startingMachineId,

    /// ID of machine currently being updated
    String? updatingMachineId,

    /// Latest Bridge version published to npm.
    String? latestBridgeVersion,

    /// Whether the latest Bridge version is being checked.
    @Default(false) bool isCheckingLatestBridgeVersion,

    /// Error message from the latest version check, if any.
    String? latestBridgeVersionError,

    /// Error message if any
    String? error,

    /// Success message if any
    String? successMessage,
  }) = _MachineManagerState;
}

/// Cubit for managing remote machines
class MachineManagerCubit extends Cubit<MachineManagerState> {
  final MachineManagerService _service;
  final SshStartupService? _sshService;
  final BridgeLatestVersionService _latestVersionService;
  final bool _ownsLatestVersionService;
  final Duration _startHealthTimeout;
  final Duration _updateHealthTimeout;
  final Duration _healthRetryDelay;
  final Duration _postStartHealthRequestTimeout;
  StreamSubscription? _machinesSub;

  static const _defaultStartHealthTimeout = Duration(seconds: 20);
  static const _defaultUpdateHealthTimeout = Duration(seconds: 30);
  static const _defaultHealthRetryDelay = Duration(seconds: 1);
  static const _defaultPostStartHealthRequestTimeout = Duration(seconds: 2);
  static const _latestBridgeVersionAutoRefreshMinInterval =
      BridgeLatestVersionService.cacheDuration;

  DateTime? _lastLatestBridgeVersionRefreshAttemptAt;

  MachineManagerCubit(
    this._service,
    this._sshService, {
    BridgeLatestVersionService? latestVersionService,
    bool refreshLatestBridgeVersionOnInit = false,
    Duration? healthTimeout,
    Duration? startHealthTimeout,
    Duration? updateHealthTimeout,
    Duration healthRetryDelay = _defaultHealthRetryDelay,
    Duration postStartHealthRequestTimeout =
        _defaultPostStartHealthRequestTimeout,
  }) : _latestVersionService =
           latestVersionService ?? BridgeLatestVersionService(),
       _ownsLatestVersionService = latestVersionService == null,
       _startHealthTimeout =
           startHealthTimeout ?? healthTimeout ?? _defaultStartHealthTimeout,
       _updateHealthTimeout =
           updateHealthTimeout ?? healthTimeout ?? _defaultUpdateHealthTimeout,
       _healthRetryDelay = healthRetryDelay,
       _postStartHealthRequestTimeout = postStartHealthRequestTimeout,
       super(const MachineManagerState()) {
    _machinesSub = _service.machines.listen((machines) {
      emit(state.copyWith(machines: machines, isLoading: false));
    });
    // Auto-init on creation
    init();
    if (refreshLatestBridgeVersionOnInit) {
      unawaited(refreshLatestBridgeVersion());
    }
  }

  /// Whether SSH features are available (not available on web)
  bool get sshAvailable => _sshService != null;

  /// Initialize and load machines
  Future<void> init() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      await _service.init();
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  /// Refresh all machine statuses
  Future<void> refreshAll() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      await _service.checkAllHealth();
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  /// Refresh the latest Bridge version published on npm.
  Future<void> refreshLatestBridgeVersion({bool forceRefresh = false}) async {
    _lastLatestBridgeVersionRefreshAttemptAt = DateTime.now();
    emit(
      state.copyWith(
        isCheckingLatestBridgeVersion: true,
        latestBridgeVersionError: null,
      ),
    );
    try {
      final version = await _latestVersionService.fetchLatestVersion(
        forceRefresh: forceRefresh,
      );
      emit(
        state.copyWith(
          latestBridgeVersion: version,
          isCheckingLatestBridgeVersion: false,
          latestBridgeVersionError: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isCheckingLatestBridgeVersion: false,
          latestBridgeVersionError: e.toString(),
        ),
      );
    }
  }

  /// Refresh npm latest version when the cached value is stale.
  ///
  /// This is intended for automatic UI-triggered checks, such as opening
  /// settings or pressing connect. Manual retry should use
  /// [refreshLatestBridgeVersion] with forceRefresh.
  Future<void> refreshLatestBridgeVersionIfStale() async {
    if (state.isCheckingLatestBridgeVersion) return;
    if (_latestVersionService.hasFreshCache &&
        state.latestBridgeVersion != null) {
      return;
    }

    final lastAttempt = _lastLatestBridgeVersionRefreshAttemptAt;
    if (lastAttempt != null &&
        DateTime.now().difference(lastAttempt) <
            _latestBridgeVersionAutoRefreshMinInterval) {
      return;
    }

    await refreshLatestBridgeVersion();
  }

  /// Version used to decide whether an update should be offered.
  String get bridgeUpdateTargetVersion {
    final latest = state.latestBridgeVersion;
    if (latest == null) return AppConstants.expectedBridgeVersion;
    return compareSemanticVersions(latest, AppConstants.expectedBridgeVersion) >
            0
        ? latest
        : AppConstants.expectedBridgeVersion;
  }

  bool bridgeNeedsUpdate(BridgeVersionInfo? versionInfo) {
    if (versionInfo == null) return false;
    return versionInfo.needsUpdate(bridgeUpdateTargetVersion);
  }

  /// Check health of a specific machine
  Future<void> checkHealth(String machineId) async {
    await _service.checkHealth(machineId);
  }

  /// Record a connection (auto-save on connect)
  Future<Machine> recordConnection({
    required String host,
    required int port,
    String? apiKey,
    String? name,
    bool? useSsl,
  }) async {
    return await _service.recordConnection(
      host: host,
      port: port,
      apiKey: apiKey,
      name: name,
      useSsl: useSsl,
    );
  }

  /// Add a new machine
  Future<void> addMachine(
    Machine machine, {
    String? apiKey,
    String? sshPassword,
    String? sshPrivateKey,
  }) async {
    emit(state.copyWith(error: null, successMessage: null));
    try {
      await _service.addMachine(
        machine,
        apiKey: apiKey,
        sshPassword: sshPassword,
        sshPrivateKey: sshPrivateKey,
      );
      emit(state.copyWith(successMessage: 'Machine added successfully'));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  /// Update an existing machine
  Future<void> updateMachine(
    Machine machine, {
    String? apiKey,
    String? sshPassword,
    String? sshPrivateKey,
    bool clearApiKey = false,
    bool clearCredentials = false,
  }) async {
    emit(state.copyWith(error: null, successMessage: null));
    try {
      await _service.updateMachine(
        machine,
        apiKey: apiKey,
        sshPassword: sshPassword,
        sshPrivateKey: sshPrivateKey,
        clearApiKey: clearApiKey,
        clearCredentials: clearCredentials,
      );
      emit(state.copyWith(successMessage: 'Machine updated successfully'));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  /// Delete a machine
  Future<void> deleteMachine(String machineId) async {
    emit(state.copyWith(error: null, successMessage: null));
    try {
      await _service.deleteMachine(machineId);
      emit(state.copyWith(successMessage: 'Machine deleted'));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  /// Toggle favorite status for a machine
  Future<void> toggleFavorite(String machineId) async {
    await _service.toggleFavorite(machineId);
  }

  /// Start Bridge Server on a machine via SSH
  Future<bool> startBridge(
    String machineId, {
    String? password,
    Future<String?> Function()? promptForPassword,
  }) async {
    if (_sshService == null) {
      emit(state.copyWith(error: 'SSH not available on this platform'));
      return false;
    }

    emit(
      state.copyWith(
        startingMachineId: machineId,
        error: null,
        successMessage: null,
      ),
    );

    try {
      final result = await _sshService.startBridgeServer(
        machineId,
        password: password,
        promptForPassword: promptForPassword,
      );

      if (result.success) {
        final status = await _waitForOnline(
          machineId,
          timeout: _startHealthTimeout,
        );

        if (status == MachineStatus.online) {
          emit(
            state.copyWith(
              startingMachineId: null,
              successMessage: 'Bridge Server started',
            ),
          );
          return true;
        } else {
          emit(
            state.copyWith(
              startingMachineId: null,
              error: 'Server process started but health check failed',
            ),
          );
          return false;
        }
      } else {
        emit(
          state.copyWith(
            startingMachineId: null,
            error: result.error ?? 'Failed to start',
          ),
        );
        return false;
      }
    } catch (e) {
      emit(state.copyWith(startingMachineId: null, error: e.toString()));
      return false;
    }
  }

  Future<MachineStatus> _waitForOnline(
    String machineId, {
    required Duration timeout,
  }) async {
    final deadline = DateTime.now().add(timeout);
    var status = await _service.checkHealth(
      machineId,
      timeout: _postStartHealthRequestTimeout,
    );

    while (status != MachineStatus.online &&
        DateTime.now().isBefore(deadline)) {
      await Future.delayed(_healthRetryDelay);
      status = await _service.checkHealth(
        machineId,
        timeout: _postStartHealthRequestTimeout,
      );
    }

    return status;
  }

  /// Stop Bridge Server on a machine via SSH
  Future<bool> stopBridge(String machineId, {String? password}) async {
    if (_sshService == null) {
      emit(state.copyWith(error: 'SSH not available on this platform'));
      return false;
    }

    emit(state.copyWith(error: null, successMessage: null));

    try {
      final result = await _sshService.stopBridgeServer(
        machineId,
        password: password,
      );

      if (result.success) {
        // Wait a moment for the server to stop
        await Future.delayed(const Duration(seconds: 1));
        // Check health to update status
        await _service.checkHealth(machineId);

        emit(state.copyWith(successMessage: 'Bridge Server stopped'));
        return true;
      } else {
        emit(state.copyWith(error: result.error ?? 'Failed to stop'));
        return false;
      }
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
      return false;
    }
  }

  /// Update Bridge Server on a machine via SSH
  Future<bool> updateBridge(
    String machineId, {
    String? password,
    Future<String?> Function()? promptForPassword,
  }) async {
    if (_sshService == null) {
      emit(state.copyWith(error: 'SSH not available on this platform'));
      return false;
    }

    emit(
      state.copyWith(
        updatingMachineId: machineId,
        error: null,
        successMessage: null,
      ),
    );

    try {
      final result = await _sshService.updateBridgeServer(
        machineId,
        password: password,
        promptForPassword: promptForPassword,
      );

      if (result.success) {
        final status = await _waitForOnline(
          machineId,
          timeout: _updateHealthTimeout,
        );

        if (status != MachineStatus.online) {
          emit(
            state.copyWith(
              updatingMachineId: null,
              error: 'Server process restarted but health check failed',
            ),
          );
          return false;
        }

        if (_machineStillNeedsUpdate(machineId)) {
          emit(
            state.copyWith(
              updatingMachineId: null,
              error:
                  'Bridge Server restarted but version is still older than $bridgeUpdateTargetVersion',
            ),
          );
          return false;
        }

        emit(
          state.copyWith(
            updatingMachineId: null,
            successMessage: 'Bridge Server updated successfully',
          ),
        );
        return true;
      } else {
        await _refreshMachineStatusAfterUpdateAttempt(machineId);
        emit(
          state.copyWith(
            updatingMachineId: null,
            error: result.error ?? 'Failed to update',
          ),
        );
        return false;
      }
    } catch (e) {
      await _refreshMachineStatusAfterUpdateAttempt(machineId);
      emit(state.copyWith(updatingMachineId: null, error: e.toString()));
      return false;
    }
  }

  Future<void> _refreshMachineStatusAfterUpdateAttempt(String machineId) async {
    try {
      await _service.checkHealth(machineId);
    } catch (_) {
      // Preserve the update failure as the user-facing error.
    }
  }

  bool _machineStillNeedsUpdate(String machineId) {
    for (final item in _service.machinesWithStatus) {
      if (item.machine.id == machineId) {
        return item.needsUpdate(bridgeUpdateTargetVersion);
      }
    }
    return false;
  }

  /// Test SSH connection for a machine
  Future<SshResult> testConnection(String machineId, {String? password}) async {
    if (_sshService == null) {
      return SshResult.failure('SSH not available on this platform');
    }
    return await _sshService.testConnection(machineId, password: password);
  }

  /// Test SSH connection with inline credentials (for add/edit dialog)
  Future<SshResult> testConnectionWithCredentials({
    required String host,
    required int sshPort,
    required String username,
    required SshAuthType authType,
    String? jumpHost,
    int jumpPort = 22,
    String? jumpUsername,
    String? password,
    String? privateKey,
  }) async {
    if (_sshService == null) {
      return SshResult.failure('SSH not available on this platform');
    }
    return await _sshService.testConnectionWithCredentials(
      host: host,
      sshPort: sshPort,
      username: username,
      authType: authType,
      jumpHost: jumpHost,
      jumpPort: jumpPort,
      jumpUsername: jumpUsername,
      password: password,
      privateKey: privateKey,
    );
  }

  /// Get a machine by ID
  Machine? getMachine(String id) => _service.getMachine(id);

  /// Find a machine by host and port.
  Machine? findByHostPort(String host, int port) =>
      _service.findByHostPort(host, port);

  /// Get API key for a machine
  Future<String?> getApiKey(String machineId) => _service.getApiKey(machineId);

  /// Get SSH password for a machine
  Future<String?> getSshPassword(String machineId) =>
      _service.getSshPassword(machineId);

  /// Build WebSocket URL with API key
  Future<String> buildWsUrl(String machineId) => _service.buildWsUrl(machineId);

  /// Create a new machine instance
  Machine createNewMachine({
    String? name,
    required String host,
    int port = 8765,
    bool useSsl = false,
  }) => _service.createNew(name: name, host: host, port: port, useSsl: useSsl);

  /// Start periodic health check
  void startPeriodicHealthCheck() {
    _service.startPeriodicHealthCheck();
  }

  /// Stop periodic health check
  void stopPeriodicHealthCheck() {
    _service.stopPeriodicHealthCheck();
  }

  /// Clear any error or success message
  void clearMessages() {
    emit(state.copyWith(error: null, successMessage: null));
  }

  @override
  Future<void> close() {
    _machinesSub?.cancel();
    if (_ownsLatestVersionService) {
      _latestVersionService.dispose();
    }
    return super.close();
  }
}
