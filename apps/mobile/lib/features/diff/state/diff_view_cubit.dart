import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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
  StreamSubscription<DiffImageResultMessage>? _diffImageSub;
  final String? _projectPath;

  DiffViewCubit({
    required BridgeService bridge,
    String? initialDiff,
    String? projectPath,
    Set<String>? initialSelectedHunkKeys,
  }) : _bridge = bridge,
       _projectPath = projectPath,
       super(_initialState(initialDiff, projectPath, initialSelectedHunkKeys)) {
    if (projectPath != null) {
      _requestDiff(projectPath, initialSelectedHunkKeys);
      _diffImageSub = _bridge.diffImageResults.listen(_onDiffImageResult);
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
        final files = _mergeImageChanges(
          parseDiff(result.diff),
          result.imageChanges,
        );
        emit(
          state.copyWith(
            loading: false,
            files: files,
            selectionMode: hasSelection,
            selectedHunkKeys: initialSelectedHunkKeys ?? const {},
          ),
        );
      }
    });
    _bridge.send(ClientMessage.getDiff(projectPath));
  }

  /// Merge image change data from the server into parsed diff files.
  List<DiffFile> _mergeImageChanges(
    List<DiffFile> files,
    List<DiffImageChange> imageChanges,
  ) {
    if (imageChanges.isEmpty) return files;

    final imageMap = <String, DiffImageChange>{
      for (final ic in imageChanges) ic.filePath: ic,
    };

    return files.map((file) {
      final ic = imageMap[file.filePath];
      if (ic == null) return file;

      // Auto-display (≤ auto threshold): loaded=true even if base64 is missing
      // (server may fail to read but we don't want "tap to load" for small files).
      // On-demand (loadable): loaded=false until explicitly fetched.
      final hasAnyData = ic.oldBase64 != null || ic.newBase64 != null;
      final isAutoDisplay = !ic.loadable && hasAnyData;

      final imageData = DiffImageData(
        oldSize: ic.oldSize,
        newSize: ic.newSize,
        oldBytes: ic.oldBase64 != null ? base64Decode(ic.oldBase64!) : null,
        newBytes: ic.newBase64 != null ? base64Decode(ic.newBase64!) : null,
        mimeType: ic.mimeType,
        isSvg: ic.isSvg,
        loadable: ic.loadable,
        loaded: isAutoDisplay,
      );

      return DiffFile(
        filePath: file.filePath,
        hunks: file.hunks,
        isBinary: file.isBinary,
        isNewFile: file.isNewFile,
        isDeleted: file.isDeleted,
        isImage: true,
        imageData: imageData,
      );
    }).toList();
  }

  /// Load image data on demand (for images between auto-display and max thresholds).
  void loadImage(int fileIdx) {
    final projectPath = _projectPath;
    if (projectPath == null) return;
    if (fileIdx >= state.files.length) return;
    final file = state.files[fileIdx];
    if (file.imageData == null || !file.imageData!.loadable) return;
    if (state.loadingImageIndices.contains(fileIdx)) return;

    emit(
      state.copyWith(
        loadingImageIndices: {...state.loadingImageIndices, fileIdx},
      ),
    );

    if (!file.isDeleted) {
      _bridge.send(
        ClientMessage.getDiffImage(projectPath, file.filePath, 'new'),
      );
    }
    if (!file.isNewFile) {
      _bridge.send(
        ClientMessage.getDiffImage(projectPath, file.filePath, 'old'),
      );
    }
  }

  void _onDiffImageResult(DiffImageResultMessage result) {
    final files = state.files;
    final idx = files.indexWhere((f) => f.filePath == result.filePath);
    if (idx == -1) return;

    final file = files[idx];
    final existing = file.imageData;
    if (existing == null) return;

    Uint8List? bytes;
    if (result.base64 != null) {
      bytes = base64Decode(result.base64!);
    }

    final updated = result.version == 'old'
        ? existing.copyWith(oldBytes: bytes, loaded: true)
        : existing.copyWith(newBytes: bytes, loaded: true);

    final newFiles = List<DiffFile>.from(files);
    newFiles[idx] = file.copyWithImageData(updated);

    // Check if both sides are loaded (or not needed)
    final bothLoaded =
        (file.isNewFile || updated.oldBytes != null) &&
        (file.isDeleted || updated.newBytes != null);

    emit(
      state.copyWith(
        files: newFiles,
        loadingImageIndices: bothLoaded
            ? (Set<int>.from(state.loadingImageIndices)..remove(idx))
            : state.loadingImageIndices,
      ),
    );
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
    _diffImageSub?.cancel();
    return super.close();
  }
}
