// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'file_browser_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BrowserLocation {

 String get directory; String get query; String? get file; int? get line;
/// Create a copy of BrowserLocation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BrowserLocationCopyWith<BrowserLocation> get copyWith => _$BrowserLocationCopyWithImpl<BrowserLocation>(this as BrowserLocation, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BrowserLocation&&(identical(other.directory, directory) || other.directory == directory)&&(identical(other.query, query) || other.query == query)&&(identical(other.file, file) || other.file == file)&&(identical(other.line, line) || other.line == line));
}


@override
int get hashCode => Object.hash(runtimeType,directory,query,file,line);

@override
String toString() {
  return 'BrowserLocation(directory: $directory, query: $query, file: $file, line: $line)';
}


}

/// @nodoc
abstract mixin class $BrowserLocationCopyWith<$Res>  {
  factory $BrowserLocationCopyWith(BrowserLocation value, $Res Function(BrowserLocation) _then) = _$BrowserLocationCopyWithImpl;
@useResult
$Res call({
 String directory, String query, String? file, int? line
});




}
/// @nodoc
class _$BrowserLocationCopyWithImpl<$Res>
    implements $BrowserLocationCopyWith<$Res> {
  _$BrowserLocationCopyWithImpl(this._self, this._then);

  final BrowserLocation _self;
  final $Res Function(BrowserLocation) _then;

/// Create a copy of BrowserLocation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? directory = null,Object? query = null,Object? file = freezed,Object? line = freezed,}) {
  return _then(BrowserLocation(
directory: null == directory ? _self.directory : directory // ignore: cast_nullable_to_non_nullable
as String,query: null == query ? _self.query : query // ignore: cast_nullable_to_non_nullable
as String,file: freezed == file ? _self.file : file // ignore: cast_nullable_to_non_nullable
as String?,line: freezed == line ? _self.line : line // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [BrowserLocation].
extension BrowserLocationPatterns on BrowserLocation {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BrowserLocation value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BrowserLocation() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BrowserLocation value)  $default,){
final _that = this;
switch (_that) {
case _BrowserLocation():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BrowserLocation value)?  $default,){
final _that = this;
switch (_that) {
case _BrowserLocation() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String directory,  String query,  String? file,  int? line)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BrowserLocation() when $default != null:
return $default(_that.directory,_that.query,_that.file,_that.line);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String directory,  String query,  String? file,  int? line)  $default,) {final _that = this;
switch (_that) {
case _BrowserLocation():
return $default(_that.directory,_that.query,_that.file,_that.line);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String directory,  String query,  String? file,  int? line)?  $default,) {final _that = this;
switch (_that) {
case _BrowserLocation() when $default != null:
return $default(_that.directory,_that.query,_that.file,_that.line);case _:
  return null;

}
}

}

/// @nodoc


class _BrowserLocation implements BrowserLocation {
  const _BrowserLocation({this.directory = '', this.query = '', this.file, this.line});
  

@override@JsonKey() final  String directory;
@override@JsonKey() final  String query;
@override final  String? file;
@override final  int? line;

/// Create a copy of BrowserLocation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BrowserLocationCopyWith<_BrowserLocation> get copyWith => __$BrowserLocationCopyWithImpl<_BrowserLocation>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BrowserLocation&&(identical(other.directory, directory) || other.directory == directory)&&(identical(other.query, query) || other.query == query)&&(identical(other.file, file) || other.file == file)&&(identical(other.line, line) || other.line == line));
}


@override
int get hashCode => Object.hash(runtimeType,directory,query,file,line);

@override
String toString() {
  return 'BrowserLocation(directory: $directory, query: $query, file: $file, line: $line)';
}


}

/// @nodoc
abstract mixin class _$BrowserLocationCopyWith<$Res> implements $BrowserLocationCopyWith<$Res> {
  factory _$BrowserLocationCopyWith(_BrowserLocation value, $Res Function(_BrowserLocation) _then) = __$BrowserLocationCopyWithImpl;
@override @useResult
$Res call({
 String directory, String query, String? file, int? line
});




}
/// @nodoc
class __$BrowserLocationCopyWithImpl<$Res>
    implements _$BrowserLocationCopyWith<$Res> {
  __$BrowserLocationCopyWithImpl(this._self, this._then);

  final _BrowserLocation _self;
  final $Res Function(_BrowserLocation) _then;

/// Create a copy of BrowserLocation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? directory = null,Object? query = null,Object? file = freezed,Object? line = freezed,}) {
  return _then(_BrowserLocation(
directory: null == directory ? _self.directory : directory // ignore: cast_nullable_to_non_nullable
as String,query: null == query ? _self.query : query // ignore: cast_nullable_to_non_nullable
as String,file: freezed == file ? _self.file : file // ignore: cast_nullable_to_non_nullable
as String?,line: freezed == line ? _self.line : line // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
mixin _$FileBrowserState {

 BrowserLocation get location; List<BrowserLocation> get history; List<ExploreEntry> get entries; List<String> get recentFiles; bool get loading; bool get indexTruncated; bool get legacyListing; String? get error;
/// Create a copy of FileBrowserState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FileBrowserStateCopyWith<FileBrowserState> get copyWith => _$FileBrowserStateCopyWithImpl<FileBrowserState>(this as FileBrowserState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FileBrowserState&&(identical(other.location, location) || other.location == location)&&const DeepCollectionEquality().equals(other.history, history)&&const DeepCollectionEquality().equals(other.entries, entries)&&const DeepCollectionEquality().equals(other.recentFiles, recentFiles)&&(identical(other.loading, loading) || other.loading == loading)&&(identical(other.indexTruncated, indexTruncated) || other.indexTruncated == indexTruncated)&&(identical(other.legacyListing, legacyListing) || other.legacyListing == legacyListing)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,location,const DeepCollectionEquality().hash(history),const DeepCollectionEquality().hash(entries),const DeepCollectionEquality().hash(recentFiles),loading,indexTruncated,legacyListing,error);

@override
String toString() {
  return 'FileBrowserState(location: $location, history: $history, entries: $entries, recentFiles: $recentFiles, loading: $loading, indexTruncated: $indexTruncated, legacyListing: $legacyListing, error: $error)';
}


}

/// @nodoc
abstract mixin class $FileBrowserStateCopyWith<$Res>  {
  factory $FileBrowserStateCopyWith(FileBrowserState value, $Res Function(FileBrowserState) _then) = _$FileBrowserStateCopyWithImpl;
@useResult
$Res call({
 BrowserLocation location, List<BrowserLocation> history, List<ExploreEntry> entries, List<String> recentFiles, bool loading, bool indexTruncated, bool legacyListing, String? error
});


$BrowserLocationCopyWith<$Res> get location;

}
/// @nodoc
class _$FileBrowserStateCopyWithImpl<$Res>
    implements $FileBrowserStateCopyWith<$Res> {
  _$FileBrowserStateCopyWithImpl(this._self, this._then);

  final FileBrowserState _self;
  final $Res Function(FileBrowserState) _then;

/// Create a copy of FileBrowserState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? location = null,Object? history = null,Object? entries = null,Object? recentFiles = null,Object? loading = null,Object? indexTruncated = null,Object? legacyListing = null,Object? error = freezed,}) {
  return _then(FileBrowserState(
location: null == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as BrowserLocation,history: null == history ? _self.history : history // ignore: cast_nullable_to_non_nullable
as List<BrowserLocation>,entries: null == entries ? _self.entries : entries // ignore: cast_nullable_to_non_nullable
as List<ExploreEntry>,recentFiles: null == recentFiles ? _self.recentFiles : recentFiles // ignore: cast_nullable_to_non_nullable
as List<String>,loading: null == loading ? _self.loading : loading // ignore: cast_nullable_to_non_nullable
as bool,indexTruncated: null == indexTruncated ? _self.indexTruncated : indexTruncated // ignore: cast_nullable_to_non_nullable
as bool,legacyListing: null == legacyListing ? _self.legacyListing : legacyListing // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of FileBrowserState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BrowserLocationCopyWith<$Res> get location {
  
  return $BrowserLocationCopyWith<$Res>(_self.location, (value) {
    return _then(_self.copyWith(location: value));
  });
}
}


/// Adds pattern-matching-related methods to [FileBrowserState].
extension FileBrowserStatePatterns on FileBrowserState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FileBrowserState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FileBrowserState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FileBrowserState value)  $default,){
final _that = this;
switch (_that) {
case _FileBrowserState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FileBrowserState value)?  $default,){
final _that = this;
switch (_that) {
case _FileBrowserState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( BrowserLocation location,  List<BrowserLocation> history,  List<ExploreEntry> entries,  List<String> recentFiles,  bool loading,  bool indexTruncated,  bool legacyListing,  String? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FileBrowserState() when $default != null:
return $default(_that.location,_that.history,_that.entries,_that.recentFiles,_that.loading,_that.indexTruncated,_that.legacyListing,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( BrowserLocation location,  List<BrowserLocation> history,  List<ExploreEntry> entries,  List<String> recentFiles,  bool loading,  bool indexTruncated,  bool legacyListing,  String? error)  $default,) {final _that = this;
switch (_that) {
case _FileBrowserState():
return $default(_that.location,_that.history,_that.entries,_that.recentFiles,_that.loading,_that.indexTruncated,_that.legacyListing,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( BrowserLocation location,  List<BrowserLocation> history,  List<ExploreEntry> entries,  List<String> recentFiles,  bool loading,  bool indexTruncated,  bool legacyListing,  String? error)?  $default,) {final _that = this;
switch (_that) {
case _FileBrowserState() when $default != null:
return $default(_that.location,_that.history,_that.entries,_that.recentFiles,_that.loading,_that.indexTruncated,_that.legacyListing,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _FileBrowserState implements FileBrowserState {
  const _FileBrowserState({this.location = const BrowserLocation(),  List<BrowserLocation> history = const [],  List<ExploreEntry> entries = const [],  List<String> recentFiles = const [], this.loading = false, this.indexTruncated = false, this.legacyListing = false, this.error}): _history = history,_entries = entries,_recentFiles = recentFiles;
  

@override@JsonKey() final  BrowserLocation location;
 final  List<BrowserLocation> _history;
@override@JsonKey() List<BrowserLocation> get history {
  if (_history is EqualUnmodifiableListView) return _history;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_history);
}

 final  List<ExploreEntry> _entries;
@override@JsonKey() List<ExploreEntry> get entries {
  if (_entries is EqualUnmodifiableListView) return _entries;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_entries);
}

 final  List<String> _recentFiles;
@override@JsonKey() List<String> get recentFiles {
  if (_recentFiles is EqualUnmodifiableListView) return _recentFiles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_recentFiles);
}

@override@JsonKey() final  bool loading;
@override@JsonKey() final  bool indexTruncated;
@override@JsonKey() final  bool legacyListing;
@override final  String? error;

/// Create a copy of FileBrowserState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FileBrowserStateCopyWith<_FileBrowserState> get copyWith => __$FileBrowserStateCopyWithImpl<_FileBrowserState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FileBrowserState&&(identical(other.location, location) || other.location == location)&&const DeepCollectionEquality().equals(other._history, _history)&&const DeepCollectionEquality().equals(other._entries, _entries)&&const DeepCollectionEquality().equals(other._recentFiles, _recentFiles)&&(identical(other.loading, loading) || other.loading == loading)&&(identical(other.indexTruncated, indexTruncated) || other.indexTruncated == indexTruncated)&&(identical(other.legacyListing, legacyListing) || other.legacyListing == legacyListing)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,location,const DeepCollectionEquality().hash(_history),const DeepCollectionEquality().hash(_entries),const DeepCollectionEquality().hash(_recentFiles),loading,indexTruncated,legacyListing,error);

@override
String toString() {
  return 'FileBrowserState(location: $location, history: $history, entries: $entries, recentFiles: $recentFiles, loading: $loading, indexTruncated: $indexTruncated, legacyListing: $legacyListing, error: $error)';
}


}

/// @nodoc
abstract mixin class _$FileBrowserStateCopyWith<$Res> implements $FileBrowserStateCopyWith<$Res> {
  factory _$FileBrowserStateCopyWith(_FileBrowserState value, $Res Function(_FileBrowserState) _then) = __$FileBrowserStateCopyWithImpl;
@override @useResult
$Res call({
 BrowserLocation location, List<BrowserLocation> history, List<ExploreEntry> entries, List<String> recentFiles, bool loading, bool indexTruncated, bool legacyListing, String? error
});


@override $BrowserLocationCopyWith<$Res> get location;

}
/// @nodoc
class __$FileBrowserStateCopyWithImpl<$Res>
    implements _$FileBrowserStateCopyWith<$Res> {
  __$FileBrowserStateCopyWithImpl(this._self, this._then);

  final _FileBrowserState _self;
  final $Res Function(_FileBrowserState) _then;

/// Create a copy of FileBrowserState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? location = null,Object? history = null,Object? entries = null,Object? recentFiles = null,Object? loading = null,Object? indexTruncated = null,Object? legacyListing = null,Object? error = freezed,}) {
  return _then(_FileBrowserState(
location: null == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as BrowserLocation,history: null == history ? _self._history : history // ignore: cast_nullable_to_non_nullable
as List<BrowserLocation>,entries: null == entries ? _self._entries : entries // ignore: cast_nullable_to_non_nullable
as List<ExploreEntry>,recentFiles: null == recentFiles ? _self._recentFiles : recentFiles // ignore: cast_nullable_to_non_nullable
as List<String>,loading: null == loading ? _self.loading : loading // ignore: cast_nullable_to_non_nullable
as bool,indexTruncated: null == indexTruncated ? _self.indexTruncated : indexTruncated // ignore: cast_nullable_to_non_nullable
as bool,legacyListing: null == legacyListing ? _self.legacyListing : legacyListing // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of FileBrowserState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BrowserLocationCopyWith<$Res> get location {
  
  return $BrowserLocationCopyWith<$Res>(_self.location, (value) {
    return _then(_self.copyWith(location: value));
  });
}
}

// dart format on
