import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/local_bridge_client.dart';
import '../data/local_bridge_launcher.dart';
import '../data/local_bridge_models.dart';
import 'local_bridge_state.dart';

typedef LocalBridgeClientFactory = LocalBridgeClient Function(int port);

/// Drives the management screen for the Bridge running on this machine.
class LocalBridgeCubit extends Cubit<LocalBridgeState> {
  LocalBridgeCubit({
    int? port,
    LocalBridgeClientFactory? clientFactory,
    this.launcher = const HelperLocalBridgeLauncher(),
    this.startTimeout = const Duration(seconds: 90),
    this.restartPollInterval = const Duration(milliseconds: 500),
    this.restartTimeout = const Duration(seconds: 40),
  }) : _clientFactory =
           clientFactory ?? ((port) => LocalBridgeClient(port: port)),
       _portResolved = port != null,
       super(LocalBridgeState(port: port ?? defaultPort)) {
    _client = _clientFactory(state.port);
  }

  final LocalBridgeLauncher launcher;

  /// How long to wait for a Bridge started from the app (the first start
  /// downloads the package).
  final Duration startTimeout;

  /// Whether the port to manage is known (given, or read from the config).
  bool _portResolved;

  static const defaultPort = 8765;

  final LocalBridgeClientFactory _clientFactory;
  final Duration restartPollInterval;
  final Duration restartTimeout;
  late LocalBridgeClient _client;

  /// Bumped when the port changes so late responses are dropped.
  int _generation = 0;

  Future<void> load({bool showLoading = true}) async {
    final generation = _generation;
    if (showLoading) emit(state.copyWith(phase: LocalBridgePhase.loading));
    if (!_portResolved) {
      _portResolved = true;
      final saved = await launcher.configuredPort();
      if (saved != null && saved != state.port && !isClosed) {
        _client.close();
        _client = _clientFactory(saved);
        emit(state.copyWith(port: saved));
      }
    }
    await _refreshLauncher();
    if (generation != _generation || isClosed) return;
    try {
      final status = await _client.status();
      final config = await _client.config();
      final pairing = await _client.pairing();
      if (generation != _generation || isClosed) return;
      emit(
        state.copyWith(
          phase: LocalBridgePhase.ready,
          status: status,
          config: config,
          pairing: pairing,
          errorDetail: null,
        ),
      );
      unawaited(refreshTools());
    } on LocalBridgeException catch (err) {
      if (generation != _generation || isClosed) return;
      emit(
        state.copyWith(
          phase: switch (err.failure) {
            LocalBridgeFailure.notRunning => LocalBridgePhase.notRunning,
            LocalBridgeFailure.secretUnavailable ||
            LocalBridgeFailure.forbidden => LocalBridgePhase.secretUnavailable,
            LocalBridgeFailure.unsupported => LocalBridgePhase.updateRequired,
            _ => LocalBridgePhase.error,
          },
          status: null,
          config: null,
          pairing: null,
          errorDetail: err.detail,
        ),
      );
    }
  }

  /// [force] bypasses the Bridge's short cache (the "check again" button).
  Future<void> _refreshLauncher() async {
    if (!await launcher.isAvailable()) {
      if (isClosed) return;
      emit(
        state.copyWith(launcherRegistration: LauncherRegistration.unavailable),
      );
      return;
    }
    final result = await launcher.run('status');
    final status = await launcher.readStatus();
    final launcherPort = await launcher.configuredPort() ?? defaultPort;
    if (isClosed) return;
    emit(
      state.copyWith(
        launcherPort: launcherPort,
        launcherRegistration: result.registration,
        launcherStatus: status,
        launcherPermissions: result.permissions,
      ),
    );
  }

  Future<void>? _permissionsRefresh;

  /// Check the macOS permissions again (the user may have just changed them
  /// in System Settings). Callers that overlap share one check.
  Future<void> refreshPermissions() {
    if (state.busy != LocalBridgeBusy.none || !state.showsPermissions) {
      return Future.value();
    }
    return _permissionsRefresh ??= _refreshLauncher().whenComplete(
      () => _permissionsRefresh = null,
    );
  }

  Future<void> openPermissionSettings(BridgePermission permission) async {
    if (permission == BridgePermission.screenCapture &&
        state.launcherPermissions?.screenCapture == false) {
      // The app is only listed under Screen Recording once it has asked.
      await launcher.run('requestScreenCapture');
    }
    await launcher.openSystemSettings(permission);
  }

  /// Register the LaunchAgent and wait for the Bridge it starts.
  Future<bool> start() async {
    if (state.busy != LocalBridgeBusy.none) return false;
    emit(state.copyWith(busy: LocalBridgeBusy.starting, startFailed: false));
    final result = await launcher.run('register');
    if (isClosed) return false;
    emit(state.copyWith(launcherRegistration: result.registration));
    if (!result.ok || result.registration != LauncherRegistration.enabled) {
      emit(
        state.copyWith(
          busy: LocalBridgeBusy.none,
          startFailed:
              result.registration != LauncherRegistration.requiresApproval,
          errorDetail: result.error,
        ),
      );
      return false;
    }

    final deadline = DateTime.now().add(startTimeout);
    while (DateTime.now().isBefore(deadline) && !isClosed) {
      await Future<void>.delayed(restartPollInterval);
      if (await _client.isRunning()) {
        // The pairing secret is written just before the port opens.
        emit(state.copyWith(busy: LocalBridgeBusy.none));
        await load(showLoading: false);
        return state.phase == LocalBridgePhase.ready;
      }
      final status = await launcher.readStatus();
      if (isClosed) return false;
      if (status?.problem != null) {
        emit(
          state.copyWith(
            busy: LocalBridgeBusy.none,
            launcherStatus: status,
            phase: LocalBridgePhase.notRunning,
          ),
        );
        return false;
      }
    }
    if (isClosed) return false;
    emit(state.copyWith(busy: LocalBridgeBusy.none, startFailed: true));
    await load(showLoading: false);
    return false;
  }

  /// Unregister the LaunchAgent: stops the Bridge and its start at login.
  Future<bool> stop() async {
    if (state.busy != LocalBridgeBusy.none) return false;
    emit(state.copyWith(busy: LocalBridgeBusy.stopping, actionFailure: null));
    final result = await launcher.run('unregister');
    if (isClosed) return false;
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (result.ok && DateTime.now().isBefore(deadline) && !isClosed) {
      if (!await _client.isRunning()) break;
      await Future<void>.delayed(restartPollInterval);
    }
    if (isClosed) return false;
    emit(
      state.copyWith(
        busy: LocalBridgeBusy.none,
        actionFailure: result.ok ? null : LocalBridgeFailure.other,
      ),
    );
    await load(showLoading: false);
    return result.ok;
  }

  Future<void> refreshTools({bool force = false}) async {
    if (state.toolsLoading) return;
    final generation = _generation;
    emit(state.copyWith(toolsLoading: true));
    try {
      final tools = await _client.tools(
        apiKey: state.pairing?.token,
        refresh: force,
      );
      if (generation != _generation || isClosed) return;
      emit(
        state.copyWith(
          tools: tools,
          toolsLoading: false,
          toolsUnsupported: false,
        ),
      );
    } on LocalBridgeException catch (err) {
      if (generation != _generation || isClosed) return;
      emit(
        state.copyWith(
          toolsLoading: false,
          toolsUnsupported: err.failure == LocalBridgeFailure.unsupported,
        ),
      );
    }
  }

  Future<List<LocalBridgeLogEntry>> loadLogs() => _client.logs();

  /// Manage the Bridge on another port (for example a second Bridge).
  Future<void> setPort(int port) async {
    if (port == state.port) return;
    _generation += 1;
    _client.close();
    _client = _clientFactory(port);
    _portResolved = true;
    emit(LocalBridgeState(port: port));
    await load();
  }

  /// Stage a change. A value equal to what is saved drops the edit.
  void edit(String key, Object? value) {
    final setting = state.config?.setting(key);
    if (setting == null || setting.lockedByEnv) return;
    final edits = {...state.edits};
    final saved = setting.fileValue;
    final unchanged = value == null
        ? !setting.fileIsSet
        : setting.type != LocalBridgeSettingType.secret &&
              _sameValue(value, saved);
    if (unchanged) {
      edits.remove(key);
    } else {
      edits[key] = value;
    }
    emit(
      state.copyWith(
        edits: edits,
        settingErrors: {...state.settingErrors}..remove(key),
      ),
    );
  }

  void discardEdits() =>
      emit(state.copyWith(edits: const {}, settingErrors: const {}));

  Future<bool> save() async {
    if (!state.hasEdits || state.busy != LocalBridgeBusy.none) return false;
    emit(state.copyWith(busy: LocalBridgeBusy.saving, actionFailure: null));
    try {
      final config = await _client.saveSettings(state.edits);
      emit(
        state.copyWith(
          config: config,
          edits: const {},
          settingErrors: const {},
          busy: LocalBridgeBusy.none,
        ),
      );
      return true;
    } on LocalBridgeException catch (err) {
      emit(
        state.copyWith(
          busy: LocalBridgeBusy.none,
          settingErrors: err.errors,
          actionFailure: err.failure,
        ),
      );
      return false;
    }
  }

  /// Ask the Bridge to exit and wait until its supervisor has started a new
  /// one (a different pid answers).
  Future<bool> restart() async {
    final previousPid = state.status?.pid;
    if (state.busy != LocalBridgeBusy.none) return false;
    emit(state.copyWith(busy: LocalBridgeBusy.restarting, actionFailure: null));
    try {
      await _client.restart();
    } on LocalBridgeException catch (err) {
      emit(
        state.copyWith(busy: LocalBridgeBusy.none, actionFailure: err.failure),
      );
      return false;
    }

    // A saved port change takes effect now: look for the Bridge there.
    final savedPort = state.config?.setting('port');
    if (savedPort != null &&
        !savedPort.lockedByEnv &&
        savedPort.fileValue is int &&
        savedPort.fileValue != state.port) {
      _generation += 1;
      _client.close();
      _client = _clientFactory(savedPort.fileValue! as int);
      emit(state.copyWith(port: savedPort.fileValue! as int));
    }

    final deadline = DateTime.now().add(restartTimeout);
    while (DateTime.now().isBefore(deadline) && !isClosed) {
      await Future<void>.delayed(restartPollInterval);
      try {
        final status = await _client.status();
        if (status.pid != previousPid) {
          emit(
            state.copyWith(busy: LocalBridgeBusy.none, apiKeyRotated: false),
          );
          await load(showLoading: false);
          return true;
        }
      } on LocalBridgeException {
        // Still down, or the new pairing secret is not written yet.
      }
    }
    if (isClosed) return false;
    emit(
      state.copyWith(
        busy: LocalBridgeBusy.none,
        actionFailure: LocalBridgeFailure.notRunning,
      ),
    );
    await load(showLoading: false);
    return false;
  }

  Future<bool> rotateApiKey() async {
    if (state.busy != LocalBridgeBusy.none) return false;
    emit(
      state.copyWith(busy: LocalBridgeBusy.rotatingKey, actionFailure: null),
    );
    try {
      await _client.rotateApiKey();
      emit(state.copyWith(busy: LocalBridgeBusy.none, apiKeyRotated: true));
      return true;
    } on LocalBridgeException catch (err) {
      emit(
        state.copyWith(busy: LocalBridgeBusy.none, actionFailure: err.failure),
      );
      return false;
    }
  }

  void clearActionFailure() => emit(state.copyWith(actionFailure: null));

  static bool _sameValue(Object? a, Object? b) =>
      a is List && b is List ? listEquals(a, b) : a == b;

  @override
  Future<void> close() {
    _client.close();
    return super.close();
  }
}
