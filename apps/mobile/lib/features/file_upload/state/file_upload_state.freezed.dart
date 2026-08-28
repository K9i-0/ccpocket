// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'file_upload_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FileUploadItemState {

 String get id; String get fileName; int get sizeBytes; int get sentBytes; FileUploadItemStatus get status; String? get uploadedPath; String? get errorCode;
/// Create a copy of FileUploadItemState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FileUploadItemStateCopyWith<FileUploadItemState> get copyWith => _$FileUploadItemStateCopyWithImpl<FileUploadItemState>(this as FileUploadItemState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FileUploadItemState&&(identical(other.id, id) || other.id == id)&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.sizeBytes, sizeBytes) || other.sizeBytes == sizeBytes)&&(identical(other.sentBytes, sentBytes) || other.sentBytes == sentBytes)&&(identical(other.status, status) || other.status == status)&&(identical(other.uploadedPath, uploadedPath) || other.uploadedPath == uploadedPath)&&(identical(other.errorCode, errorCode) || other.errorCode == errorCode));
}


@override
int get hashCode => Object.hash(runtimeType,id,fileName,sizeBytes,sentBytes,status,uploadedPath,errorCode);

@override
String toString() {
  return 'FileUploadItemState(id: $id, fileName: $fileName, sizeBytes: $sizeBytes, sentBytes: $sentBytes, status: $status, uploadedPath: $uploadedPath, errorCode: $errorCode)';
}


}

/// @nodoc
abstract mixin class $FileUploadItemStateCopyWith<$Res>  {
  factory $FileUploadItemStateCopyWith(FileUploadItemState value, $Res Function(FileUploadItemState) _then) = _$FileUploadItemStateCopyWithImpl;
@useResult
$Res call({
 String id, String fileName, int sizeBytes, int sentBytes, FileUploadItemStatus status, String? uploadedPath, String? errorCode
});




}
/// @nodoc
class _$FileUploadItemStateCopyWithImpl<$Res>
    implements $FileUploadItemStateCopyWith<$Res> {
  _$FileUploadItemStateCopyWithImpl(this._self, this._then);

  final FileUploadItemState _self;
  final $Res Function(FileUploadItemState) _then;

/// Create a copy of FileUploadItemState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? fileName = null,Object? sizeBytes = null,Object? sentBytes = null,Object? status = null,Object? uploadedPath = freezed,Object? errorCode = freezed,}) {
  return _then(FileUploadItemState(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,sizeBytes: null == sizeBytes ? _self.sizeBytes : sizeBytes // ignore: cast_nullable_to_non_nullable
as int,sentBytes: null == sentBytes ? _self.sentBytes : sentBytes // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as FileUploadItemStatus,uploadedPath: freezed == uploadedPath ? _self.uploadedPath : uploadedPath // ignore: cast_nullable_to_non_nullable
as String?,errorCode: freezed == errorCode ? _self.errorCode : errorCode // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [FileUploadItemState].
extension FileUploadItemStatePatterns on FileUploadItemState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FileUploadItemState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FileUploadItemState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FileUploadItemState value)  $default,){
final _that = this;
switch (_that) {
case _FileUploadItemState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FileUploadItemState value)?  $default,){
final _that = this;
switch (_that) {
case _FileUploadItemState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String fileName,  int sizeBytes,  int sentBytes,  FileUploadItemStatus status,  String? uploadedPath,  String? errorCode)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FileUploadItemState() when $default != null:
return $default(_that.id,_that.fileName,_that.sizeBytes,_that.sentBytes,_that.status,_that.uploadedPath,_that.errorCode);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String fileName,  int sizeBytes,  int sentBytes,  FileUploadItemStatus status,  String? uploadedPath,  String? errorCode)  $default,) {final _that = this;
switch (_that) {
case _FileUploadItemState():
return $default(_that.id,_that.fileName,_that.sizeBytes,_that.sentBytes,_that.status,_that.uploadedPath,_that.errorCode);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String fileName,  int sizeBytes,  int sentBytes,  FileUploadItemStatus status,  String? uploadedPath,  String? errorCode)?  $default,) {final _that = this;
switch (_that) {
case _FileUploadItemState() when $default != null:
return $default(_that.id,_that.fileName,_that.sizeBytes,_that.sentBytes,_that.status,_that.uploadedPath,_that.errorCode);case _:
  return null;

}
}

}

/// @nodoc


class _FileUploadItemState implements FileUploadItemState {
  const _FileUploadItemState({required this.id, required this.fileName, required this.sizeBytes, this.sentBytes = 0, this.status = FileUploadItemStatus.pending, this.uploadedPath, this.errorCode});
  

@override final  String id;
@override final  String fileName;
@override final  int sizeBytes;
@override@JsonKey() final  int sentBytes;
@override@JsonKey() final  FileUploadItemStatus status;
@override final  String? uploadedPath;
@override final  String? errorCode;

/// Create a copy of FileUploadItemState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FileUploadItemStateCopyWith<_FileUploadItemState> get copyWith => __$FileUploadItemStateCopyWithImpl<_FileUploadItemState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FileUploadItemState&&(identical(other.id, id) || other.id == id)&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.sizeBytes, sizeBytes) || other.sizeBytes == sizeBytes)&&(identical(other.sentBytes, sentBytes) || other.sentBytes == sentBytes)&&(identical(other.status, status) || other.status == status)&&(identical(other.uploadedPath, uploadedPath) || other.uploadedPath == uploadedPath)&&(identical(other.errorCode, errorCode) || other.errorCode == errorCode));
}


@override
int get hashCode => Object.hash(runtimeType,id,fileName,sizeBytes,sentBytes,status,uploadedPath,errorCode);

@override
String toString() {
  return 'FileUploadItemState(id: $id, fileName: $fileName, sizeBytes: $sizeBytes, sentBytes: $sentBytes, status: $status, uploadedPath: $uploadedPath, errorCode: $errorCode)';
}


}

/// @nodoc
abstract mixin class _$FileUploadItemStateCopyWith<$Res> implements $FileUploadItemStateCopyWith<$Res> {
  factory _$FileUploadItemStateCopyWith(_FileUploadItemState value, $Res Function(_FileUploadItemState) _then) = __$FileUploadItemStateCopyWithImpl;
@override @useResult
$Res call({
 String id, String fileName, int sizeBytes, int sentBytes, FileUploadItemStatus status, String? uploadedPath, String? errorCode
});




}
/// @nodoc
class __$FileUploadItemStateCopyWithImpl<$Res>
    implements _$FileUploadItemStateCopyWith<$Res> {
  __$FileUploadItemStateCopyWithImpl(this._self, this._then);

  final _FileUploadItemState _self;
  final $Res Function(_FileUploadItemState) _then;

/// Create a copy of FileUploadItemState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? fileName = null,Object? sizeBytes = null,Object? sentBytes = null,Object? status = null,Object? uploadedPath = freezed,Object? errorCode = freezed,}) {
  return _then(_FileUploadItemState(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,sizeBytes: null == sizeBytes ? _self.sizeBytes : sizeBytes // ignore: cast_nullable_to_non_nullable
as int,sentBytes: null == sentBytes ? _self.sentBytes : sentBytes // ignore: cast_nullable_to_non_nullable
as int,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as FileUploadItemStatus,uploadedPath: freezed == uploadedPath ? _self.uploadedPath : uploadedPath // ignore: cast_nullable_to_non_nullable
as String?,errorCode: freezed == errorCode ? _self.errorCode : errorCode // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$FileUploadState {

 List<FileUploadItemState> get items; FileUploadConflictPolicy get conflictPolicy; bool get isRunning; bool get isCancelled; bool get isComplete; String? get errorMessage;
/// Create a copy of FileUploadState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FileUploadStateCopyWith<FileUploadState> get copyWith => _$FileUploadStateCopyWithImpl<FileUploadState>(this as FileUploadState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FileUploadState&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.conflictPolicy, conflictPolicy) || other.conflictPolicy == conflictPolicy)&&(identical(other.isRunning, isRunning) || other.isRunning == isRunning)&&(identical(other.isCancelled, isCancelled) || other.isCancelled == isCancelled)&&(identical(other.isComplete, isComplete) || other.isComplete == isComplete)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(items),conflictPolicy,isRunning,isCancelled,isComplete,errorMessage);

@override
String toString() {
  return 'FileUploadState(items: $items, conflictPolicy: $conflictPolicy, isRunning: $isRunning, isCancelled: $isCancelled, isComplete: $isComplete, errorMessage: $errorMessage)';
}


}

/// @nodoc
abstract mixin class $FileUploadStateCopyWith<$Res>  {
  factory $FileUploadStateCopyWith(FileUploadState value, $Res Function(FileUploadState) _then) = _$FileUploadStateCopyWithImpl;
@useResult
$Res call({
 List<FileUploadItemState> items, FileUploadConflictPolicy conflictPolicy, bool isRunning, bool isCancelled, bool isComplete, String? errorMessage
});




}
/// @nodoc
class _$FileUploadStateCopyWithImpl<$Res>
    implements $FileUploadStateCopyWith<$Res> {
  _$FileUploadStateCopyWithImpl(this._self, this._then);

  final FileUploadState _self;
  final $Res Function(FileUploadState) _then;

/// Create a copy of FileUploadState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? items = null,Object? conflictPolicy = null,Object? isRunning = null,Object? isCancelled = null,Object? isComplete = null,Object? errorMessage = freezed,}) {
  return _then(FileUploadState(
items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<FileUploadItemState>,conflictPolicy: null == conflictPolicy ? _self.conflictPolicy : conflictPolicy // ignore: cast_nullable_to_non_nullable
as FileUploadConflictPolicy,isRunning: null == isRunning ? _self.isRunning : isRunning // ignore: cast_nullable_to_non_nullable
as bool,isCancelled: null == isCancelled ? _self.isCancelled : isCancelled // ignore: cast_nullable_to_non_nullable
as bool,isComplete: null == isComplete ? _self.isComplete : isComplete // ignore: cast_nullable_to_non_nullable
as bool,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [FileUploadState].
extension FileUploadStatePatterns on FileUploadState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FileUploadState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FileUploadState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FileUploadState value)  $default,){
final _that = this;
switch (_that) {
case _FileUploadState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FileUploadState value)?  $default,){
final _that = this;
switch (_that) {
case _FileUploadState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<FileUploadItemState> items,  FileUploadConflictPolicy conflictPolicy,  bool isRunning,  bool isCancelled,  bool isComplete,  String? errorMessage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FileUploadState() when $default != null:
return $default(_that.items,_that.conflictPolicy,_that.isRunning,_that.isCancelled,_that.isComplete,_that.errorMessage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<FileUploadItemState> items,  FileUploadConflictPolicy conflictPolicy,  bool isRunning,  bool isCancelled,  bool isComplete,  String? errorMessage)  $default,) {final _that = this;
switch (_that) {
case _FileUploadState():
return $default(_that.items,_that.conflictPolicy,_that.isRunning,_that.isCancelled,_that.isComplete,_that.errorMessage);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<FileUploadItemState> items,  FileUploadConflictPolicy conflictPolicy,  bool isRunning,  bool isCancelled,  bool isComplete,  String? errorMessage)?  $default,) {final _that = this;
switch (_that) {
case _FileUploadState() when $default != null:
return $default(_that.items,_that.conflictPolicy,_that.isRunning,_that.isCancelled,_that.isComplete,_that.errorMessage);case _:
  return null;

}
}

}

/// @nodoc


class _FileUploadState implements FileUploadState {
  const _FileUploadState({ List<FileUploadItemState> items = const [], this.conflictPolicy = FileUploadConflictPolicy.rename, this.isRunning = false, this.isCancelled = false, this.isComplete = false, this.errorMessage}): _items = items;
  

 final  List<FileUploadItemState> _items;
@override@JsonKey() List<FileUploadItemState> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override@JsonKey() final  FileUploadConflictPolicy conflictPolicy;
@override@JsonKey() final  bool isRunning;
@override@JsonKey() final  bool isCancelled;
@override@JsonKey() final  bool isComplete;
@override final  String? errorMessage;

/// Create a copy of FileUploadState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FileUploadStateCopyWith<_FileUploadState> get copyWith => __$FileUploadStateCopyWithImpl<_FileUploadState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FileUploadState&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.conflictPolicy, conflictPolicy) || other.conflictPolicy == conflictPolicy)&&(identical(other.isRunning, isRunning) || other.isRunning == isRunning)&&(identical(other.isCancelled, isCancelled) || other.isCancelled == isCancelled)&&(identical(other.isComplete, isComplete) || other.isComplete == isComplete)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_items),conflictPolicy,isRunning,isCancelled,isComplete,errorMessage);

@override
String toString() {
  return 'FileUploadState(items: $items, conflictPolicy: $conflictPolicy, isRunning: $isRunning, isCancelled: $isCancelled, isComplete: $isComplete, errorMessage: $errorMessage)';
}


}

/// @nodoc
abstract mixin class _$FileUploadStateCopyWith<$Res> implements $FileUploadStateCopyWith<$Res> {
  factory _$FileUploadStateCopyWith(_FileUploadState value, $Res Function(_FileUploadState) _then) = __$FileUploadStateCopyWithImpl;
@override @useResult
$Res call({
 List<FileUploadItemState> items, FileUploadConflictPolicy conflictPolicy, bool isRunning, bool isCancelled, bool isComplete, String? errorMessage
});




}
/// @nodoc
class __$FileUploadStateCopyWithImpl<$Res>
    implements _$FileUploadStateCopyWith<$Res> {
  __$FileUploadStateCopyWithImpl(this._self, this._then);

  final _FileUploadState _self;
  final $Res Function(_FileUploadState) _then;

/// Create a copy of FileUploadState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? items = null,Object? conflictPolicy = null,Object? isRunning = null,Object? isCancelled = null,Object? isComplete = null,Object? errorMessage = freezed,}) {
  return _then(_FileUploadState(
items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<FileUploadItemState>,conflictPolicy: null == conflictPolicy ? _self.conflictPolicy : conflictPolicy // ignore: cast_nullable_to_non_nullable
as FileUploadConflictPolicy,isRunning: null == isRunning ? _self.isRunning : isRunning // ignore: cast_nullable_to_non_nullable
as bool,isCancelled: null == isCancelled ? _self.isCancelled : isCancelled // ignore: cast_nullable_to_non_nullable
as bool,isComplete: null == isComplete ? _self.isComplete : isComplete // ignore: cast_nullable_to_non_nullable
as bool,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
