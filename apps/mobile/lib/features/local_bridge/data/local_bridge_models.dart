import 'package:flutter/foundation.dart';

/// Models for the Bridge's local management API (`/admin/*`, `/pairing`,
/// `/tools`). See docs/design/local-bridge-management.md.

String? _string(Object? value) => value is String ? value : null;
int _int(Object? value) => value is num ? value.toInt() : 0;
bool _bool(Object? value) => value == true;
List<Object?> _list(Object? value) => value is List ? value : const [];
Map<String, Object?> _map(Object? value) =>
    value is Map ? value.cast<String, Object?>() : const {};

@immutable
class LocalBridgeStatus {
  const LocalBridgeStatus({
    required this.adminApiVersion,
    required this.version,
    required this.port,
    required this.pid,
    required this.supervised,
    required this.apiKeySource,
    required this.restartRequired,
    required this.sessions,
    required this.clients,
    this.safeMode = false,
  });

  factory LocalBridgeStatus.fromJson(Map<String, Object?> json) =>
      LocalBridgeStatus(
        adminApiVersion: _int(json['adminApiVersion']),
        version: _string(json['version']) ?? '',
        port: _int(json['port']),
        pid: _int(json['pid']),
        supervised: _bool(json['supervised']),
        apiKeySource: _string(json['apiKeySource']) ?? '',
        restartRequired: _bool(json['restartRequired']),
        sessions: _int(json['sessions']),
        clients: _int(json['clients']),
        safeMode: _bool(json['safeMode']),
      );

  /// The saved settings were ignored because the Bridge kept failing to
  /// start with them.
  final bool safeMode;
  final int adminApiVersion;
  final String version;
  final int port;
  final int pid;

  /// Something restarts the Bridge when it exits (launchd, the app's agent).
  final bool supervised;

  /// `configured` (env/flag), `stored`, `generated` or `disabled`.
  final String apiKeySource;
  final bool restartRequired;
  final int sessions;
  final int clients;

  bool get authDisabled => apiKeySource == 'disabled';

  /// The stored key can be replaced; one given by env/flag cannot.
  bool get canRotateApiKey =>
      apiKeySource == 'stored' || apiKeySource == 'generated';
}

enum LocalBridgeSettingType {
  port,
  string,
  wsUrl,
  boolean,
  dirs,
  enumeration,
  secret,
}

enum LocalBridgeSettingSource { env, file, defaultValue }

@immutable
class LocalBridgeSetting {
  const LocalBridgeSetting({
    required this.key,
    required this.env,
    required this.type,
    required this.source,
    this.values = const [],
    this.value,
    this.fileValue,
    this.configured = false,
    this.fileConfigured = false,
  });

  factory LocalBridgeSetting.fromJson(Map<String, Object?> json) =>
      LocalBridgeSetting(
        key: _string(json['key']) ?? '',
        env: _string(json['env']) ?? '',
        type: switch (json['type']) {
          'port' => LocalBridgeSettingType.port,
          'wsUrl' => LocalBridgeSettingType.wsUrl,
          'boolean' => LocalBridgeSettingType.boolean,
          'dirs' => LocalBridgeSettingType.dirs,
          'enum' => LocalBridgeSettingType.enumeration,
          'secret' => LocalBridgeSettingType.secret,
          _ => LocalBridgeSettingType.string,
        },
        source: switch (json['source']) {
          'env' => LocalBridgeSettingSource.env,
          'file' => LocalBridgeSettingSource.file,
          _ => LocalBridgeSettingSource.defaultValue,
        },
        values: _list(json['values']).whereType<String>().toList(),
        value: _normalize(json['value']),
        fileValue: _normalize(json['fileValue']),
        configured: _bool(json['configured']),
        fileConfigured: _bool(json['fileConfigured']),
      );

  static Object? _normalize(Object? value) =>
      value is List ? value.whereType<String>().toList() : value;

  final String key;

  /// Environment variable that overrides this setting.
  final String env;
  final LocalBridgeSettingType type;
  final LocalBridgeSettingSource source;
  final List<String> values;

  /// Value the running Bridge uses (`bool`, `int`, `String`, `List<String>`).
  /// Always null for secrets: see [configured].
  final Object? value;

  /// Value saved in the config file; applies after a restart.
  final Object? fileValue;
  final bool configured;
  final bool fileConfigured;

  /// An environment variable wins over the config file, so the UI cannot
  /// change this setting.
  bool get lockedByEnv => source == LocalBridgeSettingSource.env;

  /// What a restart would use: the saved value, else the running one
  /// (which is then the default or the env value).
  Object? get effectiveValue =>
      lockedByEnv ? value : (fileValue ?? (fileIsSet ? null : value));

  bool get fileIsSet => type == LocalBridgeSettingType.secret
      ? fileConfigured
      : fileValue != null;
}

@immutable
class LocalBridgeConfig {
  const LocalBridgeConfig({
    required this.path,
    required this.settings,
    required this.restartRequired,
  });

  factory LocalBridgeConfig.fromJson(Map<String, Object?> json) =>
      LocalBridgeConfig(
        path: _string(json['path']) ?? '',
        settings: [
          for (final item in _list(json['settings']))
            LocalBridgeSetting.fromJson(_map(item)),
        ],
        restartRequired: _bool(json['restartRequired']),
      );

  final String path;
  final List<LocalBridgeSetting> settings;
  final bool restartRequired;

  LocalBridgeSetting? setting(String key) {
    for (final setting in settings) {
      if (setting.key == key) return setting;
    }
    return null;
  }
}

@immutable
class LocalBridgeConnection {
  const LocalBridgeConnection({
    required this.label,
    required this.wsUrl,
    required this.deepLink,
  });

  /// `LAN`, `Tailscale` or `Public`.
  final String label;
  final String wsUrl;

  /// `ccpocket://connect?...` link including the token: what the QR encodes.
  final String deepLink;
}

@immutable
class LocalBridgePairing {
  const LocalBridgePairing({
    required this.authRequired,
    required this.connections,
    this.token,
  });

  factory LocalBridgePairing.fromJson(Map<String, Object?> json) {
    final connections = <LocalBridgeConnection>[];
    for (final item in _list(json['connections'])) {
      final map = _map(item);
      final wsUrl = _string(map['wsUrl']);
      final deepLink = _string(map['deepLink']);
      if (wsUrl == null || deepLink == null) continue;
      connections.add(
        LocalBridgeConnection(
          label: _string(map['label']) ?? '',
          wsUrl: wsUrl,
          deepLink: deepLink,
        ),
      );
    }
    return LocalBridgePairing(
      authRequired: json['auth'] == 'required',
      connections: connections,
      token: _string(json['token']),
    );
  }

  final bool authRequired;

  /// Addresses other devices can reach, preferred first.
  final List<LocalBridgeConnection> connections;

  /// The Bridge API key; null when authentication is off or in demo mode.
  final String? token;
}

enum LocalBridgeToolRequirement { required, agent, optional }

@immutable
class LocalBridgeToolCommand {
  const LocalBridgeToolCommand({required this.label, required this.command});

  final String label;
  final String command;
}

@immutable
class LocalBridgeTool {
  const LocalBridgeTool({
    required this.id,
    required this.name,
    required this.requirement,
    required this.installed,
    required this.ready,
    required this.docsUrl,
    this.version,
    this.message,
    this.installCommands = const [],
    this.setupCommand,
  });

  factory LocalBridgeTool.fromJson(Map<String, Object?> json) =>
      LocalBridgeTool(
        id: _string(json['id']) ?? '',
        name: _string(json['name']) ?? '',
        requirement: switch (json['requirement']) {
          'required' => LocalBridgeToolRequirement.required,
          'agent' => LocalBridgeToolRequirement.agent,
          _ => LocalBridgeToolRequirement.optional,
        },
        installed: _bool(json['installed']),
        ready: _bool(json['ready']),
        docsUrl: _string(json['docsUrl']) ?? '',
        version: _string(json['version']),
        message: _string(json['message']),
        installCommands: [
          for (final item in _list(json['installCommands']))
            if (_string(_map(item)['command']) case final command?)
              LocalBridgeToolCommand(
                label: _string(_map(item)['label']) ?? '',
                command: command,
              ),
        ],
        setupCommand: _string(json['setupCommand']),
      );

  /// `node`, `git`, `claude`, `codex`, `antigravity`, `gh`, `tailscale`.
  final String id;
  final String name;
  final LocalBridgeToolRequirement requirement;
  final bool installed;

  /// Installed, new enough, and signed in where that can be checked.
  final bool ready;
  final String docsUrl;
  final String? version;
  final String? message;
  final List<LocalBridgeToolCommand> installCommands;

  /// Command to sign in / connect when installed but not [ready].
  final String? setupCommand;
}

@immutable
class LocalBridgeTools {
  const LocalBridgeTools({required this.tools, required this.ready});

  factory LocalBridgeTools.fromJson(Map<String, Object?> json) =>
      LocalBridgeTools(
        tools: [
          for (final item in _list(json['tools']))
            LocalBridgeTool.fromJson(_map(item)),
        ],
        ready: _bool(json['ready']),
      );

  final List<LocalBridgeTool> tools;

  /// Node, Git and at least one agent are ready.
  final bool ready;
}

@immutable
class LocalBridgeLogEntry {
  const LocalBridgeLogEntry({
    required this.time,
    required this.level,
    required this.message,
  });

  factory LocalBridgeLogEntry.fromJson(Map<String, Object?> json) =>
      LocalBridgeLogEntry(
        time: DateTime.fromMillisecondsSinceEpoch(_int(json['time'])),
        level: _string(json['level']) ?? 'info',
        message: _string(json['message']) ?? '',
      );

  final DateTime time;

  /// `info`, `warn` or `error`.
  final String level;
  final String message;
}
