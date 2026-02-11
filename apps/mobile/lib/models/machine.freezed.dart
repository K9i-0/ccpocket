// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'machine.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BridgeVersionInfo&&(identical(other.version, version) || other.version == version)&&(identical(other.nodeVersion, nodeVersion) || other.nodeVersion == nodeVersion)&&(identical(other.platform, platform) || other.platform == platform)&&(identical(other.arch, arch) || other.arch == arch)&&(identical(other.gitCommit, gitCommit) || other.gitCommit == gitCommit)&&(identical(other.gitBranch, gitBranch) || other.gitBranch == gitBranch));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,version,nodeVersion,platform,arch,gitCommit,gitBranch);

@override
String toString() {
  return 'BridgeVersionInfo(version: $version, nodeVersion: $nodeVersion, platform: $platform, arch: $arch, gitCommit: $gitCommit, gitBranch: $gitBranch)';
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
  return _then(_self.copyWith(
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
int get hashCode => Object.hash(runtimeType,version,nodeVersion,platform,arch,gitCommit,gitBranch);

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
 int get port;/// Whether API key is stored in secure storage
 bool get hasApiKey;/// Last successful connection time
 DateTime? get lastConnected;/// Whether this machine is pinned/favorited (shows at top)
 bool get isFavorite;// ---- SSH Configuration ----
/// Whether SSH remote startup is enabled
 bool get sshEnabled;/// SSH username
 String? get sshUsername;/// SSH port
 int get sshPort;/// SSH authentication type
 SshAuthType get sshAuthType;/// Whether SSH credentials are saved (password or private key in secure storage)
 bool get hasCredentials;
/// Create a copy of Machine
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MachineCopyWith<Machine> get copyWith => _$MachineCopyWithImpl<Machine>(this as Machine, _$identity);

  /// Serializes this Machine to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Machine&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.host, host) || other.host == host)&&(identical(other.port, port) || other.port == port)&&(identical(other.hasApiKey, hasApiKey) || other.hasApiKey == hasApiKey)&&(identical(other.lastConnected, lastConnected) || other.lastConnected == lastConnected)&&(identical(other.isFavorite, isFavorite) || other.isFavorite == isFavorite)&&(identical(other.sshEnabled, sshEnabled) || other.sshEnabled == sshEnabled)&&(identical(other.sshUsername, sshUsername) || other.sshUsername == sshUsername)&&(identical(other.sshPort, sshPort) || other.sshPort == sshPort)&&(identical(other.sshAuthType, sshAuthType) || other.sshAuthType == sshAuthType)&&(identical(other.hasCredentials, hasCredentials) || other.hasCredentials == hasCredentials));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,host,port,hasApiKey,lastConnected,isFavorite,sshEnabled,sshUsername,sshPort,sshAuthType,hasCredentials);

@override
String toString() {
  return 'Machine(id: $id, name: $name, host: $host, port: $port, hasApiKey: $hasApiKey, lastConnected: $lastConnected, isFavorite: $isFavorite, sshEnabled: $sshEnabled, sshUsername: $sshUsername, sshPort: $sshPort, sshAuthType: $sshAuthType, hasCredentials: $hasCredentials)';
}


}

/// @nodoc
abstract mixin class $MachineCopyWith<$Res>  {
  factory $MachineCopyWith(Machine value, $Res Function(Machine) _then) = _$MachineCopyWithImpl;
@useResult
$Res call({
 String id, String? name, String host, int port, bool hasApiKey, DateTime? lastConnected, bool isFavorite, bool sshEnabled, String? sshUsername, int sshPort, SshAuthType sshAuthType, bool hasCredentials
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = freezed,Object? host = null,Object? port = null,Object? hasApiKey = null,Object? lastConnected = freezed,Object? isFavorite = null,Object? sshEnabled = null,Object? sshUsername = freezed,Object? sshPort = null,Object? sshAuthType = null,Object? hasCredentials = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as String,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,hasApiKey: null == hasApiKey ? _self.hasApiKey : hasApiKey // ignore: cast_nullable_to_non_nullable
as bool,lastConnected: freezed == lastConnected ? _self.lastConnected : lastConnected // ignore: cast_nullable_to_non_nullable
as DateTime?,isFavorite: null == isFavorite ? _self.isFavorite : isFavorite // ignore: cast_nullable_to_non_nullable
as bool,sshEnabled: null == sshEnabled ? _self.sshEnabled : sshEnabled // ignore: cast_nullable_to_non_nullable
as bool,sshUsername: freezed == sshUsername ? _self.sshUsername : sshUsername // ignore: cast_nullable_to_non_nullable
as String?,sshPort: null == sshPort ? _self.sshPort : sshPort // ignore: cast_nullable_to_non_nullable
as int,sshAuthType: null == sshAuthType ? _self.sshAuthType : sshAuthType // ignore: cast_nullable_to_non_nullable
as SshAuthType,hasCredentials: null == hasCredentials ? _self.hasCredentials : hasCredentials // ignore: cast_nullable_to_non_nullable
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String? name,  String host,  int port,  bool hasApiKey,  DateTime? lastConnected,  bool isFavorite,  bool sshEnabled,  String? sshUsername,  int sshPort,  SshAuthType sshAuthType,  bool hasCredentials)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Machine() when $default != null:
return $default(_that.id,_that.name,_that.host,_that.port,_that.hasApiKey,_that.lastConnected,_that.isFavorite,_that.sshEnabled,_that.sshUsername,_that.sshPort,_that.sshAuthType,_that.hasCredentials);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String? name,  String host,  int port,  bool hasApiKey,  DateTime? lastConnected,  bool isFavorite,  bool sshEnabled,  String? sshUsername,  int sshPort,  SshAuthType sshAuthType,  bool hasCredentials)  $default,) {final _that = this;
switch (_that) {
case _Machine():
return $default(_that.id,_that.name,_that.host,_that.port,_that.hasApiKey,_that.lastConnected,_that.isFavorite,_that.sshEnabled,_that.sshUsername,_that.sshPort,_that.sshAuthType,_that.hasCredentials);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String? name,  String host,  int port,  bool hasApiKey,  DateTime? lastConnected,  bool isFavorite,  bool sshEnabled,  String? sshUsername,  int sshPort,  SshAuthType sshAuthType,  bool hasCredentials)?  $default,) {final _that = this;
switch (_that) {
case _Machine() when $default != null:
return $default(_that.id,_that.name,_that.host,_that.port,_that.hasApiKey,_that.lastConnected,_that.isFavorite,_that.sshEnabled,_that.sshUsername,_that.sshPort,_that.sshAuthType,_that.hasCredentials);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Machine extends Machine {
  const _Machine({required this.id, this.name, required this.host, this.port = 8765, this.hasApiKey = false, this.lastConnected, this.isFavorite = false, this.sshEnabled = false, this.sshUsername, this.sshPort = 22, this.sshAuthType = SshAuthType.password, this.hasCredentials = false}): super._();
  factory _Machine.fromJson(Map<String, dynamic> json) => _$MachineFromJson(json);

/// Unique identifier (UUID)
@override final  String id;
/// User-friendly display name (optional - shows host:port if null)
@override final  String? name;
/// IP address or hostname (typically Tailscale IP like 100.64.x.x)
@override final  String host;
/// Bridge Server port
@override@JsonKey() final  int port;
/// Whether API key is stored in secure storage
@override@JsonKey() final  bool hasApiKey;
/// Last successful connection time
@override final  DateTime? lastConnected;
/// Whether this machine is pinned/favorited (shows at top)
@override@JsonKey() final  bool isFavorite;
// ---- SSH Configuration ----
/// Whether SSH remote startup is enabled
@override@JsonKey() final  bool sshEnabled;
/// SSH username
@override final  String? sshUsername;
/// SSH port
@override@JsonKey() final  int sshPort;
/// SSH authentication type
@override@JsonKey() final  SshAuthType sshAuthType;
/// Whether SSH credentials are saved (password or private key in secure storage)
@override@JsonKey() final  bool hasCredentials;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Machine&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.host, host) || other.host == host)&&(identical(other.port, port) || other.port == port)&&(identical(other.hasApiKey, hasApiKey) || other.hasApiKey == hasApiKey)&&(identical(other.lastConnected, lastConnected) || other.lastConnected == lastConnected)&&(identical(other.isFavorite, isFavorite) || other.isFavorite == isFavorite)&&(identical(other.sshEnabled, sshEnabled) || other.sshEnabled == sshEnabled)&&(identical(other.sshUsername, sshUsername) || other.sshUsername == sshUsername)&&(identical(other.sshPort, sshPort) || other.sshPort == sshPort)&&(identical(other.sshAuthType, sshAuthType) || other.sshAuthType == sshAuthType)&&(identical(other.hasCredentials, hasCredentials) || other.hasCredentials == hasCredentials));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,host,port,hasApiKey,lastConnected,isFavorite,sshEnabled,sshUsername,sshPort,sshAuthType,hasCredentials);

@override
String toString() {
  return 'Machine(id: $id, name: $name, host: $host, port: $port, hasApiKey: $hasApiKey, lastConnected: $lastConnected, isFavorite: $isFavorite, sshEnabled: $sshEnabled, sshUsername: $sshUsername, sshPort: $sshPort, sshAuthType: $sshAuthType, hasCredentials: $hasCredentials)';
}


}

/// @nodoc
abstract mixin class _$MachineCopyWith<$Res> implements $MachineCopyWith<$Res> {
  factory _$MachineCopyWith(_Machine value, $Res Function(_Machine) _then) = __$MachineCopyWithImpl;
@override @useResult
$Res call({
 String id, String? name, String host, int port, bool hasApiKey, DateTime? lastConnected, bool isFavorite, bool sshEnabled, String? sshUsername, int sshPort, SshAuthType sshAuthType, bool hasCredentials
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = freezed,Object? host = null,Object? port = null,Object? hasApiKey = null,Object? lastConnected = freezed,Object? isFavorite = null,Object? sshEnabled = null,Object? sshUsername = freezed,Object? sshPort = null,Object? sshAuthType = null,Object? hasCredentials = null,}) {
  return _then(_Machine(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,host: null == host ? _self.host : host // ignore: cast_nullable_to_non_nullable
as String,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,hasApiKey: null == hasApiKey ? _self.hasApiKey : hasApiKey // ignore: cast_nullable_to_non_nullable
as bool,lastConnected: freezed == lastConnected ? _self.lastConnected : lastConnected // ignore: cast_nullable_to_non_nullable
as DateTime?,isFavorite: null == isFavorite ? _self.isFavorite : isFavorite // ignore: cast_nullable_to_non_nullable
as bool,sshEnabled: null == sshEnabled ? _self.sshEnabled : sshEnabled // ignore: cast_nullable_to_non_nullable
as bool,sshUsername: freezed == sshUsername ? _self.sshUsername : sshUsername // ignore: cast_nullable_to_non_nullable
as String?,sshPort: null == sshPort ? _self.sshPort : sshPort // ignore: cast_nullable_to_non_nullable
as int,sshAuthType: null == sshAuthType ? _self.sshAuthType : sshAuthType // ignore: cast_nullable_to_non_nullable
as SshAuthType,hasCredentials: null == hasCredentials ? _self.hasCredentials : hasCredentials // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$MachineWithStatus {

 Machine get machine; MachineStatus get status; DateTime? get lastChecked; String? get lastError;/// Bridge version info (fetched during health check)
 BridgeVersionInfo? get versionInfo;
/// Create a copy of MachineWithStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MachineWithStatusCopyWith<MachineWithStatus> get copyWith => _$MachineWithStatusCopyWithImpl<MachineWithStatus>(this as MachineWithStatus, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MachineWithStatus&&(identical(other.machine, machine) || other.machine == machine)&&(identical(other.status, status) || other.status == status)&&(identical(other.lastChecked, lastChecked) || other.lastChecked == lastChecked)&&(identical(other.lastError, lastError) || other.lastError == lastError)&&(identical(other.versionInfo, versionInfo) || other.versionInfo == versionInfo));
}


@override
int get hashCode => Object.hash(runtimeType,machine,status,lastChecked,lastError,versionInfo);

@override
String toString() {
  return 'MachineWithStatus(machine: $machine, status: $status, lastChecked: $lastChecked, lastError: $lastError, versionInfo: $versionInfo)';
}


}

/// @nodoc
abstract mixin class $MachineWithStatusCopyWith<$Res>  {
  factory $MachineWithStatusCopyWith(MachineWithStatus value, $Res Function(MachineWithStatus) _then) = _$MachineWithStatusCopyWithImpl;
@useResult
$Res call({
 Machine machine, MachineStatus status, DateTime? lastChecked, String? lastError, BridgeVersionInfo? versionInfo
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
@pragma('vm:prefer-inline') @override $Res call({Object? machine = null,Object? status = null,Object? lastChecked = freezed,Object? lastError = freezed,Object? versionInfo = freezed,}) {
  return _then(_self.copyWith(
machine: null == machine ? _self.machine : machine // ignore: cast_nullable_to_non_nullable
as Machine,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MachineStatus,lastChecked: freezed == lastChecked ? _self.lastChecked : lastChecked // ignore: cast_nullable_to_non_nullable
as DateTime?,lastError: freezed == lastError ? _self.lastError : lastError // ignore: cast_nullable_to_non_nullable
as String?,versionInfo: freezed == versionInfo ? _self.versionInfo : versionInfo // ignore: cast_nullable_to_non_nullable
as BridgeVersionInfo?,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Machine machine,  MachineStatus status,  DateTime? lastChecked,  String? lastError,  BridgeVersionInfo? versionInfo)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MachineWithStatus() when $default != null:
return $default(_that.machine,_that.status,_that.lastChecked,_that.lastError,_that.versionInfo);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Machine machine,  MachineStatus status,  DateTime? lastChecked,  String? lastError,  BridgeVersionInfo? versionInfo)  $default,) {final _that = this;
switch (_that) {
case _MachineWithStatus():
return $default(_that.machine,_that.status,_that.lastChecked,_that.lastError,_that.versionInfo);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Machine machine,  MachineStatus status,  DateTime? lastChecked,  String? lastError,  BridgeVersionInfo? versionInfo)?  $default,) {final _that = this;
switch (_that) {
case _MachineWithStatus() when $default != null:
return $default(_that.machine,_that.status,_that.lastChecked,_that.lastError,_that.versionInfo);case _:
  return null;

}
}

}

/// @nodoc


class _MachineWithStatus extends MachineWithStatus {
  const _MachineWithStatus({required this.machine, this.status = MachineStatus.unknown, this.lastChecked, this.lastError, this.versionInfo}): super._();
  

@override final  Machine machine;
@override@JsonKey() final  MachineStatus status;
@override final  DateTime? lastChecked;
@override final  String? lastError;
/// Bridge version info (fetched during health check)
@override final  BridgeVersionInfo? versionInfo;

/// Create a copy of MachineWithStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MachineWithStatusCopyWith<_MachineWithStatus> get copyWith => __$MachineWithStatusCopyWithImpl<_MachineWithStatus>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MachineWithStatus&&(identical(other.machine, machine) || other.machine == machine)&&(identical(other.status, status) || other.status == status)&&(identical(other.lastChecked, lastChecked) || other.lastChecked == lastChecked)&&(identical(other.lastError, lastError) || other.lastError == lastError)&&(identical(other.versionInfo, versionInfo) || other.versionInfo == versionInfo));
}


@override
int get hashCode => Object.hash(runtimeType,machine,status,lastChecked,lastError,versionInfo);

@override
String toString() {
  return 'MachineWithStatus(machine: $machine, status: $status, lastChecked: $lastChecked, lastError: $lastError, versionInfo: $versionInfo)';
}


}

/// @nodoc
abstract mixin class _$MachineWithStatusCopyWith<$Res> implements $MachineWithStatusCopyWith<$Res> {
  factory _$MachineWithStatusCopyWith(_MachineWithStatus value, $Res Function(_MachineWithStatus) _then) = __$MachineWithStatusCopyWithImpl;
@override @useResult
$Res call({
 Machine machine, MachineStatus status, DateTime? lastChecked, String? lastError, BridgeVersionInfo? versionInfo
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
@override @pragma('vm:prefer-inline') $Res call({Object? machine = null,Object? status = null,Object? lastChecked = freezed,Object? lastError = freezed,Object? versionInfo = freezed,}) {
  return _then(_MachineWithStatus(
machine: null == machine ? _self.machine : machine // ignore: cast_nullable_to_non_nullable
as Machine,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as MachineStatus,lastChecked: freezed == lastChecked ? _self.lastChecked : lastChecked // ignore: cast_nullable_to_non_nullable
as DateTime?,lastError: freezed == lastError ? _self.lastError : lastError // ignore: cast_nullable_to_non_nullable
as String?,versionInfo: freezed == versionInfo ? _self.versionInfo : versionInfo // ignore: cast_nullable_to_non_nullable
as BridgeVersionInfo?,
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
