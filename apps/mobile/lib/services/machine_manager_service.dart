import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../constants/app_constants.dart';
import '../models/machine.dart';

/// Manages machine configurations, health status, and version info.
///
/// Responsibilities:
/// - CRUD operations for machine configurations
/// - Automatic save on connection (recordConnection)
/// - Periodic health checks with version fetching
/// - Secure credential storage (API keys, SSH passwords/keys)
/// - Migration from old data formats
class MachineManagerService {
  // New storage key for unified Machine model
  static const _prefsKey = 'machines_v2';
  // Old keys for migration
  static const _oldMachinesKey = 'remote_machines';
  static const _oldUrlHistoryKey = 'url_history';
  static const _secureKeyPrefix = 'machine_';
  static const _uuid = Uuid();

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage;

  final _machinesController =
      StreamController<List<MachineWithStatus>>.broadcast();
  List<Machine> _machines = [];
  final Map<String, MachineStatus> _statusCache = {};
  final Map<String, DateTime> _lastChecked = {};
  final Map<String, String> _lastErrors = {};
  final Map<String, BridgeVersionInfo> _versionCache = {};
  Timer? _healthCheckTimer;

  MachineManagerService(this._prefs, this._secureStorage);

  /// Stream of machines with their current status
  Stream<List<MachineWithStatus>> get machines => _machinesController.stream;

  /// Current list of machines
  List<Machine> get currentMachines => List.unmodifiable(_machines);

  /// Get machines with current status and version info
  List<MachineWithStatus> get machinesWithStatus {
    return _machines.map((m) {
      return MachineWithStatus(
        machine: m,
        status: _statusCache[m.id] ?? MachineStatus.unknown,
        lastChecked: _lastChecked[m.id],
        lastError: _lastErrors[m.id],
        versionInfo: _versionCache[m.id],
      );
    }).toList();
  }

  /// Initialize service, migrate if needed, and load machines
  Future<void> init() async {
    await _migrateIfNeeded();
    _machines = _loadFromPrefs();
    _sortMachines();
    _notifyListeners();
    // Start health check after loading
    await checkAllHealth();
  }

  /// Migrate from old RemoteMachine + UrlHistoryEntry to new Machine format
  Future<void> _migrateIfNeeded() async {
    // Check if already migrated
    if (_prefs.containsKey(_prefsKey)) return;

    final machines = <Machine>[];
    final seenKeys = <String>{}; // host:port keys for deduplication

    // 1. Migrate old RemoteMachine entries (mark as favorites)
    final oldMachinesRaw = _prefs.getString(_oldMachinesKey);
    if (oldMachinesRaw != null && oldMachinesRaw.isNotEmpty) {
      try {
        final list = jsonDecode(oldMachinesRaw) as List;
        for (final e in list) {
          final old = e as Map<String, dynamic>;
          final host = old['host'] as String;
          final port = old['port'] as int? ?? 8765;
          final key = '$host:$port';

          if (seenKeys.add(key)) {
            machines.add(
              Machine(
                id: old['id'] as String? ?? _uuid.v4(),
                name: old['name'] as String?,
                host: host,
                port: port,
                hasApiKey: old['hasApiKey'] as bool? ?? false,
                isFavorite: true, // Mark saved machines as favorites
                sshEnabled: old['sshEnabled'] as bool? ?? false,
                sshUsername: old['sshUsername'] as String?,
                sshPort: old['sshPort'] as int? ?? 22,
                sshAuthType: _parseSshAuthType(old['sshAuthType']),
                hasCredentials: old['hasCredentials'] as bool? ?? false,
              ),
            );
          }
        }
      } catch (e) {
        print('[MachineManager] Failed to migrate old machines: $e');
      }
    }

    // 2. Migrate URL history entries (not favorites)
    final urlHistoryRaw = _prefs.getString(_oldUrlHistoryKey);
    if (urlHistoryRaw != null && urlHistoryRaw.isNotEmpty) {
      try {
        final list = jsonDecode(urlHistoryRaw) as List;
        for (final e in list) {
          final entry = e as Map<String, dynamic>;
          final url = entry['url'] as String;
          final uri = Uri.tryParse(url);
          if (uri == null) continue;

          final host = uri.host;
          final port = uri.hasPort ? uri.port : 8765;
          final key = '$host:$port';

          if (seenKeys.add(key)) {
            // Migrate API key to secure storage
            final apiKey = entry['apiKey'] as String?;
            final machineId = _uuid.v4();
            if (apiKey != null && apiKey.isNotEmpty) {
              await _secureStorage.write(
                key: '${_secureKeyPrefix}${machineId}_api',
                value: apiKey,
              );
            }

            final lastConnectedStr = entry['lastConnected'] as String?;
            DateTime? lastConnected;
            if (lastConnectedStr != null) {
              lastConnected = DateTime.tryParse(lastConnectedStr);
            }

            machines.add(
              Machine(
                id: machineId,
                name: entry['name'] as String?,
                host: host,
                port: port,
                hasApiKey: apiKey != null && apiKey.isNotEmpty,
                lastConnected: lastConnected,
                isFavorite: false, // URL history entries are not favorites
              ),
            );
          }
        }
      } catch (e) {
        print('[MachineManager] Failed to migrate URL history: $e');
      }
    }

    // Save migrated data
    if (machines.isNotEmpty) {
      _machines = machines;
      await _saveToPrefs();
      print('[MachineManager] Migrated ${machines.length} machines');
    }

    // Note: Keep old keys for rollback safety
  }

  SshAuthType _parseSshAuthType(dynamic value) {
    if (value == 'privateKey') return SshAuthType.privateKey;
    return SshAuthType.password;
  }

  /// Load machines from SharedPreferences
  List<Machine> _loadFromPrefs() {
    final raw = _prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => Machine.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('[MachineManager] Failed to load machines: $e');
      return [];
    }
  }

  /// Save machines to SharedPreferences
  Future<void> _saveToPrefs() async {
    final json = jsonEncode(_machines.map((m) => m.toJson()).toList());
    await _prefs.setString(_prefsKey, json);
  }

  /// Sort machines: favorites first, then by lastConnected DESC
  void _sortMachines() {
    _machines.sort((a, b) {
      // Favorites first
      if (a.isFavorite != b.isFavorite) {
        return a.isFavorite ? -1 : 1;
      }
      // Then by lastConnected (most recent first)
      final aTime = a.lastConnected?.millisecondsSinceEpoch ?? 0;
      final bTime = b.lastConnected?.millisecondsSinceEpoch ?? 0;
      return bTime - aTime;
    });
  }

  /// Enforce maximum history size (keep favorites + most recent)
  Future<void> _enforceMaxHistory() async {
    if (_machines.length <= AppConstants.maxMachineHistory) return;

    // Keep all favorites
    final favorites = _machines.where((m) => m.isFavorite).toList();
    final nonFavorites = _machines.where((m) => !m.isFavorite).toList();

    // Sort non-favorites by lastConnected
    nonFavorites.sort((a, b) {
      final aTime = a.lastConnected?.millisecondsSinceEpoch ?? 0;
      final bTime = b.lastConnected?.millisecondsSinceEpoch ?? 0;
      return bTime - aTime;
    });

    // Keep enough non-favorites to reach max
    final keepCount = AppConstants.maxMachineHistory - favorites.length;
    final toKeep = nonFavorites
        .take(keepCount.clamp(0, nonFavorites.length))
        .toList();

    // Remove excess machines and their credentials
    final toRemove = nonFavorites.skip(keepCount.clamp(0, nonFavorites.length));
    for (final m in toRemove) {
      await _deleteCredentials(m.id);
    }

    _machines = [...favorites, ...toKeep];
  }

  /// Notify listeners of updated machine list
  void _notifyListeners() {
    _machinesController.add(machinesWithStatus);
  }

  // ---- Machine Lookup ----

  /// Find machine by host:port (unique key)
  Machine? findByHostPort(String host, int port) {
    try {
      return _machines.firstWhere((m) => m.host == host && m.port == port);
    } catch (_) {
      return null;
    }
  }

  /// Get machine by ID
  Machine? getMachine(String id) {
    try {
      return _machines.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  // ---- Auto-save on Connection ----

  /// Record a successful connection (auto-save).
  /// Creates new machine or updates existing one's lastConnected.
  Future<Machine> recordConnection({
    required String host,
    required int port,
    String? apiKey,
    String? name,
  }) async {
    var machine = findByHostPort(host, port);

    if (machine != null) {
      // Update existing machine
      machine = machine.copyWith(
        lastConnected: DateTime.now(),
        name: name ?? machine.name,
      );
      final index = _machines.indexWhere((m) => m.id == machine!.id);
      if (index != -1) {
        _machines[index] = machine;
      }
    } else {
      // Create new machine
      machine = Machine(
        id: _uuid.v4(),
        host: host,
        port: port,
        name: name,
        lastConnected: DateTime.now(),
        hasApiKey: apiKey != null && apiKey.isNotEmpty,
      );
      _machines.add(machine);
    }

    // Save API key if provided
    if (apiKey != null && apiKey.isNotEmpty) {
      await _secureStorage.write(
        key: '${_secureKeyPrefix}${machine.id}_api',
        value: apiKey,
      );
      machine = machine.copyWith(hasApiKey: true);
      final index = _machines.indexWhere((m) => m.id == machine!.id);
      if (index != -1) {
        _machines[index] = machine;
      }
    }

    // Enforce max history and sort
    await _enforceMaxHistory();
    _sortMachines();
    await _saveToPrefs();
    _notifyListeners();

    return machine;
  }

  // ---- CRUD Operations ----

  /// Generate a new machine with unique ID
  Machine createNew({String? name, required String host, int port = 8765}) {
    return Machine(id: _uuid.v4(), name: name, host: host, port: port);
  }

  /// Add a new machine
  Future<void> addMachine(
    Machine machine, {
    String? apiKey,
    String? sshPassword,
    String? sshPrivateKey,
  }) async {
    // Check if machine with same host:port already exists
    final existingIndex = _machines.indexWhere(
      (m) => m.host == machine.host && m.port == machine.port,
    );
    if (existingIndex != -1) {
      // Update existing machine
      _machines[existingIndex] = machine;
    } else {
      _machines.add(machine);
    }

    // Save credentials securely
    await _saveCredentials(
      machine.id,
      apiKey: apiKey,
      sshPassword: sshPassword,
      sshPrivateKey: sshPrivateKey,
    );

    // Update hasApiKey and hasCredentials flags
    final hasApiKey = apiKey != null && apiKey.isNotEmpty;
    final hasCredentials =
        (sshPassword != null && sshPassword.isNotEmpty) ||
        (sshPrivateKey != null && sshPrivateKey.isNotEmpty);

    if (existingIndex != -1) {
      _machines[existingIndex] = machine.copyWith(
        hasApiKey: hasApiKey,
        hasCredentials: hasCredentials,
      );
    } else {
      _machines[_machines.length - 1] = machine.copyWith(
        hasApiKey: hasApiKey,
        hasCredentials: hasCredentials,
      );
    }

    _sortMachines();
    await _saveToPrefs();
    _notifyListeners();

    // Check health for the new/updated machine
    await checkHealth(machine.id);
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
    final index = _machines.indexWhere((m) => m.id == machine.id);
    if (index == -1) return;

    // Handle credential updates
    if (clearApiKey) {
      await _secureStorage.delete(key: '${_secureKeyPrefix}${machine.id}_api');
    } else if (apiKey != null && apiKey.isNotEmpty) {
      await _secureStorage.write(
        key: '${_secureKeyPrefix}${machine.id}_api',
        value: apiKey,
      );
    }

    if (clearCredentials) {
      await _secureStorage.delete(
        key: '${_secureKeyPrefix}${machine.id}_ssh_pass',
      );
      await _secureStorage.delete(
        key: '${_secureKeyPrefix}${machine.id}_ssh_key',
      );
    } else {
      if (sshPassword != null && sshPassword.isNotEmpty) {
        await _secureStorage.write(
          key: '${_secureKeyPrefix}${machine.id}_ssh_pass',
          value: sshPassword,
        );
      }
      if (sshPrivateKey != null && sshPrivateKey.isNotEmpty) {
        await _secureStorage.write(
          key: '${_secureKeyPrefix}${machine.id}_ssh_key',
          value: sshPrivateKey,
        );
      }
    }

    // Update flags
    final existingApiKey = await getApiKey(machine.id);
    final existingPassword = await getSshPassword(machine.id);
    final existingKey = await getSshPrivateKey(machine.id);

    _machines[index] = machine.copyWith(
      hasApiKey: existingApiKey != null && existingApiKey.isNotEmpty,
      hasCredentials:
          (existingPassword != null && existingPassword.isNotEmpty) ||
          (existingKey != null && existingKey.isNotEmpty),
    );

    _sortMachines();
    await _saveToPrefs();
    _notifyListeners();
  }

  /// Delete a machine and its credentials
  Future<void> deleteMachine(String id) async {
    _machines.removeWhere((m) => m.id == id);
    await _deleteCredentials(id);
    _statusCache.remove(id);
    _lastChecked.remove(id);
    _lastErrors.remove(id);
    _versionCache.remove(id);
    await _saveToPrefs();
    _notifyListeners();
  }

  /// Toggle favorite status for a machine
  Future<void> toggleFavorite(String machineId) async {
    final index = _machines.indexWhere((m) => m.id == machineId);
    if (index == -1) return;

    _machines[index] = _machines[index].copyWith(
      isFavorite: !_machines[index].isFavorite,
    );
    _sortMachines();
    await _saveToPrefs();
    _notifyListeners();
  }

  // ---- Health Check ----

  /// Check health of a specific machine and fetch version info
  Future<MachineStatus> checkHealth(String machineId) async {
    final machine = getMachine(machineId);
    if (machine == null) return MachineStatus.unknown;

    try {
      final healthUrl = '${machine.httpUrl}/health';
      final response = await http
          .get(Uri.parse(healthUrl))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        _statusCache[machineId] = MachineStatus.online;
        _lastErrors.remove(machineId);

        // Fetch version info for online machines
        await _fetchVersionInfo(machine);
      } else {
        _statusCache[machineId] = MachineStatus.offline;
        _lastErrors[machineId] = 'HTTP ${response.statusCode}';
        _versionCache.remove(machineId);
      }
    } on http.ClientException catch (e) {
      // Connection refused = server not running (offline), not network issue
      _statusCache[machineId] = MachineStatus.offline;
      _lastErrors[machineId] = e.message;
      _versionCache.remove(machineId);
    } on TimeoutException {
      _statusCache[machineId] = MachineStatus.unreachable;
      _lastErrors[machineId] = 'Connection timeout';
      _versionCache.remove(machineId);
    } catch (e) {
      _statusCache[machineId] = MachineStatus.offline;
      _lastErrors[machineId] = e.toString();
      _versionCache.remove(machineId);
    }

    _lastChecked[machineId] = DateTime.now();
    _notifyListeners();
    return _statusCache[machineId]!;
  }

  /// Fetch version info from /version endpoint
  Future<void> _fetchVersionInfo(Machine machine) async {
    try {
      final versionUrl = '${machine.httpUrl}/version';
      final response = await http
          .get(Uri.parse(versionUrl))
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        _versionCache[machine.id] = BridgeVersionInfo.fromJson(json);
      }
    } catch (e) {
      // Version endpoint is optional, don't treat as error
      print('[MachineManager] Failed to fetch version for ${machine.id}: $e');
    }
  }

  /// Check health of all machines
  Future<void> checkAllHealth() async {
    await Future.wait(_machines.map((m) => checkHealth(m.id)));
  }

  /// Start periodic health check
  void startPeriodicHealthCheck({
    Duration interval = const Duration(seconds: 30),
  }) {
    stopPeriodicHealthCheck();
    _healthCheckTimer = Timer.periodic(interval, (_) => checkAllHealth());
  }

  /// Stop periodic health check
  void stopPeriodicHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
  }

  // ---- Secure Credential Management ----

  Future<void> _saveCredentials(
    String machineId, {
    String? apiKey,
    String? sshPassword,
    String? sshPrivateKey,
  }) async {
    if (apiKey != null && apiKey.isNotEmpty) {
      await _secureStorage.write(
        key: '${_secureKeyPrefix}${machineId}_api',
        value: apiKey,
      );
    }
    if (sshPassword != null && sshPassword.isNotEmpty) {
      await _secureStorage.write(
        key: '${_secureKeyPrefix}${machineId}_ssh_pass',
        value: sshPassword,
      );
    }
    if (sshPrivateKey != null && sshPrivateKey.isNotEmpty) {
      await _secureStorage.write(
        key: '${_secureKeyPrefix}${machineId}_ssh_key',
        value: sshPrivateKey,
      );
    }
  }

  Future<void> _deleteCredentials(String machineId) async {
    await _secureStorage.delete(key: '${_secureKeyPrefix}${machineId}_api');
    await _secureStorage.delete(
      key: '${_secureKeyPrefix}${machineId}_ssh_pass',
    );
    await _secureStorage.delete(key: '${_secureKeyPrefix}${machineId}_ssh_key');
  }

  /// Get API key for a machine
  Future<String?> getApiKey(String machineId) async {
    return await _secureStorage.read(
      key: '${_secureKeyPrefix}${machineId}_api',
    );
  }

  /// Get SSH password for a machine
  Future<String?> getSshPassword(String machineId) async {
    return await _secureStorage.read(
      key: '${_secureKeyPrefix}${machineId}_ssh_pass',
    );
  }

  /// Get SSH private key for a machine
  Future<String?> getSshPrivateKey(String machineId) async {
    return await _secureStorage.read(
      key: '${_secureKeyPrefix}${machineId}_ssh_key',
    );
  }

  /// Build WebSocket URL with API key if available
  Future<String> buildWsUrl(String machineId) async {
    final machine = getMachine(machineId);
    if (machine == null) throw ArgumentError('Machine not found: $machineId');

    var url = machine.wsUrl;
    final apiKey = await getApiKey(machineId);
    if (apiKey != null && apiKey.isNotEmpty) {
      url = '$url?token=$apiKey';
    }
    return url;
  }

  /// Dispose resources
  void dispose() {
    stopPeriodicHealthCheck();
    _machinesController.close();
  }
}
