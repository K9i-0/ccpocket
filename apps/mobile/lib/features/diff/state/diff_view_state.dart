import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../utils/diff_parser.dart';

part 'diff_view_state.freezed.dart';

/// State for the diff viewer screen.
@freezed
abstract class DiffViewState with _$DiffViewState {
  const factory DiffViewState({
    /// Parsed diff files.
    @Default([]) List<DiffFile> files,

    /// Indices of files hidden by the filter.
    @Default({}) Set<int> hiddenFileIndices,

    /// Indices of files whose hunks are collapsed.
    @Default({}) Set<int> collapsedFileIndices,

    /// Whether a diff request is in progress.
    @Default(false) bool loading,

    /// Error message from parsing or server request.
    String? error,

    /// Whether selection mode is active.
    @Default(false) bool selectionMode,

    /// Selected hunk keys in the format "$fileIdx:$hunkIdx".
    @Default({}) Set<String> selectedHunkKeys,

    /// Indices of image files currently loading on demand.
    @Default({}) Set<int> loadingImageIndices,
  }) = _DiffViewState;
}
