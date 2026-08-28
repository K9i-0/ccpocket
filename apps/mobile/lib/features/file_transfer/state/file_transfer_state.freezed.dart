// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'file_transfer_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FileTransferState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FileTransferState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'FileTransferState()';
}


}

/// @nodoc
class $FileTransferStateCopyWith<$Res>  {
$FileTransferStateCopyWith(FileTransferState _, $Res Function(FileTransferState) __);
}


/// Adds pattern-matching-related methods to [FileTransferState].
extension FileTransferStatePatterns on FileTransferState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( FileTransferIdle value)?  idle,TResult Function( FileTransferPreparing value)?  preparing,TResult Function( FileTransferDownloading value)?  downloading,TResult Function( FileTransferReady value)?  ready,TResult Function( FileTransferFailed value)?  failed,TResult Function( FileTransferCancelled value)?  cancelled,required TResult orElse(),}){
final _that = this;
switch (_that) {
case FileTransferIdle() when idle != null:
return idle(_that);case FileTransferPreparing() when preparing != null:
return preparing(_that);case FileTransferDownloading() when downloading != null:
return downloading(_that);case FileTransferReady() when ready != null:
return ready(_that);case FileTransferFailed() when failed != null:
return failed(_that);case FileTransferCancelled() when cancelled != null:
return cancelled(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( FileTransferIdle value)  idle,required TResult Function( FileTransferPreparing value)  preparing,required TResult Function( FileTransferDownloading value)  downloading,required TResult Function( FileTransferReady value)  ready,required TResult Function( FileTransferFailed value)  failed,required TResult Function( FileTransferCancelled value)  cancelled,}){
final _that = this;
switch (_that) {
case FileTransferIdle():
return idle(_that);case FileTransferPreparing():
return preparing(_that);case FileTransferDownloading():
return downloading(_that);case FileTransferReady():
return ready(_that);case FileTransferFailed():
return failed(_that);case FileTransferCancelled():
return cancelled(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( FileTransferIdle value)?  idle,TResult? Function( FileTransferPreparing value)?  preparing,TResult? Function( FileTransferDownloading value)?  downloading,TResult? Function( FileTransferReady value)?  ready,TResult? Function( FileTransferFailed value)?  failed,TResult? Function( FileTransferCancelled value)?  cancelled,}){
final _that = this;
switch (_that) {
case FileTransferIdle() when idle != null:
return idle(_that);case FileTransferPreparing() when preparing != null:
return preparing(_that);case FileTransferDownloading() when downloading != null:
return downloading(_that);case FileTransferReady() when ready != null:
return ready(_that);case FileTransferFailed() when failed != null:
return failed(_that);case FileTransferCancelled() when cancelled != null:
return cancelled(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  idle,TResult Function()?  preparing,TResult Function( int receivedBytes,  int totalBytes)?  downloading,TResult Function( String localPath,  String fileName,  String mimeType,  int sizeBytes)?  ready,TResult Function( String errorCode,  String message)?  failed,TResult Function()?  cancelled,required TResult orElse(),}) {final _that = this;
switch (_that) {
case FileTransferIdle() when idle != null:
return idle();case FileTransferPreparing() when preparing != null:
return preparing();case FileTransferDownloading() when downloading != null:
return downloading(_that.receivedBytes,_that.totalBytes);case FileTransferReady() when ready != null:
return ready(_that.localPath,_that.fileName,_that.mimeType,_that.sizeBytes);case FileTransferFailed() when failed != null:
return failed(_that.errorCode,_that.message);case FileTransferCancelled() when cancelled != null:
return cancelled();case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  idle,required TResult Function()  preparing,required TResult Function( int receivedBytes,  int totalBytes)  downloading,required TResult Function( String localPath,  String fileName,  String mimeType,  int sizeBytes)  ready,required TResult Function( String errorCode,  String message)  failed,required TResult Function()  cancelled,}) {final _that = this;
switch (_that) {
case FileTransferIdle():
return idle();case FileTransferPreparing():
return preparing();case FileTransferDownloading():
return downloading(_that.receivedBytes,_that.totalBytes);case FileTransferReady():
return ready(_that.localPath,_that.fileName,_that.mimeType,_that.sizeBytes);case FileTransferFailed():
return failed(_that.errorCode,_that.message);case FileTransferCancelled():
return cancelled();}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  idle,TResult? Function()?  preparing,TResult? Function( int receivedBytes,  int totalBytes)?  downloading,TResult? Function( String localPath,  String fileName,  String mimeType,  int sizeBytes)?  ready,TResult? Function( String errorCode,  String message)?  failed,TResult? Function()?  cancelled,}) {final _that = this;
switch (_that) {
case FileTransferIdle() when idle != null:
return idle();case FileTransferPreparing() when preparing != null:
return preparing();case FileTransferDownloading() when downloading != null:
return downloading(_that.receivedBytes,_that.totalBytes);case FileTransferReady() when ready != null:
return ready(_that.localPath,_that.fileName,_that.mimeType,_that.sizeBytes);case FileTransferFailed() when failed != null:
return failed(_that.errorCode,_that.message);case FileTransferCancelled() when cancelled != null:
return cancelled();case _:
  return null;

}
}

}

/// @nodoc


class FileTransferIdle implements FileTransferState {
  const FileTransferIdle();







@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FileTransferIdle);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'FileTransferState.idle()';
}


}




/// @nodoc


class FileTransferPreparing implements FileTransferState {
  const FileTransferPreparing();







@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FileTransferPreparing);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'FileTransferState.preparing()';
}


}




/// @nodoc


class FileTransferDownloading implements FileTransferState {
  const FileTransferDownloading({required this.receivedBytes, required this.totalBytes});


 final  int receivedBytes;
 final  int totalBytes;

/// Create a copy of FileTransferState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FileTransferDownloadingCopyWith<FileTransferDownloading> get copyWith => _$FileTransferDownloadingCopyWithImpl<FileTransferDownloading>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FileTransferDownloading&&(identical(other.receivedBytes, receivedBytes) || other.receivedBytes == receivedBytes)&&(identical(other.totalBytes, totalBytes) || other.totalBytes == totalBytes));
}


@override
int get hashCode => Object.hash(runtimeType,receivedBytes,totalBytes);

@override
String toString() {
  return 'FileTransferState.downloading(receivedBytes: $receivedBytes, totalBytes: $totalBytes)';
}


}

/// @nodoc
abstract mixin class $FileTransferDownloadingCopyWith<$Res> implements $FileTransferStateCopyWith<$Res> {
  factory $FileTransferDownloadingCopyWith(FileTransferDownloading value, $Res Function(FileTransferDownloading) _then) = _$FileTransferDownloadingCopyWithImpl;
@useResult
$Res call({
 int receivedBytes, int totalBytes
});




}
/// @nodoc
class _$FileTransferDownloadingCopyWithImpl<$Res>
    implements $FileTransferDownloadingCopyWith<$Res> {
  _$FileTransferDownloadingCopyWithImpl(this._self, this._then);

  final FileTransferDownloading _self;
  final $Res Function(FileTransferDownloading) _then;

/// Create a copy of FileTransferState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? receivedBytes = null,Object? totalBytes = null,}) {
  return _then(FileTransferDownloading(
receivedBytes: null == receivedBytes ? _self.receivedBytes : receivedBytes // ignore: cast_nullable_to_non_nullable
as int,totalBytes: null == totalBytes ? _self.totalBytes : totalBytes // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class FileTransferReady implements FileTransferState {
  const FileTransferReady({required this.localPath, required this.fileName, required this.mimeType, required this.sizeBytes});


 final  String localPath;
 final  String fileName;
 final  String mimeType;
 final  int sizeBytes;

/// Create a copy of FileTransferState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FileTransferReadyCopyWith<FileTransferReady> get copyWith => _$FileTransferReadyCopyWithImpl<FileTransferReady>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FileTransferReady&&(identical(other.localPath, localPath) || other.localPath == localPath)&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType)&&(identical(other.sizeBytes, sizeBytes) || other.sizeBytes == sizeBytes));
}


@override
int get hashCode => Object.hash(runtimeType,localPath,fileName,mimeType,sizeBytes);

@override
String toString() {
  return 'FileTransferState.ready(localPath: $localPath, fileName: $fileName, mimeType: $mimeType, sizeBytes: $sizeBytes)';
}


}

/// @nodoc
abstract mixin class $FileTransferReadyCopyWith<$Res> implements $FileTransferStateCopyWith<$Res> {
  factory $FileTransferReadyCopyWith(FileTransferReady value, $Res Function(FileTransferReady) _then) = _$FileTransferReadyCopyWithImpl;
@useResult
$Res call({
 String localPath, String fileName, String mimeType, int sizeBytes
});




}
/// @nodoc
class _$FileTransferReadyCopyWithImpl<$Res>
    implements $FileTransferReadyCopyWith<$Res> {
  _$FileTransferReadyCopyWithImpl(this._self, this._then);

  final FileTransferReady _self;
  final $Res Function(FileTransferReady) _then;

/// Create a copy of FileTransferState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? localPath = null,Object? fileName = null,Object? mimeType = null,Object? sizeBytes = null,}) {
  return _then(FileTransferReady(
localPath: null == localPath ? _self.localPath : localPath // ignore: cast_nullable_to_non_nullable
as String,fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,mimeType: null == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String,sizeBytes: null == sizeBytes ? _self.sizeBytes : sizeBytes // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class FileTransferFailed implements FileTransferState {
  const FileTransferFailed({required this.errorCode, required this.message});


 final  String errorCode;
 final  String message;

/// Create a copy of FileTransferState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FileTransferFailedCopyWith<FileTransferFailed> get copyWith => _$FileTransferFailedCopyWithImpl<FileTransferFailed>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FileTransferFailed&&(identical(other.errorCode, errorCode) || other.errorCode == errorCode)&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,errorCode,message);

@override
String toString() {
  return 'FileTransferState.failed(errorCode: $errorCode, message: $message)';
}


}

/// @nodoc
abstract mixin class $FileTransferFailedCopyWith<$Res> implements $FileTransferStateCopyWith<$Res> {
  factory $FileTransferFailedCopyWith(FileTransferFailed value, $Res Function(FileTransferFailed) _then) = _$FileTransferFailedCopyWithImpl;
@useResult
$Res call({
 String errorCode, String message
});




}
/// @nodoc
class _$FileTransferFailedCopyWithImpl<$Res>
    implements $FileTransferFailedCopyWith<$Res> {
  _$FileTransferFailedCopyWithImpl(this._self, this._then);

  final FileTransferFailed _self;
  final $Res Function(FileTransferFailed) _then;

/// Create a copy of FileTransferState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? errorCode = null,Object? message = null,}) {
  return _then(FileTransferFailed(
errorCode: null == errorCode ? _self.errorCode : errorCode // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class FileTransferCancelled implements FileTransferState {
  const FileTransferCancelled();







@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FileTransferCancelled);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'FileTransferState.cancelled()';
}


}




// dart format on
