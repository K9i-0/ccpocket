// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'machine.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BridgeVersionInfo _$BridgeVersionInfoFromJson(Map<String, dynamic> json) =>
    _BridgeVersionInfo(
      version: json['version'] as String,
      nodeVersion: json['nodeVersion'] as String?,
      platform: json['platform'] as String?,
      arch: json['arch'] as String?,
      gitCommit: json['gitCommit'] as String?,
      gitBranch: json['gitBranch'] as String?,
    );

Map<String, dynamic> _$BridgeVersionInfoToJson(_BridgeVersionInfo instance) =>
    <String, dynamic>{
      'version': instance.version,
      'nodeVersion': instance.nodeVersion,
      'platform': instance.platform,
      'arch': instance.arch,
      'gitCommit': instance.gitCommit,
      'gitBranch': instance.gitBranch,
    };

_Machine _$MachineFromJson(Map<String, dynamic> json) => _Machine(
  id: json['id'] as String,
  name: json['name'] as String?,
  host: json['host'] as String,
  port: (json['port'] as num?)?.toInt() ?? 8765,
  hasApiKey: json['hasApiKey'] as bool? ?? false,
  lastConnected: json['lastConnected'] == null
      ? null
      : DateTime.parse(json['lastConnected'] as String),
  isFavorite: json['isFavorite'] as bool? ?? false,
  sshEnabled: json['sshEnabled'] as bool? ?? false,
  sshUsername: json['sshUsername'] as String?,
  sshPort: (json['sshPort'] as num?)?.toInt() ?? 22,
  sshAuthType:
      $enumDecodeNullable(_$SshAuthTypeEnumMap, json['sshAuthType']) ??
      SshAuthType.password,
  hasCredentials: json['hasCredentials'] as bool? ?? false,
);

Map<String, dynamic> _$MachineToJson(_Machine instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'host': instance.host,
  'port': instance.port,
  'hasApiKey': instance.hasApiKey,
  'lastConnected': instance.lastConnected?.toIso8601String(),
  'isFavorite': instance.isFavorite,
  'sshEnabled': instance.sshEnabled,
  'sshUsername': instance.sshUsername,
  'sshPort': instance.sshPort,
  'sshAuthType': _$SshAuthTypeEnumMap[instance.sshAuthType]!,
  'hasCredentials': instance.hasCredentials,
};

const _$SshAuthTypeEnumMap = {
  SshAuthType.password: 'password',
  SshAuthType.privateKey: 'privateKey',
};
