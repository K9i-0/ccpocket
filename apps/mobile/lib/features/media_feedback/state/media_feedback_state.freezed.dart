// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'media_feedback_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FeedbackMedia {

 String get key; String get label; bool get isVideo; String? get path; String? get projectPath; String? get url; String? get base64; String get mimeType; int? get modifiedAt;
/// Create a copy of FeedbackMedia
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FeedbackMediaCopyWith<FeedbackMedia> get copyWith => _$FeedbackMediaCopyWithImpl<FeedbackMedia>(this as FeedbackMedia, _$identity);

  /// Serializes this FeedbackMedia to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FeedbackMedia&&(identical(other.key, key) || other.key == key)&&(identical(other.label, label) || other.label == label)&&(identical(other.isVideo, isVideo) || other.isVideo == isVideo)&&(identical(other.path, path) || other.path == path)&&(identical(other.projectPath, projectPath) || other.projectPath == projectPath)&&(identical(other.url, url) || other.url == url)&&(identical(other.base64, base64) || other.base64 == base64)&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType)&&(identical(other.modifiedAt, modifiedAt) || other.modifiedAt == modifiedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,key,label,isVideo,path,projectPath,url,base64,mimeType,modifiedAt);

@override
String toString() {
  return 'FeedbackMedia(key: $key, label: $label, isVideo: $isVideo, path: $path, projectPath: $projectPath, url: $url, base64: $base64, mimeType: $mimeType, modifiedAt: $modifiedAt)';
}


}

/// @nodoc
abstract mixin class $FeedbackMediaCopyWith<$Res>  {
  factory $FeedbackMediaCopyWith(FeedbackMedia value, $Res Function(FeedbackMedia) _then) = _$FeedbackMediaCopyWithImpl;
@useResult
$Res call({
 String key, String label, bool isVideo, String? path, String? projectPath, String? url, String? base64, String mimeType, int? modifiedAt
});




}
/// @nodoc
class _$FeedbackMediaCopyWithImpl<$Res>
    implements $FeedbackMediaCopyWith<$Res> {
  _$FeedbackMediaCopyWithImpl(this._self, this._then);

  final FeedbackMedia _self;
  final $Res Function(FeedbackMedia) _then;

/// Create a copy of FeedbackMedia
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? key = null,Object? label = null,Object? isVideo = null,Object? path = freezed,Object? projectPath = freezed,Object? url = freezed,Object? base64 = freezed,Object? mimeType = null,Object? modifiedAt = freezed,}) {
  return _then(FeedbackMedia(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,isVideo: null == isVideo ? _self.isVideo : isVideo // ignore: cast_nullable_to_non_nullable
as bool,path: freezed == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String?,projectPath: freezed == projectPath ? _self.projectPath : projectPath // ignore: cast_nullable_to_non_nullable
as String?,url: freezed == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String?,base64: freezed == base64 ? _self.base64 : base64 // ignore: cast_nullable_to_non_nullable
as String?,mimeType: null == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String,modifiedAt: freezed == modifiedAt ? _self.modifiedAt : modifiedAt // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [FeedbackMedia].
extension FeedbackMediaPatterns on FeedbackMedia {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FeedbackMedia value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FeedbackMedia() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FeedbackMedia value)  $default,){
final _that = this;
switch (_that) {
case _FeedbackMedia():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FeedbackMedia value)?  $default,){
final _that = this;
switch (_that) {
case _FeedbackMedia() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String key,  String label,  bool isVideo,  String? path,  String? projectPath,  String? url,  String? base64,  String mimeType,  int? modifiedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FeedbackMedia() when $default != null:
return $default(_that.key,_that.label,_that.isVideo,_that.path,_that.projectPath,_that.url,_that.base64,_that.mimeType,_that.modifiedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String key,  String label,  bool isVideo,  String? path,  String? projectPath,  String? url,  String? base64,  String mimeType,  int? modifiedAt)  $default,) {final _that = this;
switch (_that) {
case _FeedbackMedia():
return $default(_that.key,_that.label,_that.isVideo,_that.path,_that.projectPath,_that.url,_that.base64,_that.mimeType,_that.modifiedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String key,  String label,  bool isVideo,  String? path,  String? projectPath,  String? url,  String? base64,  String mimeType,  int? modifiedAt)?  $default,) {final _that = this;
switch (_that) {
case _FeedbackMedia() when $default != null:
return $default(_that.key,_that.label,_that.isVideo,_that.path,_that.projectPath,_that.url,_that.base64,_that.mimeType,_that.modifiedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FeedbackMedia implements FeedbackMedia {
  const _FeedbackMedia({required this.key, required this.label, this.isVideo = false, this.path, this.projectPath, this.url, this.base64, this.mimeType = 'image/png', this.modifiedAt});
  factory _FeedbackMedia.fromJson(Map<String, dynamic> json) => _$FeedbackMediaFromJson(json);

@override final  String key;
@override final  String label;
@override@JsonKey() final  bool isVideo;
@override final  String? path;
@override final  String? projectPath;
@override final  String? url;
@override final  String? base64;
@override@JsonKey() final  String mimeType;
@override final  int? modifiedAt;

/// Create a copy of FeedbackMedia
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FeedbackMediaCopyWith<_FeedbackMedia> get copyWith => __$FeedbackMediaCopyWithImpl<_FeedbackMedia>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FeedbackMediaToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FeedbackMedia&&(identical(other.key, key) || other.key == key)&&(identical(other.label, label) || other.label == label)&&(identical(other.isVideo, isVideo) || other.isVideo == isVideo)&&(identical(other.path, path) || other.path == path)&&(identical(other.projectPath, projectPath) || other.projectPath == projectPath)&&(identical(other.url, url) || other.url == url)&&(identical(other.base64, base64) || other.base64 == base64)&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType)&&(identical(other.modifiedAt, modifiedAt) || other.modifiedAt == modifiedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,key,label,isVideo,path,projectPath,url,base64,mimeType,modifiedAt);

@override
String toString() {
  return 'FeedbackMedia(key: $key, label: $label, isVideo: $isVideo, path: $path, projectPath: $projectPath, url: $url, base64: $base64, mimeType: $mimeType, modifiedAt: $modifiedAt)';
}


}

/// @nodoc
abstract mixin class _$FeedbackMediaCopyWith<$Res> implements $FeedbackMediaCopyWith<$Res> {
  factory _$FeedbackMediaCopyWith(_FeedbackMedia value, $Res Function(_FeedbackMedia) _then) = __$FeedbackMediaCopyWithImpl;
@override @useResult
$Res call({
 String key, String label, bool isVideo, String? path, String? projectPath, String? url, String? base64, String mimeType, int? modifiedAt
});




}
/// @nodoc
class __$FeedbackMediaCopyWithImpl<$Res>
    implements _$FeedbackMediaCopyWith<$Res> {
  __$FeedbackMediaCopyWithImpl(this._self, this._then);

  final _FeedbackMedia _self;
  final $Res Function(_FeedbackMedia) _then;

/// Create a copy of FeedbackMedia
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? key = null,Object? label = null,Object? isVideo = null,Object? path = freezed,Object? projectPath = freezed,Object? url = freezed,Object? base64 = freezed,Object? mimeType = null,Object? modifiedAt = freezed,}) {
  return _then(_FeedbackMedia(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,isVideo: null == isVideo ? _self.isVideo : isVideo // ignore: cast_nullable_to_non_nullable
as bool,path: freezed == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String?,projectPath: freezed == projectPath ? _self.projectPath : projectPath // ignore: cast_nullable_to_non_nullable
as String?,url: freezed == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String?,base64: freezed == base64 ? _self.base64 : base64 // ignore: cast_nullable_to_non_nullable
as String?,mimeType: null == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String,modifiedAt: freezed == modifiedAt ? _self.modifiedAt : modifiedAt // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$MediaFeedback {

 String get id; FeedbackMedia get media; String get text; int? get positionMs;
/// Create a copy of MediaFeedback
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MediaFeedbackCopyWith<MediaFeedback> get copyWith => _$MediaFeedbackCopyWithImpl<MediaFeedback>(this as MediaFeedback, _$identity);

  /// Serializes this MediaFeedback to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MediaFeedback&&(identical(other.id, id) || other.id == id)&&(identical(other.media, media) || other.media == media)&&(identical(other.text, text) || other.text == text)&&(identical(other.positionMs, positionMs) || other.positionMs == positionMs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,media,text,positionMs);

@override
String toString() {
  return 'MediaFeedback(id: $id, media: $media, text: $text, positionMs: $positionMs)';
}


}

/// @nodoc
abstract mixin class $MediaFeedbackCopyWith<$Res>  {
  factory $MediaFeedbackCopyWith(MediaFeedback value, $Res Function(MediaFeedback) _then) = _$MediaFeedbackCopyWithImpl;
@useResult
$Res call({
 String id, FeedbackMedia media, String text, int? positionMs
});


$FeedbackMediaCopyWith<$Res> get media;

}
/// @nodoc
class _$MediaFeedbackCopyWithImpl<$Res>
    implements $MediaFeedbackCopyWith<$Res> {
  _$MediaFeedbackCopyWithImpl(this._self, this._then);

  final MediaFeedback _self;
  final $Res Function(MediaFeedback) _then;

/// Create a copy of MediaFeedback
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? media = null,Object? text = null,Object? positionMs = freezed,}) {
  return _then(MediaFeedback(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,media: null == media ? _self.media : media // ignore: cast_nullable_to_non_nullable
as FeedbackMedia,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,positionMs: freezed == positionMs ? _self.positionMs : positionMs // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}
/// Create a copy of MediaFeedback
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FeedbackMediaCopyWith<$Res> get media {
  
  return $FeedbackMediaCopyWith<$Res>(_self.media, (value) {
    return _then(_self.copyWith(media: value));
  });
}
}


/// Adds pattern-matching-related methods to [MediaFeedback].
extension MediaFeedbackPatterns on MediaFeedback {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MediaFeedback value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MediaFeedback() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MediaFeedback value)  $default,){
final _that = this;
switch (_that) {
case _MediaFeedback():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MediaFeedback value)?  $default,){
final _that = this;
switch (_that) {
case _MediaFeedback() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  FeedbackMedia media,  String text,  int? positionMs)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MediaFeedback() when $default != null:
return $default(_that.id,_that.media,_that.text,_that.positionMs);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  FeedbackMedia media,  String text,  int? positionMs)  $default,) {final _that = this;
switch (_that) {
case _MediaFeedback():
return $default(_that.id,_that.media,_that.text,_that.positionMs);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  FeedbackMedia media,  String text,  int? positionMs)?  $default,) {final _that = this;
switch (_that) {
case _MediaFeedback() when $default != null:
return $default(_that.id,_that.media,_that.text,_that.positionMs);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MediaFeedback implements MediaFeedback {
  const _MediaFeedback({required this.id, required this.media, required this.text, this.positionMs});
  factory _MediaFeedback.fromJson(Map<String, dynamic> json) => _$MediaFeedbackFromJson(json);

@override final  String id;
@override final  FeedbackMedia media;
@override final  String text;
@override final  int? positionMs;

/// Create a copy of MediaFeedback
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MediaFeedbackCopyWith<_MediaFeedback> get copyWith => __$MediaFeedbackCopyWithImpl<_MediaFeedback>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MediaFeedbackToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MediaFeedback&&(identical(other.id, id) || other.id == id)&&(identical(other.media, media) || other.media == media)&&(identical(other.text, text) || other.text == text)&&(identical(other.positionMs, positionMs) || other.positionMs == positionMs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,media,text,positionMs);

@override
String toString() {
  return 'MediaFeedback(id: $id, media: $media, text: $text, positionMs: $positionMs)';
}


}

/// @nodoc
abstract mixin class _$MediaFeedbackCopyWith<$Res> implements $MediaFeedbackCopyWith<$Res> {
  factory _$MediaFeedbackCopyWith(_MediaFeedback value, $Res Function(_MediaFeedback) _then) = __$MediaFeedbackCopyWithImpl;
@override @useResult
$Res call({
 String id, FeedbackMedia media, String text, int? positionMs
});


@override $FeedbackMediaCopyWith<$Res> get media;

}
/// @nodoc
class __$MediaFeedbackCopyWithImpl<$Res>
    implements _$MediaFeedbackCopyWith<$Res> {
  __$MediaFeedbackCopyWithImpl(this._self, this._then);

  final _MediaFeedback _self;
  final $Res Function(_MediaFeedback) _then;

/// Create a copy of MediaFeedback
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? media = null,Object? text = null,Object? positionMs = freezed,}) {
  return _then(_MediaFeedback(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,media: null == media ? _self.media : media // ignore: cast_nullable_to_non_nullable
as FeedbackMedia,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,positionMs: freezed == positionMs ? _self.positionMs : positionMs // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

/// Create a copy of MediaFeedback
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FeedbackMediaCopyWith<$Res> get media {
  
  return $FeedbackMediaCopyWith<$Res>(_self.media, (value) {
    return _then(_self.copyWith(media: value));
  });
}
}

/// @nodoc
mixin _$MediaFeedbackState {

 Map<String, List<MediaFeedback>> get sessions;
/// Create a copy of MediaFeedbackState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MediaFeedbackStateCopyWith<MediaFeedbackState> get copyWith => _$MediaFeedbackStateCopyWithImpl<MediaFeedbackState>(this as MediaFeedbackState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MediaFeedbackState&&const DeepCollectionEquality().equals(other.sessions, sessions));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(sessions));

@override
String toString() {
  return 'MediaFeedbackState(sessions: $sessions)';
}


}

/// @nodoc
abstract mixin class $MediaFeedbackStateCopyWith<$Res>  {
  factory $MediaFeedbackStateCopyWith(MediaFeedbackState value, $Res Function(MediaFeedbackState) _then) = _$MediaFeedbackStateCopyWithImpl;
@useResult
$Res call({
 Map<String, List<MediaFeedback>> sessions
});




}
/// @nodoc
class _$MediaFeedbackStateCopyWithImpl<$Res>
    implements $MediaFeedbackStateCopyWith<$Res> {
  _$MediaFeedbackStateCopyWithImpl(this._self, this._then);

  final MediaFeedbackState _self;
  final $Res Function(MediaFeedbackState) _then;

/// Create a copy of MediaFeedbackState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sessions = null,}) {
  return _then(MediaFeedbackState(
sessions: null == sessions ? _self.sessions : sessions // ignore: cast_nullable_to_non_nullable
as Map<String, List<MediaFeedback>>,
  ));
}

}


/// Adds pattern-matching-related methods to [MediaFeedbackState].
extension MediaFeedbackStatePatterns on MediaFeedbackState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MediaFeedbackState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MediaFeedbackState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MediaFeedbackState value)  $default,){
final _that = this;
switch (_that) {
case _MediaFeedbackState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MediaFeedbackState value)?  $default,){
final _that = this;
switch (_that) {
case _MediaFeedbackState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Map<String, List<MediaFeedback>> sessions)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MediaFeedbackState() when $default != null:
return $default(_that.sessions);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Map<String, List<MediaFeedback>> sessions)  $default,) {final _that = this;
switch (_that) {
case _MediaFeedbackState():
return $default(_that.sessions);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Map<String, List<MediaFeedback>> sessions)?  $default,) {final _that = this;
switch (_that) {
case _MediaFeedbackState() when $default != null:
return $default(_that.sessions);case _:
  return null;

}
}

}

/// @nodoc


class _MediaFeedbackState implements MediaFeedbackState {
  const _MediaFeedbackState({ Map<String, List<MediaFeedback>> sessions = const {}}): _sessions = sessions;
  

 final  Map<String, List<MediaFeedback>> _sessions;
@override@JsonKey() Map<String, List<MediaFeedback>> get sessions {
  if (_sessions is EqualUnmodifiableMapView) return _sessions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_sessions);
}


/// Create a copy of MediaFeedbackState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MediaFeedbackStateCopyWith<_MediaFeedbackState> get copyWith => __$MediaFeedbackStateCopyWithImpl<_MediaFeedbackState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MediaFeedbackState&&const DeepCollectionEquality().equals(other._sessions, _sessions));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_sessions));

@override
String toString() {
  return 'MediaFeedbackState(sessions: $sessions)';
}


}

/// @nodoc
abstract mixin class _$MediaFeedbackStateCopyWith<$Res> implements $MediaFeedbackStateCopyWith<$Res> {
  factory _$MediaFeedbackStateCopyWith(_MediaFeedbackState value, $Res Function(_MediaFeedbackState) _then) = __$MediaFeedbackStateCopyWithImpl;
@override @useResult
$Res call({
 Map<String, List<MediaFeedback>> sessions
});




}
/// @nodoc
class __$MediaFeedbackStateCopyWithImpl<$Res>
    implements _$MediaFeedbackStateCopyWith<$Res> {
  __$MediaFeedbackStateCopyWithImpl(this._self, this._then);

  final _MediaFeedbackState _self;
  final $Res Function(_MediaFeedbackState) _then;

/// Create a copy of MediaFeedbackState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sessions = null,}) {
  return _then(_MediaFeedbackState(
sessions: null == sessions ? _self._sessions : sessions // ignore: cast_nullable_to_non_nullable
as Map<String, List<MediaFeedback>>,
  ));
}


}

// dart format on
