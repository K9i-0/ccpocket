import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../models/messages.dart';
import '../../../providers/bridge_providers.dart';
import '../../../utils/diff_parser.dart';
import 'diff_view_state.dart';

part 'diff_view_notifier.g.dart';

/// Manages diff viewer state: file parsing, collapse/expand, and filtering.
///
/// Two modes controlled by build parameters:
/// - [initialDiff] provided → parse immediately (individual tool result).
/// - [projectPath] provided → request `git diff` from Bridge and subscribe.
@riverpod
class DiffViewNotifier extends _$DiffViewNotifier {
  StreamSubscription<DiffResultMessage>? _diffSub;

  @override
  DiffViewState build({String? initialDiff, String? projectPath}) {
    ref.onDispose(() {
      _diffSub?.cancel();
    });

    if (initialDiff != null) {
      return DiffViewState(files: parseDiff(initialDiff));
    }

    if (projectPath != null) {
      _requestDiff(projectPath);
      return const DiffViewState(loading: true);
    }

    return const DiffViewState();
  }

  void _requestDiff(String projectPath) {
    final bridge = ref.read(bridgeServiceProvider);
    _diffSub = bridge.diffResults.listen((result) {
      if (result.error != null) {
        state = state.copyWith(loading: false, error: result.error);
      } else if (result.diff.trim().isEmpty) {
        state = state.copyWith(loading: false, files: []);
      } else {
        state = state.copyWith(loading: false, files: parseDiff(result.diff));
      }
    });
    bridge.send(ClientMessage.getDiff(projectPath));
  }

  // ---- UI commands (Path B) ----

  /// Toggle collapse state for a file at [fileIdx].
  void toggleCollapse(int fileIdx) {
    final current = state.collapsedFileIndices;
    state = state.copyWith(
      collapsedFileIndices: current.contains(fileIdx)
          ? (Set<int>.from(current)..remove(fileIdx))
          : {...current, fileIdx},
    );
  }

  /// Replace hidden file indices with [indices].
  void setHiddenFiles(Set<int> indices) {
    state = state.copyWith(hiddenFileIndices: indices);
  }

  /// Toggle visibility for a single file at [index].
  void toggleFileVisibility(int index) {
    final current = state.hiddenFileIndices;
    state = state.copyWith(
      hiddenFileIndices: current.contains(index)
          ? (Set<int>.from(current)..remove(index))
          : {...current, index},
    );
  }

  /// Show all files (clear hidden filter).
  void clearHidden() {
    state = state.copyWith(hiddenFileIndices: const {});
  }
}
