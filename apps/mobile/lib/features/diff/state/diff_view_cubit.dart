import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/messages.dart';
import '../../../services/bridge_service.dart';
import '../../../utils/diff_parser.dart';
import 'diff_view_state.dart';

/// Manages diff viewer state: file parsing, collapse/expand, and filtering.
///
/// Two modes controlled by constructor parameters:
/// - [initialDiff] provided → parse immediately (individual tool result).
/// - [projectPath] provided → request `git diff` from Bridge and subscribe.
class DiffViewCubit extends Cubit<DiffViewState> {
  final BridgeService _bridge;
  StreamSubscription<DiffResultMessage>? _diffSub;

  DiffViewCubit({
    required BridgeService bridge,
    String? initialDiff,
    String? projectPath,
    Set<String>? initialSelectedHunkKeys,
  }) : _bridge = bridge,
       super(_initialState(initialDiff, projectPath, initialSelectedHunkKeys)) {
    if (projectPath != null) {
      _requestDiff(projectPath, initialSelectedHunkKeys);
    }
  }

  static DiffViewState _initialState(
    String? initialDiff,
    String? projectPath,
    Set<String>? initialSelectedHunkKeys,
  ) {
    final hasSelection =
        initialSelectedHunkKeys != null && initialSelectedHunkKeys.isNotEmpty;
    if (initialDiff != null) {
      return DiffViewState(
        files: parseDiff(initialDiff),
        selectionMode: hasSelection,
        selectedHunkKeys: initialSelectedHunkKeys ?? const {},
      );
    }
    if (projectPath != null) {
      return const DiffViewState(loading: true);
    }
    return const DiffViewState();
  }

  void _requestDiff(String projectPath, Set<String>? initialSelectedHunkKeys) {
    final hasSelection =
        initialSelectedHunkKeys != null && initialSelectedHunkKeys.isNotEmpty;
    _diffSub = _bridge.diffResults.listen((result) {
      if (result.error != null) {
        emit(state.copyWith(loading: false, error: result.error));
      } else if (result.diff.trim().isEmpty) {
        emit(state.copyWith(loading: false, files: []));
      } else {
        emit(
          state.copyWith(
            loading: false,
            files: parseDiff(result.diff),
            selectionMode: hasSelection,
            selectedHunkKeys: initialSelectedHunkKeys ?? const {},
          ),
        );
      }
    });
    _bridge.send(ClientMessage.getDiff(projectPath));
  }

  /// Toggle collapse state for a file at [fileIdx].
  void toggleCollapse(int fileIdx) {
    final current = state.collapsedFileIndices;
    emit(
      state.copyWith(
        collapsedFileIndices: current.contains(fileIdx)
            ? (Set<int>.from(current)..remove(fileIdx))
            : {...current, fileIdx},
      ),
    );
  }

  /// Replace hidden file indices with [indices].
  void setHiddenFiles(Set<int> indices) {
    emit(state.copyWith(hiddenFileIndices: indices));
  }

  /// Toggle visibility for a single file at [index].
  void toggleFileVisibility(int index) {
    final current = state.hiddenFileIndices;
    emit(
      state.copyWith(
        hiddenFileIndices: current.contains(index)
            ? (Set<int>.from(current)..remove(index))
            : {...current, index},
      ),
    );
  }

  /// Show all files (clear hidden filter).
  void clearHidden() {
    emit(state.copyWith(hiddenFileIndices: const {}));
  }

  // ---------------------------------------------------------------------------
  // Selection mode
  // ---------------------------------------------------------------------------

  /// Toggle selection mode on/off. Clears selection when turning off.
  void toggleSelectionMode() {
    emit(
      state.copyWith(
        selectionMode: !state.selectionMode,
        selectedHunkKeys: const {},
      ),
    );
  }

  /// Toggle all hunks of a file.
  void toggleFileSelection(int fileIdx) {
    final file = state.files[fileIdx];
    final allKeys = List.generate(
      file.hunks.length,
      (i) => '$fileIdx:$i',
    ).toSet();
    final current = state.selectedHunkKeys;

    // If all hunks are selected → deselect all; otherwise → select all.
    final allSelected = allKeys.every(current.contains);
    if (allSelected) {
      emit(
        state.copyWith(
          selectedHunkKeys: Set<String>.from(current)..removeAll(allKeys),
        ),
      );
    } else {
      emit(state.copyWith(selectedHunkKeys: {...current, ...allKeys}));
    }
  }

  /// Toggle a single hunk.
  void toggleHunkSelection(int fileIdx, int hunkIdx) {
    final key = '$fileIdx:$hunkIdx';
    final current = state.selectedHunkKeys;
    emit(
      state.copyWith(
        selectedHunkKeys: current.contains(key)
            ? (Set<String>.from(current)..remove(key))
            : {...current, key},
      ),
    );
  }

  /// Whether all hunks in a file are selected.
  bool isFileFullySelected(int fileIdx) {
    final file = state.files[fileIdx];
    if (file.hunks.isEmpty) return false;
    return List.generate(
      file.hunks.length,
      (i) => '$fileIdx:$i',
    ).every(state.selectedHunkKeys.contains);
  }

  /// Whether some (but not all) hunks in a file are selected.
  bool isFilePartiallySelected(int fileIdx) {
    final file = state.files[fileIdx];
    if (file.hunks.isEmpty) return false;
    final keys = List.generate(file.hunks.length, (i) => '$fileIdx:$i');
    final selectedCount = keys.where(state.selectedHunkKeys.contains).length;
    return selectedCount > 0 && selectedCount < keys.length;
  }

  /// Whether any hunk is selected.
  bool get hasAnySelection => state.selectedHunkKeys.isNotEmpty;

  /// Count of fully selected files and partially selected hunk count.
  /// Returns (fullySelectedFiles, partialHunks).
  ({int files, int hunks}) get selectionSummary {
    var fullFiles = 0;
    var partialHunks = 0;
    for (var i = 0; i < state.files.length; i++) {
      final file = state.files[i];
      final keys = List.generate(file.hunks.length, (h) => '$i:$h');
      final selected = keys.where(state.selectedHunkKeys.contains).length;
      if (selected == 0) continue;
      if (selected == file.hunks.length) {
        fullFiles++;
      } else {
        partialHunks += selected;
      }
    }
    return (files: fullFiles, hunks: partialHunks);
  }

  @override
  Future<void> close() {
    _diffSub?.cancel();
    return super.close();
  }
}
