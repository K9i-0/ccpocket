import 'package:freezed_annotation/freezed_annotation.dart';

import '../../explore/state/explore_state.dart';

part 'file_browser_state.freezed.dart';

@freezed
abstract class BrowserLocation with _$BrowserLocation {
  const factory BrowserLocation({
    @Default('') String directory,
    @Default('') String query,
    String? file,
    int? line,
  }) = _BrowserLocation;
}

@freezed
abstract class FileBrowserState with _$FileBrowserState {
  const factory FileBrowserState({
    @Default(BrowserLocation()) BrowserLocation location,
    @Default([]) List<BrowserLocation> history,
    @Default([]) List<ExploreEntry> entries,
    @Default([]) List<String> recentFiles,
    @Default(false) bool loading,
    @Default(false) bool indexTruncated,
    @Default(false) bool legacyListing,
    String? error,
  }) = _FileBrowserState;
}
