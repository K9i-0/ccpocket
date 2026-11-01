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

 String get key; String get label; bool get isVideo;/// A changed file in the Git diff. Code comments carry a [CodeAnchor].
 bool get isCode; String? get path; String? get projectPath; String? get url; String? get base64; String get mimeType; int? get modifiedAt;
/// Create a copy of FeedbackMedia
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FeedbackMediaCopyWith<FeedbackMedia> get copyWith => _$FeedbackMediaCopyWithImpl<FeedbackMedia>(this as FeedbackMedia, _$identity);

  /// Serializes this FeedbackMedia to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as FeedbackMedia;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FeedbackMedia&&(identical(other.key, _this.key) || other.key == _this.key)&&(identical(other.label, _this.label) || other.label == _this.label)&&(identical(other.isVideo, _this.isVideo) || other.isVideo == _this.isVideo)&&(identical(other.isCode, _this.isCode) || other.isCode == _this.isCode)&&(identical(other.path, _this.path) || other.path == _this.path)&&(identical(other.projectPath, _this.projectPath) || other.projectPath == _this.projectPath)&&(identical(other.url, _this.url) || other.url == _this.url)&&(identical(other.base64, _this.base64) || other.base64 == _this.base64)&&(identical(other.mimeType, _this.mimeType) || other.mimeType == _this.mimeType)&&(identical(other.modifiedAt, _this.modifiedAt) || other.modifiedAt == _this.modifiedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as FeedbackMedia;
  return Object.hash(runtimeType,_this.key,_this.label,_this.isVideo,_this.isCode,_this.path,_this.projectPath,_this.url,_this.base64,_this.mimeType,_this.modifiedAt);
}

@override
String toString() {
  final _this = this as FeedbackMedia;
  return 'FeedbackMedia(key: ${_this.key}, label: ${_this.label}, isVideo: ${_this.isVideo}, isCode: ${_this.isCode}, path: ${_this.path}, projectPath: ${_this.projectPath}, url: ${_this.url}, base64: ${_this.base64}, mimeType: ${_this.mimeType}, modifiedAt: ${_this.modifiedAt})';
}


}

/// @nodoc
abstract mixin class $FeedbackMediaCopyWith<$Res>  {
  factory $FeedbackMediaCopyWith(FeedbackMedia value, $Res Function(FeedbackMedia) _then) = _$FeedbackMediaCopyWithImpl;
@useResult
$Res call({
 String key, String label, bool isVideo, bool isCode, String? path, String? projectPath, String? url, String? base64, String mimeType, int? modifiedAt
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
@pragma('vm:prefer-inline') @override $Res call({Object? key = null,Object? label = null,Object? isVideo = null,Object? isCode = null,Object? path = freezed,Object? projectPath = freezed,Object? url = freezed,Object? base64 = freezed,Object? mimeType = null,Object? modifiedAt = freezed,}) {
  return _then(FeedbackMedia(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,isVideo: null == isVideo ? _self.isVideo : isVideo // ignore: cast_nullable_to_non_nullable
as bool,isCode: null == isCode ? _self.isCode : isCode // ignore: cast_nullable_to_non_nullable
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String key,  String label,  bool isVideo,  bool isCode,  String? path,  String? projectPath,  String? url,  String? base64,  String mimeType,  int? modifiedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FeedbackMedia() when $default != null:
return $default(_that.key,_that.label,_that.isVideo,_that.isCode,_that.path,_that.projectPath,_that.url,_that.base64,_that.mimeType,_that.modifiedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String key,  String label,  bool isVideo,  bool isCode,  String? path,  String? projectPath,  String? url,  String? base64,  String mimeType,  int? modifiedAt)  $default,) {final _that = this;
switch (_that) {
case _FeedbackMedia():
return $default(_that.key,_that.label,_that.isVideo,_that.isCode,_that.path,_that.projectPath,_that.url,_that.base64,_that.mimeType,_that.modifiedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String key,  String label,  bool isVideo,  bool isCode,  String? path,  String? projectPath,  String? url,  String? base64,  String mimeType,  int? modifiedAt)?  $default,) {final _that = this;
switch (_that) {
case _FeedbackMedia() when $default != null:
return $default(_that.key,_that.label,_that.isVideo,_that.isCode,_that.path,_that.projectPath,_that.url,_that.base64,_that.mimeType,_that.modifiedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FeedbackMedia implements FeedbackMedia {
  const _FeedbackMedia({required this.key, required this.label, this.isVideo = false, this.isCode = false, this.path, this.projectPath, this.url, this.base64, this.mimeType = 'image/png', this.modifiedAt});
  factory _FeedbackMedia.fromJson(Map<String, dynamic> json) => _$FeedbackMediaFromJson(json);

@override final  String key;
@override final  String label;
@override@JsonKey() final  bool isVideo;
/// A changed file in the Git diff. Code comments carry a [CodeAnchor].
@override@JsonKey() final  bool isCode;
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
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _FeedbackMedia&&(identical(other.key, key) || other.key == key)&&(identical(other.label, label) || other.label == label)&&(identical(other.isVideo, isVideo) || other.isVideo == isVideo)&&(identical(other.isCode, isCode) || other.isCode == isCode)&&(identical(other.path, path) || other.path == path)&&(identical(other.projectPath, projectPath) || other.projectPath == projectPath)&&(identical(other.url, url) || other.url == url)&&(identical(other.base64, base64) || other.base64 == base64)&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType)&&(identical(other.modifiedAt, modifiedAt) || other.modifiedAt == modifiedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,key,label,isVideo,isCode,path,projectPath,url,base64,mimeType,modifiedAt);
}

@override
String toString() {
    return 'FeedbackMedia(key: $key, label: $label, isVideo: $isVideo, isCode: $isCode, path: $path, projectPath: $projectPath, url: $url, base64: $base64, mimeType: $mimeType, modifiedAt: $modifiedAt)';
}


}

/// @nodoc
abstract mixin class _$FeedbackMediaCopyWith<$Res> implements $FeedbackMediaCopyWith<$Res> {
  factory _$FeedbackMediaCopyWith(_FeedbackMedia value, $Res Function(_FeedbackMedia) _then) = __$FeedbackMediaCopyWithImpl;
@override @useResult
$Res call({
 String key, String label, bool isVideo, bool isCode, String? path, String? projectPath, String? url, String? base64, String mimeType, int? modifiedAt
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
@override @pragma('vm:prefer-inline') $Res call({Object? key = null,Object? label = null,Object? isVideo = null,Object? isCode = null,Object? path = freezed,Object? projectPath = freezed,Object? url = freezed,Object? base64 = freezed,Object? mimeType = null,Object? modifiedAt = freezed,}) {
  return _then(_FeedbackMedia(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,isVideo: null == isVideo ? _self.isVideo : isVideo // ignore: cast_nullable_to_non_nullable
as bool,isCode: null == isCode ? _self.isCode : isCode // ignore: cast_nullable_to_non_nullable
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

 String get id; FeedbackMedia get media; String get text; int? get positionMs; CodeAnchor? get code;
/// Create a copy of MediaFeedback
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MediaFeedbackCopyWith<MediaFeedback> get copyWith => _$MediaFeedbackCopyWithImpl<MediaFeedback>(this as MediaFeedback, _$identity);

  /// Serializes this MediaFeedback to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MediaFeedback;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MediaFeedback&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.media, _this.media) || other.media == _this.media)&&(identical(other.text, _this.text) || other.text == _this.text)&&(identical(other.positionMs, _this.positionMs) || other.positionMs == _this.positionMs)&&(identical(other.code, _this.code) || other.code == _this.code));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MediaFeedback;
  return Object.hash(runtimeType,_this.id,_this.media,_this.text,_this.positionMs,_this.code);
}

@override
String toString() {
  final _this = this as MediaFeedback;
  return 'MediaFeedback(id: ${_this.id}, media: ${_this.media}, text: ${_this.text}, positionMs: ${_this.positionMs}, code: ${_this.code})';
}


}

/// @nodoc
abstract mixin class $MediaFeedbackCopyWith<$Res>  {
  factory $MediaFeedbackCopyWith(MediaFeedback value, $Res Function(MediaFeedback) _then) = _$MediaFeedbackCopyWithImpl;
@useResult
$Res call({
 String id, FeedbackMedia media, String text, int? positionMs, CodeAnchor? code
});


$FeedbackMediaCopyWith<$Res> get media;$CodeAnchorCopyWith<$Res>? get code;

}
/// @nodoc
class _$MediaFeedbackCopyWithImpl<$Res>
    implements $MediaFeedbackCopyWith<$Res> {
  _$MediaFeedbackCopyWithImpl(this._self, this._then);

  final MediaFeedback _self;
  final $Res Function(MediaFeedback) _then;

/// Create a copy of MediaFeedback
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? media = null,Object? text = null,Object? positionMs = freezed,Object? code = freezed,}) {
  return _then(MediaFeedback(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,media: null == media ? _self.media : media // ignore: cast_nullable_to_non_nullable
as FeedbackMedia,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,positionMs: freezed == positionMs ? _self.positionMs : positionMs // ignore: cast_nullable_to_non_nullable
as int?,code: freezed == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as CodeAnchor?,
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
}/// Create a copy of MediaFeedback
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodeAnchorCopyWith<$Res>? get code {
    if (_self.code == null) {
    return null;
  }

  return $CodeAnchorCopyWith<$Res>(_self.code!, (value) {
    return _then(_self.copyWith(code: value));
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  FeedbackMedia media,  String text,  int? positionMs,  CodeAnchor? code)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MediaFeedback() when $default != null:
return $default(_that.id,_that.media,_that.text,_that.positionMs,_that.code);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  FeedbackMedia media,  String text,  int? positionMs,  CodeAnchor? code)  $default,) {final _that = this;
switch (_that) {
case _MediaFeedback():
return $default(_that.id,_that.media,_that.text,_that.positionMs,_that.code);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  FeedbackMedia media,  String text,  int? positionMs,  CodeAnchor? code)?  $default,) {final _that = this;
switch (_that) {
case _MediaFeedback() when $default != null:
return $default(_that.id,_that.media,_that.text,_that.positionMs,_that.code);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MediaFeedback implements MediaFeedback {
  const _MediaFeedback({required this.id, required this.media, required this.text, this.positionMs, this.code});
  factory _MediaFeedback.fromJson(Map<String, dynamic> json) => _$MediaFeedbackFromJson(json);

@override final  String id;
@override final  FeedbackMedia media;
@override final  String text;
@override final  int? positionMs;
@override final  CodeAnchor? code;

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
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MediaFeedback&&(identical(other.id, id) || other.id == id)&&(identical(other.media, media) || other.media == media)&&(identical(other.text, text) || other.text == text)&&(identical(other.positionMs, positionMs) || other.positionMs == positionMs)&&(identical(other.code, code) || other.code == code));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,media,text,positionMs,code);
}

@override
String toString() {
    return 'MediaFeedback(id: $id, media: $media, text: $text, positionMs: $positionMs, code: $code)';
}


}

/// @nodoc
abstract mixin class _$MediaFeedbackCopyWith<$Res> implements $MediaFeedbackCopyWith<$Res> {
  factory _$MediaFeedbackCopyWith(_MediaFeedback value, $Res Function(_MediaFeedback) _then) = __$MediaFeedbackCopyWithImpl;
@override @useResult
$Res call({
 String id, FeedbackMedia media, String text, int? positionMs, CodeAnchor? code
});


@override $FeedbackMediaCopyWith<$Res> get media;@override $CodeAnchorCopyWith<$Res>? get code;

}
/// @nodoc
class __$MediaFeedbackCopyWithImpl<$Res>
    implements _$MediaFeedbackCopyWith<$Res> {
  __$MediaFeedbackCopyWithImpl(this._self, this._then);

  final _MediaFeedback _self;
  final $Res Function(_MediaFeedback) _then;

/// Create a copy of MediaFeedback
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? media = null,Object? text = null,Object? positionMs = freezed,Object? code = freezed,}) {
  return _then(_MediaFeedback(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,media: null == media ? _self.media : media // ignore: cast_nullable_to_non_nullable
as FeedbackMedia,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,positionMs: freezed == positionMs ? _self.positionMs : positionMs // ignore: cast_nullable_to_non_nullable
as int?,code: freezed == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as CodeAnchor?,
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
}/// Create a copy of MediaFeedback
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CodeAnchorCopyWith<$Res>? get code {
    if (_self.code == null) {
    return null;
  }

  return $CodeAnchorCopyWith<$Res>(_self.code!, (value) {
    return _then(_self.copyWith(code: value));
  });
}
}


/// @nodoc
mixin _$CodeAnchor {

 DiffSource get source; DiffSide get side; int get startLine; int get endLine; int get lineCount; String get hunkHeader; String get excerpt;
/// Create a copy of CodeAnchor
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CodeAnchorCopyWith<CodeAnchor> get copyWith => _$CodeAnchorCopyWithImpl<CodeAnchor>(this as CodeAnchor, _$identity);

  /// Serializes this CodeAnchor to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as CodeAnchor;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CodeAnchor&&(identical(other.source, _this.source) || other.source == _this.source)&&(identical(other.side, _this.side) || other.side == _this.side)&&(identical(other.startLine, _this.startLine) || other.startLine == _this.startLine)&&(identical(other.endLine, _this.endLine) || other.endLine == _this.endLine)&&(identical(other.lineCount, _this.lineCount) || other.lineCount == _this.lineCount)&&(identical(other.hunkHeader, _this.hunkHeader) || other.hunkHeader == _this.hunkHeader)&&(identical(other.excerpt, _this.excerpt) || other.excerpt == _this.excerpt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CodeAnchor;
  return Object.hash(runtimeType,_this.source,_this.side,_this.startLine,_this.endLine,_this.lineCount,_this.hunkHeader,_this.excerpt);
}

@override
String toString() {
  final _this = this as CodeAnchor;
  return 'CodeAnchor(source: ${_this.source}, side: ${_this.side}, startLine: ${_this.startLine}, endLine: ${_this.endLine}, lineCount: ${_this.lineCount}, hunkHeader: ${_this.hunkHeader}, excerpt: ${_this.excerpt})';
}


}

/// @nodoc
abstract mixin class $CodeAnchorCopyWith<$Res>  {
  factory $CodeAnchorCopyWith(CodeAnchor value, $Res Function(CodeAnchor) _then) = _$CodeAnchorCopyWithImpl;
@useResult
$Res call({
 DiffSource source, DiffSide side, int startLine, int endLine, int lineCount, String hunkHeader, String excerpt
});




}
/// @nodoc
class _$CodeAnchorCopyWithImpl<$Res>
    implements $CodeAnchorCopyWith<$Res> {
  _$CodeAnchorCopyWithImpl(this._self, this._then);

  final CodeAnchor _self;
  final $Res Function(CodeAnchor) _then;

/// Create a copy of CodeAnchor
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? source = null,Object? side = null,Object? startLine = null,Object? endLine = null,Object? lineCount = null,Object? hunkHeader = null,Object? excerpt = null,}) {
  return _then(CodeAnchor(
source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as DiffSource,side: null == side ? _self.side : side // ignore: cast_nullable_to_non_nullable
as DiffSide,startLine: null == startLine ? _self.startLine : startLine // ignore: cast_nullable_to_non_nullable
as int,endLine: null == endLine ? _self.endLine : endLine // ignore: cast_nullable_to_non_nullable
as int,lineCount: null == lineCount ? _self.lineCount : lineCount // ignore: cast_nullable_to_non_nullable
as int,hunkHeader: null == hunkHeader ? _self.hunkHeader : hunkHeader // ignore: cast_nullable_to_non_nullable
as String,excerpt: null == excerpt ? _self.excerpt : excerpt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [CodeAnchor].
extension CodeAnchorPatterns on CodeAnchor {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CodeAnchor value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CodeAnchor() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CodeAnchor value)  $default,){
final _that = this;
switch (_that) {
case _CodeAnchor():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CodeAnchor value)?  $default,){
final _that = this;
switch (_that) {
case _CodeAnchor() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DiffSource source,  DiffSide side,  int startLine,  int endLine,  int lineCount,  String hunkHeader,  String excerpt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CodeAnchor() when $default != null:
return $default(_that.source,_that.side,_that.startLine,_that.endLine,_that.lineCount,_that.hunkHeader,_that.excerpt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DiffSource source,  DiffSide side,  int startLine,  int endLine,  int lineCount,  String hunkHeader,  String excerpt)  $default,) {final _that = this;
switch (_that) {
case _CodeAnchor():
return $default(_that.source,_that.side,_that.startLine,_that.endLine,_that.lineCount,_that.hunkHeader,_that.excerpt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DiffSource source,  DiffSide side,  int startLine,  int endLine,  int lineCount,  String hunkHeader,  String excerpt)?  $default,) {final _that = this;
switch (_that) {
case _CodeAnchor() when $default != null:
return $default(_that.source,_that.side,_that.startLine,_that.endLine,_that.lineCount,_that.hunkHeader,_that.excerpt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CodeAnchor implements CodeAnchor {
  const _CodeAnchor({required this.source, required this.side, required this.startLine, required this.endLine, required this.lineCount, required this.hunkHeader, required this.excerpt});
  factory _CodeAnchor.fromJson(Map<String, dynamic> json) => _$CodeAnchorFromJson(json);

@override final  DiffSource source;
@override final  DiffSide side;
@override final  int startLine;
@override final  int endLine;
@override final  int lineCount;
@override final  String hunkHeader;
@override final  String excerpt;

/// Create a copy of CodeAnchor
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CodeAnchorCopyWith<_CodeAnchor> get copyWith => __$CodeAnchorCopyWithImpl<_CodeAnchor>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CodeAnchorToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CodeAnchor&&(identical(other.source, source) || other.source == source)&&(identical(other.side, side) || other.side == side)&&(identical(other.startLine, startLine) || other.startLine == startLine)&&(identical(other.endLine, endLine) || other.endLine == endLine)&&(identical(other.lineCount, lineCount) || other.lineCount == lineCount)&&(identical(other.hunkHeader, hunkHeader) || other.hunkHeader == hunkHeader)&&(identical(other.excerpt, excerpt) || other.excerpt == excerpt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,source,side,startLine,endLine,lineCount,hunkHeader,excerpt);
}

@override
String toString() {
    return 'CodeAnchor(source: $source, side: $side, startLine: $startLine, endLine: $endLine, lineCount: $lineCount, hunkHeader: $hunkHeader, excerpt: $excerpt)';
}


}

/// @nodoc
abstract mixin class _$CodeAnchorCopyWith<$Res> implements $CodeAnchorCopyWith<$Res> {
  factory _$CodeAnchorCopyWith(_CodeAnchor value, $Res Function(_CodeAnchor) _then) = __$CodeAnchorCopyWithImpl;
@override @useResult
$Res call({
 DiffSource source, DiffSide side, int startLine, int endLine, int lineCount, String hunkHeader, String excerpt
});




}
/// @nodoc
class __$CodeAnchorCopyWithImpl<$Res>
    implements _$CodeAnchorCopyWith<$Res> {
  __$CodeAnchorCopyWithImpl(this._self, this._then);

  final _CodeAnchor _self;
  final $Res Function(_CodeAnchor) _then;

/// Create a copy of CodeAnchor
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? source = null,Object? side = null,Object? startLine = null,Object? endLine = null,Object? lineCount = null,Object? hunkHeader = null,Object? excerpt = null,}) {
  return _then(_CodeAnchor(
source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as DiffSource,side: null == side ? _self.side : side // ignore: cast_nullable_to_non_nullable
as DiffSide,startLine: null == startLine ? _self.startLine : startLine // ignore: cast_nullable_to_non_nullable
as int,endLine: null == endLine ? _self.endLine : endLine // ignore: cast_nullable_to_non_nullable
as int,lineCount: null == lineCount ? _self.lineCount : lineCount // ignore: cast_nullable_to_non_nullable
as int,hunkHeader: null == hunkHeader ? _self.hunkHeader : hunkHeader // ignore: cast_nullable_to_non_nullable
as String,excerpt: null == excerpt ? _self.excerpt : excerpt // ignore: cast_nullable_to_non_nullable
as String,
  ));
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
  final _this = this as MediaFeedbackState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MediaFeedbackState&&const DeepCollectionEquality().equals(other.sessions, _this.sessions));
}


@override
int get hashCode {
  final _this = this as MediaFeedbackState;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.sessions));
}

@override
String toString() {
  final _this = this as MediaFeedbackState;
  return 'MediaFeedbackState(sessions: ${_this.sessions})';
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
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MediaFeedbackState&&const DeepCollectionEquality().equals(other.sessions, _sessions));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_sessions));
}

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
