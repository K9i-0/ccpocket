// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'machine.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BridgeVersionInfo {

 String get version; String? get nodeVersion; String? get platform; String? get arch; String? get gitCommit; String? get gitBranch;
/// Create a copy of BridgeVersionInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BridgeVersionInfoCopyWith<BridgeVersionInfo> get copyWith => _$BridgeVersionInfoCopyWithImpl<BridgeVersionInfo>(this as BridgeVersionInfo, _$identity);

  /// Serializes this BridgeVersionInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as BridgeVersionInfo;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BridgeVersionInfo&&(identical(other.version, _this.version) || other.version == _this.version)&&(identical(other.nodeVersion, _this.nodeVersion) || other.nodeVersion == _this.nodeVersion)&&(identical(other.platform, _this.platform) || other.platform == _this.platform)&&(identical(other.arch, _this.arch) || other.arch == _this.arch)&&(identical(other.gitCommit, _this.gitCommit) || other.gitCommit == _this.gitCommit)&&(identical(other.gitBranch, _this.gitBranch) || other.gitBranch == _this.gitBranch));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as BridgeVersionInfo;
  return Object.hash(runtimeType,_this.version,_this.nodeVersion,_this.platform,_this.arch,_this.gitCommit,_this.gitBranch);
}

@override
String toString() {
  final _this = this as BridgeVersionInfo;
  return 'BridgeVersionInfo(version: ${_this.version}, nodeVersion: ${_this.nodeVersion}, platform: ${_this.platform}, arch: ${_this.arch}, gitCommit: ${_this.gitCommit}, gitBranch: ${_this.gitBranch})';
}


}

/// @nodoc
abstract mixin class $BridgeVersionInfoCopyWith<$Res>  {
  factory $BridgeVersionInfoCopyWith(BridgeVersionInfo value, $Res Function(BridgeVersionInfo) _then) = _$BridgeVersionInfoCopyWithImpl;
@useResult
$Res call({
 String version, String? nodeVersion, String? platform, String? arch, String? gitCommit, String? gitBranch
});




}
/// @nodoc
class _$BridgeVersionInfoCopyWithImpl<$Res>
    implements $BridgeVersionInfoCopyWith<$Res> {
  _$BridgeVersionInfoCopyWithImpl(this._self, this._then);

  final BridgeVersionInfo _self;
  final $Res Function(BridgeVersionInfo) _then;

/// Create a copy of BridgeVersionInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? version = null,Object? nodeVersion = freezed,Object? platform = freezed,Object? arch = freezed,Object? gitCommit = freezed,Object? gitBranch = freezed,}) {
  return _then(BridgeVersionInfo(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,nodeVersion: freezed == nodeVersion ? _self.nodeVersion : nodeVersion // ignore: cast_nullable_to_non_nullable
as String?,platform: freezed == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as String?,arch: freezed == arch ? _self.arch : arch // ignore: cast_nullable_to_non_nullable
as String?,gitCommit: freezed == gitCommit ? _self.gitCommit : gitCommit // ignore: cast_nullable_to_non_nullable
as String?,gitBranch: freezed == gitBranch ? _self.gitBranch : gitBranch // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [BridgeVersionInfo].
extension BridgeVersionInfoPatterns on BridgeVersionInfo {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BridgeVersionInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BridgeVersionInfo() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BridgeVersionInfo value)  $default,){
final _that = this;
switch (_that) {
case _BridgeVersionInfo():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BridgeVersionInfo value)?  $default,){
final _that = this;
switch (_that) {
case _BridgeVersionInfo() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String version,  String? nodeVersion,  String? platform,  String? arch,  String? gitCommit,  String? gitBranch)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BridgeVersionInfo() when $default != null:
return $default(_that.version,_that.nodeVersion,_that.platform,_that.arch,_that.gitCommit,_that.gitBranch);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String version,  String? nodeVersion,  String? platform,  String? arch,  String? gitCommit,  String? gitBranch)  $default,) {final _that = this;
switch (_that) {
case _BridgeVersionInfo():
return $default(_that.version,_that.nodeVersion,_that.platform,_that.arch,_that.gitCommit,_that.gitBranch);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String version,  String? nodeVersion,  String? platform,  String? arch,  String? gitCommit,  String? gitBranch)?  $default,) {final _that = this;
switch (_that) {
case _BridgeVersionInfo() when $default != null:
return $default(_that.version,_that.nodeVersion,_that.platform,_that.arch,_that.gitCommit,_that.gitBranch);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BridgeVersionInfo extends BridgeVersionInfo {
  const _BridgeVersionInfo({required this.version, this.nodeVersion, this.platform, this.arch, this.gitCommit, this.gitBranch}): super._();
  factory _BridgeVersionInfo.fromJson(Map<String, dynamic> json) => _$BridgeVersionInfoFromJson(json);

@override final  String version;
@override final  String? nodeVersion;
@override final  String? platform;
@override final  String? arch;
@override final  String? gitCommit;
@override final  String? gitBranch;

/// Create a copy of BridgeVersionInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BridgeVersionInfoCopyWith<_BridgeVersionInfo> get copyWith => __$BridgeVersionInfoCopyWithImpl<_BridgeVersionInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BridgeVersionInfoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BridgeVersionInfo&&(identical(other.version, version) || other.version == version)&&(identical(other.nodeVersion, nodeVersion) || other.nodeVersion == nodeVersion)&&(identical(other.platform, platform) || other.platform == platform)&&(identical(other.arch, arch) || other.arch == arch)&&(identical(other.gitCommit, gitCommit) || other.gitCommit == gitCommit)&&(identical(other.gitBranch, gitBranch) || other.gitBranch == gitBranch));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,version,nodeVersion,platform,arch,gitCommit,gitBranch);
}

@override
String toString() {
    return 'BridgeVersionInfo(version: $version, nodeVersion: $nodeVersion, platform: $platform, arch: $arch, gitCommit: $gitCommit, gitBranch: $gitBranch)';
}


}

/// @nodoc
abstract mixin class _$BridgeVersionInfoCopyWith<$Res> implements $BridgeVersionInfoCopyWith<$Res> {
  factory _$BridgeVersionInfoCopyWith(_BridgeVersionInfo value, $Res Function(_BridgeVersionInfo) _then) = __$BridgeVersionInfoCopyWithImpl;
@override @useResult
$Res call({
 String version, String? nodeVersion, String? platform, String? arch, String? gitCommit, String? gitBranch
});




}
/// @nodoc
class __$BridgeVersionInfoCopyWithImpl<$Res>
    implements _$BridgeVersionInfoCopyWith<$Res> {
  __$BridgeVersionInfoCopyWithImpl(this._self, this._then);

  final _BridgeVersionInfo _self;
  final $Res Function(_BridgeVersionInfo) _then;

/// Create a copy of BridgeVersionInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? version = null,Object? nodeVersion = freezed,Object? platform = freezed,Object? arch = freezed,Object? gitCommit = freezed,Object? gitBranch = freezed,}) {
  return _then(_BridgeVersionInfo(
version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as String,nodeVersion: freezed == nodeVersion ? _self.nodeVersion : nodeVersion // ignore: cast_nullable_to_non_nullable
as String?,platform: freezed == platform ? _self.platform : platform // ignore: cast_nullable_to_non_nullable
as String?,arch: freezed == arch ? _self.arch : arch // ignore: cast_nullable_to_non_nullable
as String?,gitCommit: freezed == gitCommit ? _self.gitCommit : gitCommit // ignore: cast_nullable_to_non_nullable
as String?,gitBranch: freezed == gitBranch ? _self.gitBranch : gitBranch // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$Machine {

/// Unique identifier (UUID)
 String get id;/// User-friendly display name (optional - shows host:port if null)
 String? get name;/// IP address or hostname (typically Tailscale IP like 100.64.x.x)
 String get host;/// Bridge Server port
 int get port;/// Whether to connect via secure WebSocket/HTTP
 bool get useSsl;/// Whether the transport is detected or explicitly required.
 BridgeConnectionMode get connectionMode;/// Whether [useSsl] contains a successful automatic probe result.
 bool get hasResolvedTransport;/// Whether API key is stored in secure storage
 bool get hasApiKey;/// Last successful connection time
 DateTime? get lastConnected;/// Whether this machine is pinned/favorited (shows at top)
 bool get isFavorite;/// Whether SSH remote startup is enabled
 bool get sshEnabled;/// SSH username
 String? get sshUsername;/// SSH port
 int get sshPort;/// SSH authentication type
 SshAuthType get sshAuthType;/// Optional SSH jump host used to reach the target SSH server
 String? get sshJumpHost;/// SSH jump host port
 int get sshJumpPort;/// Optional SSH jump username. Defaults to [sshUsername] when omitted.
 String? get sshJumpUsername;/// SSH authentication type for the jump host when separate credentials are saved.
 SshAuthType get sshJumpAuthType;/// Whether SSH credentials are saved (password or private key in secure storage)
 bool get hasCredentials;/// Whether separate SSH jump host credentials are saved in secure storage.
 bool get hasJumpCredentials;
/// Create a copy of Machine
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MachineCopyWith<Machine> get copyWith => _$MachineCopyWithImpl<Machine>(this as Machine, _$identity);

  /// Serializes this Machine to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Machine;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Machine&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.host, _this.host) || other.host == _this.host)&&(identical(other.port, _this.port) || other.port == _this.port)&&(identical(other.useSsl, _this.useSsl) || other.useSsl == _this.useSsl)&&(identical(other.connectionMode, _this.connectionMode) || other.connectionMode == _this.connectionMode)&&(identical(other.hasResolvedTransport, _this.hasResolvedTransport) || other.hasResolvedTransport == _this.hasResolvedTransport)&&(identical(other.hasApiKey, _this.hasApiKey) || other.hasApiKey == _this.hasApiKey)&&(identical(other.lastConnected, _this.lastConnected) || other.lastConnected == _this.lastConnected)&&(identical(other.isFavorite, _this.isFavorite) || other.isFavorite == _this.isFavorite)&&(identical(other.sshEnabled, _this.sshEnabled) || other.sshEnabled == _this.sshEnabled)&&(identical(other.sshUsername, _this.sshUsername) || other.sshUsername == _this.sshUsername)&&(identical(other.sshPort, _this.sshPort) || other.sshPort == _this.sshPort)&&(identical(other.sshAuthType, _this.sshAuthType) || other.sshAuthType == _this.sshAuthType)&&(identical(other.sshJumpHost, _this.sshJumpHost) || other.sshJumpHost == _this.sshJumpHost)&&(identical(other.sshJumpPort, _this.sshJumpPort) || other.sshJumpPort == _this.sshJumpPort)&&(identical(other.sshJumpUsername, _this.sshJumpUsername) || other.sshJumpUsername == _this.sshJumpUsername)&&(identical(other.sshJumpAuthType, _this.sshJumpAuthType) || other.sshJumpAuthType == _this.sshJumpAuthType)&&(identical(other.hasCredentials, _this.hasCredentials) || other.hasCredentials == _this.hasCredentials)&&(identical(other.hasJumpCredentials, _this.hasJumpCredentials) || other.hasJumpCredentials == _this.hasJumpCredentials));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Machine;
  return Object.hashAll([runtimeType,_this.id,_this.name,_this.host,_this.port,_this.useSsl,_this.connectionMode,_this.hasResolvedTransport,_this.hasApiKey,_this.lastConnected,_this.isFavorite,_this.sshEnabled,_this.sshUsername,_this.sshPort,_this.sshAuthType,_this.sshJumpHost,_this.sshJumpPort,_this.sshJumpUsername,_this.sshJumpAuthType,_this.hasCredentials,_this.hasJumpCredentials]);
}

@override
String toString() {
  final _this = this as Machine;
  return 'Machine(id: ${_this.id}, name: ${_this.name}, host: ${_this.host}, port: ${_this.port}, useSsl: ${_this.useSsl}, connectionMode: ${_this.connectionMode}, hasResolvedTransport: ${_this.hasResolvedTransport}, hasApiKey: ${_this.hasApiKey}, lastConnected: ${_this.lastConnected}, isFavorite: ${_this.isFavorite}, sshEnabled: ${_this.sshEnabled}, sshUsername: ${_this.sshUsername}, sshPort: ${_this.sshPort}, sshAuthType: ${_this.sshAuthType}, sshJumpHost: ${_this.sshJumpHost}, sshJumpPort: ${_this.sshJumpPort}, sshJumpUsername: ${_this.sshJumpUsername}, sshJumpAuthType: ${_this.sshJumpAuthType}, hasCredentials: ${_this.hasCredentials}, hasJumpCredentials: ${_this.hasJumpCredentials})';
}


}

/// @nodoc
abstract mixin class $MachineCopyWith<$Res>  {
  factory $MachineCopyWith(Machine value, $Res Function(Machine) _then) = _$MachineCopyWithImpl;
@useResult
$Res call({
 String id, String? name, String host, int port, bool useSsl, BridgeConnectionMode connectionMode, bool hasResolvedTransport, bool hasApiKey, DateTime? lastConnected, bool isFavorite, bool sshEnabled, String? sshUsername, int sshPort, SshAuthType sshAuthType, String? sshJumpHost, int sshJumpPort, String? sshJumpUsername, SshAuthType sshJumpAuthType, bool hasCredentials, bool hasJumpCredentials
});




}
/// @nodoc
class _$MachineCopyWithImpl<$Res>
    implements $MachineCopyWith<$Res> {
  _$MachineCopyWithImpl(this._self, this._then);

  final Machine _self;
  final $Res Function(Machine) _then;

/// Create a copy of Machine
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = freezed,Object? host = null,Object? port = null,Object? useSsl = null,Object? connectionMode = null,Object? hasResolvedTransport = null,Object? hasApiKey = null,Object? lastConnected = freezed,Object? isFavorite = null,Object? sshEnabled = null,Object? sshUsername = freezed,Object? sshPort = null,Object? sshAuthType = null,Object? sshJumpHost = freezed,Object? sshJumpPort = null,Object? sshJumpUsername = freezed,Object? sshJumpAuthType = null,Object? hasCredentials = null,Object? hasJumpCredentials = null,}) {
  return _then(Machine(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as String,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,useSsl: null == useSsl ? _self.useSsl : useSsl // ignore: cast_nullable_to_non_nullable
as bool,connectionMode: null == connectionMode ? _self.connectionMode : connectionMode // ignore: cast_nullable_to_non_nullable
as BridgeConnectionMode,hasResolvedTransport: null == hasResolvedTransport ? _self.hasResolvedTransport : hasResolvedTransport // ignore: cast_nullable_to_non_nullable
as bool,hasApiKey: null == hasApiKey ? _self.hasApiKey : hasApiKey // ignore: cast_nullable_to_non_nullable
as bool,lastConnected: freezed == lastConnected ? _self.lastConnected : lastConnected // ignore: cast_nullable_to_non_nullable
as DateTime?,isFavorite: null == isFavorite ? _self.isFavorite : isFavorite // ignore: cast_nullable_to_non_nullable
as bool,sshEnabled: null == sshEnabled ? _self.sshEnabled : sshEnabled // ignore: cast_nullable_to_non_nullable
as bool,sshUsername: freezed == sshUsername ? _self.sshUsername : sshUsername // ignore: cast_nullable_to_non_nullable
as String?,sshPort: null == sshPort ? _self.sshPort : sshPort // ignore: cast_nullable_to_non_nullable
as int,sshAuthType: null == sshAuthType ? _self.sshAuthType : sshAuthType // ignore: cast_nullable_to_non_nullable
as SshAuthType,sshJumpHost: freezed == sshJumpHost ? _self.sshJumpHost : sshJumpHost // ignore: cast_nullable_to_non_nullable
as String?,sshJumpPort: null == sshJumpPort ? _self.sshJumpPort : sshJumpPort // ignore: cast_nullable_to_non_nullable
as int,sshJumpUsername: freezed == sshJumpUsername ? _self.sshJumpUsername : sshJumpUsername // ignore: cast_nullable_to_non_nullable
as String?,sshJumpAuthType: null == sshJumpAuthType ? _self.sshJumpAuthType : sshJumpAuthType // ignore: cast_nullable_to_non_nullable
as SshAuthType,hasCredentials: null == hasCredentials ? _self.hasCredentials : hasCredentials // ignore: cast_nullable_to_non_nullable
as bool,hasJumpCredentials: null == hasJumpCredentials ? _self.hasJumpCredentials : hasJumpCredentials // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [Machine].
extension MachinePatterns on Machine {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Machine value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Machine() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Machine value)  $default,){
final _that = this;
switch (_that) {
case _Machine():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Machine value)?  $default,){
final _that = this;
switch (_that) {
case _Machine() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String? name,  String host,  int port,  bool useSsl,  BridgeConnectionMode connectionMode,  bool hasResolvedTransport,  bool hasApiKey,  DateTime? lastConnected,  bool isFavorite,  bool sshEnabled,  String? sshUsername,  int sshPort,  SshAuthType sshAuthType,  String? sshJumpHost,  int sshJumpPort,  String? sshJumpUsername,  SshAuthType sshJumpAuthType,  bool hasCredentials,  bool hasJumpCredentials)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Machine() when $default != null:
return $default(_that.id,_that.name,_that.host,_that.port,_that.useSsl,_that.connectionMode,_that.hasResolvedTransport,_that.hasApiKey,_that.lastConnected,_that.isFavorite,_that.sshEnabled,_that.sshUsername,_that.sshPort,_that.sshAuthType,_that.sshJumpHost,_that.sshJumpPort,_that.sshJumpUsername,_that.sshJumpAuthType,_that.hasCredentials,_that.hasJumpCredentials);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String? name,  String host,  int port,  bool useSsl,  BridgeConnectionMode connectionMode,  bool hasResolvedTransport,  bool hasApiKey,  DateTime? lastConnected,  bool isFavorite,  bool sshEnabled,  String? sshUsername,  int sshPort,  SshAuthType sshAuthType,  String? sshJumpHost,  int sshJumpPort,  String? sshJumpUsername,  SshAuthType sshJumpAuthType,  bool hasCredentials,  bool hasJumpCredentials)  $default,) {final _that = this;
switch (_that) {
case _Machine():
return $default(_that.id,_that.name,_that.host,_that.port,_that.useSsl,_that.connectionMode,_that.hasResolvedTransport,_that.hasApiKey,_that.lastConnected,_that.isFavorite,_that.sshEnabled,_that.sshUsername,_that.sshPort,_that.sshAuthType,_that.sshJumpHost,_that.sshJumpPort,_that.sshJumpUsername,_that.sshJumpAuthType,_that.hasCredentials,_that.hasJumpCredentials);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String? name,  String host,  int port,  bool useSsl,  BridgeConnectionMode connectionMode,  bool hasResolvedTransport,  bool hasApiKey,  DateTime? lastConnected,  bool isFavorite,  bool sshEnabled,  String? sshUsername,  int sshPort,  SshAuthType sshAuthType,  String? sshJumpHost,  int sshJumpPort,  String? sshJumpUsername,  SshAuthType sshJumpAuthType,  bool hasCredentials,  bool hasJumpCredentials)?  $default,) {final _that = this;
switch (_that) {
case _Machine() when $default != null:
return $default(_that.id,_that.name,_that.host,_that.port,_that.useSsl,_that.connectionMode,_that.hasResolvedTransport,_that.hasApiKey,_that.lastConnected,_that.isFavorite,_that.sshEnabled,_that.sshUsername,_that.sshPort,_that.sshAuthType,_that.sshJumpHost,_that.sshJumpPort,_that.sshJumpUsername,_that.sshJumpAuthType,_that.hasCredentials,_that.hasJumpCredentials);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Machine extends Machine {
  const _Machine({required this.id, this.name, required this.host, this.port = 8765, this.useSsl = false, this.connectionMode = BridgeConnectionMode.automatic, this.hasResolvedTransport = false, this.hasApiKey = false, this.lastConnected, this.isFavorite = false, this.sshEnabled = false, this.sshUsername, this.sshPort = 22, this.sshAuthType = SshAuthType.password, this.sshJumpHost, this.sshJumpPort = 22, this.sshJumpUsername, this.sshJumpAuthType = SshAuthType.password, this.hasCredentials = false, this.hasJumpCredentials = false}): super._();
  factory _Machine.fromJson(Map<String, dynamic> json) => _$MachineFromJson(json);

/// Unique identifier (UUID)
@override final  String id;
/// User-friendly display name (optional - shows host:port if null)
@override final  String? name;
/// IP address or hostname (typically Tailscale IP like 100.64.x.x)
@override final  String host;
/// Bridge Server port
@override@JsonKey() final  int port;
/// Whether to connect via secure WebSocket/HTTP
@override@JsonKey() final  bool useSsl;
/// Whether the transport is detected or explicitly required.
@override@JsonKey() final  BridgeConnectionMode connectionMode;
/// Whether [useSsl] contains a successful automatic probe result.
@override@JsonKey() final  bool hasResolvedTransport;
/// Whether API key is stored in secure storage
@override@JsonKey() final  bool hasApiKey;
/// Last successful connection time
@override final  DateTime? lastConnected;
/// Whether this machine is pinned/favorited (shows at top)
@override@JsonKey() final  bool isFavorite;
/// Whether SSH remote startup is enabled
@override@JsonKey() final  bool sshEnabled;
/// SSH username
@override final  String? sshUsername;
/// SSH port
@override@JsonKey() final  int sshPort;
/// SSH authentication type
@override@JsonKey() final  SshAuthType sshAuthType;
/// Optional SSH jump host used to reach the target SSH server
@override final  String? sshJumpHost;
/// SSH jump host port
@override@JsonKey() final  int sshJumpPort;
/// Optional SSH jump username. Defaults to [sshUsername] when omitted.
@override final  String? sshJumpUsername;
/// SSH authentication type for the jump host when separate credentials are saved.
@override@JsonKey() final  SshAuthType sshJumpAuthType;
/// Whether SSH credentials are saved (password or private key in secure storage)
@override@JsonKey() final  bool hasCredentials;
/// Whether separate SSH jump host credentials are saved in secure storage.
@override@JsonKey() final  bool hasJumpCredentials;

/// Create a copy of Machine
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MachineCopyWith<_Machine> get copyWith => __$MachineCopyWithImpl<_Machine>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MachineToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Machine&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.host, host) || other.host == host)&&(identical(other.port, port) || other.port == port)&&(identical(other.useSsl, useSsl) || other.useSsl == useSsl)&&(identical(other.connectionMode, connectionMode) || other.connectionMode == connectionMode)&&(identical(other.hasResolvedTransport, hasResolvedTransport) || other.hasResolvedTransport == hasResolvedTransport)&&(identical(other.hasApiKey, hasApiKey) || other.hasApiKey == hasApiKey)&&(identical(other.lastConnected, lastConnected) || other.lastConnected == lastConnected)&&(identical(other.isFavorite, isFavorite) || other.isFavorite == isFavorite)&&(identical(other.sshEnabled, sshEnabled) || other.sshEnabled == sshEnabled)&&(identical(other.sshUsername, sshUsername) || other.sshUsername == sshUsername)&&(identical(other.sshPort, sshPort) || other.sshPort == sshPort)&&(identical(other.sshAuthType, sshAuthType) || other.sshAuthType == sshAuthType)&&(identical(other.sshJumpHost, sshJumpHost) || other.sshJumpHost == sshJumpHost)&&(identical(other.sshJumpPort, sshJumpPort) || other.sshJumpPort == sshJumpPort)&&(identical(other.sshJumpUsername, sshJumpUsername) || other.sshJumpUsername == sshJumpUsername)&&(identical(other.sshJumpAuthType, sshJumpAuthType) || other.sshJumpAuthType == sshJumpAuthType)&&(identical(other.hasCredentials, hasCredentials) || other.hasCredentials == hasCredentials)&&(identical(other.hasJumpCredentials, hasJumpCredentials) || other.hasJumpCredentials == hasJumpCredentials));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hashAll([runtimeType,id,name,host,port,useSsl,connectionMode,hasResolvedTransport,hasApiKey,lastConnected,isFavorite,sshEnabled,sshUsername,sshPort,sshAuthType,sshJumpHost,sshJumpPort,sshJumpUsername,sshJumpAuthType,hasCredentials,hasJumpCredentials]);
}

@override
String toString() {
    return 'Machine(id: $id, name: $name, host: $host, port: $port, useSsl: $useSsl, connectionMode: $connectionMode, hasResolvedTransport: $hasResolvedTransport, hasApiKey: $hasApiKey, lastConnected: $lastConnected, isFavorite: $isFavorite, sshEnabled: $sshEnabled, sshUsername: $sshUsername, sshPort: $sshPort, sshAuthType: $sshAuthType, sshJumpHost: $sshJumpHost, sshJumpPort: $sshJumpPort, sshJumpUsername: $sshJumpUsername, sshJumpAuthType: $sshJumpAuthType, hasCredentials: $hasCredentials, hasJumpCredentials: $hasJumpCredentials)';
}


}

/// @nodoc
abstract mixin class _$MachineCopyWith<$Res> implements $MachineCopyWith<$Res> {
  factory _$MachineCopyWith(_Machine value, $Res Function(_Machine) _then) = __$MachineCopyWithImpl;
@override @useResult
$Res call({
 String id, String? name, String host, int port, bool useSsl, BridgeConnectionMode connectionMode, bool hasResolvedTransport, bool hasApiKey, DateTime? lastConnected, bool isFavorite, bool sshEnabled, String? sshUsername, int sshPort, SshAuthType sshAuthType, String? sshJumpHost, int sshJumpPort, String? sshJumpUsername, SshAuthType sshJumpAuthType, bool hasCredentials, bool hasJumpCredentials
});




}
/// @nodoc
class __$MachineCopyWithImpl<$Res>
    implements _$MachineCopyWith<$Res> {
  __$MachineCopyWithImpl(this._self, this._then);

  final _Machine _self;
  final $Res Function(_Machine) _then;

/// Create a copy of Machine
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = freezed,Object? host = null,Object? port = null,Object? useSsl = null,Object? connectionMode = null,Object? hasResolvedTransport = null,Object? hasApiKey = null,Object? lastConnected = freezed,Object? isFavorite = null,Object? sshEnabled = null,Object? sshUsername = freezed,Object? sshPort = null,Object? sshAuthType = null,Object? sshJumpHost = freezed,Object? sshJumpPort = null,Object? sshJumpUsername = freezed,Object? sshJumpAuthType = null,Object? hasCredentials = null,Object? hasJumpCredentials = null,}) {
  return _then(_Machine(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as String,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,useSsl: null == useSsl ? _self.useSsl : useSsl // ignore: cast_nullable_to_non_nullable
as bool,connectionMode: null == connectionMode ? _self.connectionMode : connectionMode // ignore: cast_nullable_to_non_nullable
as BridgeConnectionMode,hasResolvedTransport: null == hasResolvedTransport ? _self.hasResolvedTransport : hasResolvedTransport // ignore: cast_nullable_to_non_nullable
as bool,hasApiKey: null == hasApiKey ? _self.hasApiKey : hasApiKey // ignore: cast_nullable_to_non_nullable
as bool,lastConnected: freezed == lastConnected ? _self.lastConnected : lastConnected // ignore: cast_nullable_to_non_nullable
as DateTime?,isFavorite: null == isFavorite ? _self.isFavorite : isFavorite // ignore: cast_nullable_to_non_nullable
as bool,sshEnabled: null == sshEnabled ? _self.sshEnabled : sshEnabled // ignore: cast_nullable_to_non_nullable
as bool,sshUsername: freezed == sshUsername ? _self.sshUsername : sshUsername // ignore: cast_nullable_to_non_nullable
as String?,sshPort: null == sshPort ? _self.sshPort : sshPort // ignore: cast_nullable_to_non_nullable
as int,sshAuthType: null == sshAuthType ? _self.sshAuthType : sshAuthType // ignore: cast_nullable_to_non_nullable
as SshAuthType,sshJumpHost: freezed == sshJumpHost ? _self.sshJumpHost : sshJumpHost // ignore: cast_nullable_to_non_nullable
as String?,sshJumpPort: null == sshJumpPort ? _self.sshJumpPort : sshJumpPort // ignore: cast_nullable_to_non_nullable
as int,sshJumpUsername: freezed == sshJumpUsername ? _self.sshJumpUsername : sshJumpUsername // ignore: cast_nullable_to_non_nullable
as String?,sshJumpAuthType: null == sshJumpAuthType ? _self.sshJumpAuthType : sshJumpAuthType // ignore: cast_nullable_to_non_nullable
as SshAuthType,hasCredentials: null == hasCredentials ? _self.hasCredentials : hasCredentials // ignore: cast_nullable_to_non_nullable
as bool,hasJumpCredentials: null == hasJumpCredentials ? _self.hasJumpCredentials : hasJumpCredentials // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$MachineWithStatus {

 Machine get machine; MachineStatus get status; DateTime? get lastChecked; String? get lastError;/// Bridge version info (fetched during health check)
 BridgeVersionInfo? get versionInfo;/// `/health` reported `auth: "required"` (Bridge requires an API key).
 bool get authRequired;
/// Create a copy of MachineWithStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MachineWithStatusCopyWith<MachineWithStatus> get copyWith => _$MachineWithStatusCopyWithImpl<MachineWithStatus>(this as MachineWithStatus, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as MachineWithStatus;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MachineWithStatus&&(identical(other.machine, _this.machine) || other.machine == _this.machine)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.lastChecked, _this.lastChecked) || other.lastChecked == _this.lastChecked)&&(identical(other.lastError, _this.lastError) || other.lastError == _this.lastError)&&(identical(other.versionInfo, _this.versionInfo) || other.versionInfo == _this.versionInfo)&&(identical(other.authRequired, _this.authRequired) || other.authRequired == _this.authRequired));
}


@override
int get hashCode {
  final _this = this as MachineWithStatus;
  return Object.hash(runtimeType,_this.machine,_this.status,_this.lastChecked,_this.lastError,_this.versionInfo,_this.authRequired);
}

@override
String toString() {
  final _this = this as MachineWithStatus;
  return 'MachineWithStatus(machine: ${_this.machine}, status: ${_this.status}, lastChecked: ${_this.lastChecked}, lastError: ${_this.lastError}, versionInfo: ${_this.versionInfo}, authRequired: ${_this.authRequired})';
}


}

/// @nodoc
abstract mixin class $MachineWithStatusCopyWith<$Res>  {
  factory $MachineWithStatusCopyWith(MachineWithStatus value, $Res Function(MachineWithStatus) _then) = _$MachineWithStatusCopyWithImpl;
@useResult
$Res call({
 Machine machine, MachineStatus status, DateTime? lastChecked, String? lastError, BridgeVersionInfo? versionInfo, bool authRequired
});


$MachineCopyWith<$Res> get machine;$BridgeVersionInfoCopyWith<$Res>? get versionInfo;

}
/// @nodoc
class _$MachineWithStatusCopyWithImpl<$Res>
    implements $MachineWithStatusCopyWith<$Res> {
  _$MachineWithStatusCopyWithImpl(this._self, this._then);

  final MachineWithStatus _self;
  final $Res Function(MachineWithStatus) _then;

/// Create a copy of MachineWithStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? machine = null,Object? status = null,Object? lastChecked = freezed,Object? lastError = freezed,Object? versionInfo = freezed,Object? authRequired = null,}) {
  return _then(MachineWithStatus(
machine: null == machine ? _self.machine : machine // ignore: cast_nullable_to_non_nullable
as Machine,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MachineStatus,lastChecked: freezed == lastChecked ? _self.lastChecked : lastChecked // ignore: cast_nullable_to_non_nullable
as DateTime?,lastError: freezed == lastError ? _self.lastError : lastError // ignore: cast_nullable_to_non_nullable
as String?,versionInfo: freezed == versionInfo ? _self.versionInfo : versionInfo // ignore: cast_nullable_to_non_nullable
as BridgeVersionInfo?,authRequired: null == authRequired ? _self.authRequired : authRequired // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of MachineWithStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MachineCopyWith<$Res> get machine {
  
  return $MachineCopyWith<$Res>(_self.machine, (value) {
    return _then(_self.copyWith(machine: value));
  });
}/// Create a copy of MachineWithStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BridgeVersionInfoCopyWith<$Res>? get versionInfo {
    if (_self.versionInfo == null) {
    return null;
  }

  return $BridgeVersionInfoCopyWith<$Res>(_self.versionInfo!, (value) {
    return _then(_self.copyWith(versionInfo: value));
  });
}
}


/// Adds pattern-matching-related methods to [MachineWithStatus].
extension MachineWithStatusPatterns on MachineWithStatus {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MachineWithStatus value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MachineWithStatus() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MachineWithStatus value)  $default,){
final _that = this;
switch (_that) {
case _MachineWithStatus():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MachineWithStatus value)?  $default,){
final _that = this;
switch (_that) {
case _MachineWithStatus() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Machine machine,  MachineStatus status,  DateTime? lastChecked,  String? lastError,  BridgeVersionInfo? versionInfo,  bool authRequired)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MachineWithStatus() when $default != null:
return $default(_that.machine,_that.status,_that.lastChecked,_that.lastError,_that.versionInfo,_that.authRequired);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Machine machine,  MachineStatus status,  DateTime? lastChecked,  String? lastError,  BridgeVersionInfo? versionInfo,  bool authRequired)  $default,) {final _that = this;
switch (_that) {
case _MachineWithStatus():
return $default(_that.machine,_that.status,_that.lastChecked,_that.lastError,_that.versionInfo,_that.authRequired);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Machine machine,  MachineStatus status,  DateTime? lastChecked,  String? lastError,  BridgeVersionInfo? versionInfo,  bool authRequired)?  $default,) {final _that = this;
switch (_that) {
case _MachineWithStatus() when $default != null:
return $default(_that.machine,_that.status,_that.lastChecked,_that.lastError,_that.versionInfo,_that.authRequired);case _:
  return null;

}
}

}

/// @nodoc


class _MachineWithStatus extends MachineWithStatus {
  const _MachineWithStatus({required this.machine, this.status = MachineStatus.unknown, this.lastChecked, this.lastError, this.versionInfo, this.authRequired = false}): super._();
  

@override final  Machine machine;
@override@JsonKey() final  MachineStatus status;
@override final  DateTime? lastChecked;
@override final  String? lastError;
/// Bridge version info (fetched during health check)
@override final  BridgeVersionInfo? versionInfo;
/// `/health` reported `auth: "required"` (Bridge requires an API key).
@override@JsonKey() final  bool authRequired;

/// Create a copy of MachineWithStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MachineWithStatusCopyWith<_MachineWithStatus> get copyWith => __$MachineWithStatusCopyWithImpl<_MachineWithStatus>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MachineWithStatus&&(identical(other.machine, machine) || other.machine == machine)&&(identical(other.status, status) || other.status == status)&&(identical(other.lastChecked, lastChecked) || other.lastChecked == lastChecked)&&(identical(other.lastError, lastError) || other.lastError == lastError)&&(identical(other.versionInfo, versionInfo) || other.versionInfo == versionInfo)&&(identical(other.authRequired, authRequired) || other.authRequired == authRequired));
}


@override
int get hashCode {
    return Object.hash(runtimeType,machine,status,lastChecked,lastError,versionInfo,authRequired);
}

@override
String toString() {
    return 'MachineWithStatus(machine: $machine, status: $status, lastChecked: $lastChecked, lastError: $lastError, versionInfo: $versionInfo, authRequired: $authRequired)';
}


}

/// @nodoc
abstract mixin class _$MachineWithStatusCopyWith<$Res> implements $MachineWithStatusCopyWith<$Res> {
  factory _$MachineWithStatusCopyWith(_MachineWithStatus value, $Res Function(_MachineWithStatus) _then) = __$MachineWithStatusCopyWithImpl;
@override @useResult
$Res call({
 Machine machine, MachineStatus status, DateTime? lastChecked, String? lastError, BridgeVersionInfo? versionInfo, bool authRequired
});


@override $MachineCopyWith<$Res> get machine;@override $BridgeVersionInfoCopyWith<$Res>? get versionInfo;

}
/// @nodoc
class __$MachineWithStatusCopyWithImpl<$Res>
    implements _$MachineWithStatusCopyWith<$Res> {
  __$MachineWithStatusCopyWithImpl(this._self, this._then);

  final _MachineWithStatus _self;
  final $Res Function(_MachineWithStatus) _then;

/// Create a copy of MachineWithStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? machine = null,Object? status = null,Object? lastChecked = freezed,Object? lastError = freezed,Object? versionInfo = freezed,Object? authRequired = null,}) {
  return _then(_MachineWithStatus(
machine: null == machine ? _self.machine : machine // ignore: cast_nullable_to_non_nullable
as Machine,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MachineStatus,lastChecked: freezed == lastChecked ? _self.lastChecked : lastChecked // ignore: cast_nullable_to_non_nullable
as DateTime?,lastError: freezed == lastError ? _self.lastError : lastError // ignore: cast_nullable_to_non_nullable
as String?,versionInfo: freezed == versionInfo ? _self.versionInfo : versionInfo // ignore: cast_nullable_to_non_nullable
as BridgeVersionInfo?,authRequired: null == authRequired ? _self.authRequired : authRequired // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of MachineWithStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MachineCopyWith<$Res> get machine {
  
  return $MachineCopyWith<$Res>(_self.machine, (value) {
    return _then(_self.copyWith(machine: value));
  });
}/// Create a copy of MachineWithStatus
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BridgeVersionInfoCopyWith<$Res>? get versionInfo {
    if (_self.versionInfo == null) {
    return null;
  }

  return $BridgeVersionInfoCopyWith<$Res>(_self.versionInfo!, (value) {
    return _then(_self.copyWith(versionInfo: value));
  });
}
}

// dart format on
