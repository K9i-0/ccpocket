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
  }) : _bridge = bridge,
       super(_initialState(initialDiff, projectPath)) {
    if (projectPath != null) {
      _requestDiff(projectPath);
    }
  }

  static DiffViewState _initialState(String? initialDiff, String? projectPath) {
    if (initialDiff != null) {
      return DiffViewState(files: parseDiff(initialDiff));
    }
    if (projectPath != null) {
      return const DiffViewState(loading: true);
    }
    return const DiffViewState();
  }

  void _requestDiff(String projectPath) {
    _diffSub = _bridge.diffResults.listen((result) {
      if (result.error != null) {
        emit(state.copyWith(loading: false, error: result.error));
      } else if (result.diff.trim().isEmpty) {
        emit(state.copyWith(loading: false, files: []));
      } else {
        emit(state.copyWith(loading: false, files: parseDiff(result.diff)));
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

  @override
  Future<void> close() {
    _diffSub?.cancel();
    return super.close();
  }
}
