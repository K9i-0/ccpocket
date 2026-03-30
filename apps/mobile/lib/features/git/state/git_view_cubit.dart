import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/messages.dart';
import '../../../services/bridge_service.dart';
import '../../../utils/diff_parser.dart';
import 'git_view_state.dart';

/// Manages diff viewer state: file parsing, collapse/expand, and git actions.
///
/// Two modes controlled by constructor parameters:
/// - [initialDiff] provided → parse immediately (individual tool result).
/// - [projectPath] provided → request `git diff` from Bridge and subscribe.
class GitViewCubit extends Cubit<GitViewState> {
  final BridgeService _bridge;
  StreamSubscription<DiffResultMessage>? _diffSub;
  StreamSubscription<DiffImageResultMessage>? _diffImageSub;
  StreamSubscription<GitStageResultMessage>? _stageSub;
  StreamSubscription<GitUnstageResultMessage>? _unstageSub;
  StreamSubscription<GitUnstageHunksResultMessage>? _unstageHunksSub;
  StreamSubscription<GitFetchResultMessage>? _fetchSub;
  StreamSubscription<GitPullResultMessage>? _pullSub;
  StreamSubscription<GitPushResultMessage>? _pushResultSub;
  StreamSubscription<GitCommitResultMessage>? _commitResultSub;
  StreamSubscription<GitRemoteStatusResultMessage>? _remoteStatusSub;
  StreamSubscription<GitRevertFileResultMessage>? _revertSub;
  StreamSubscription<GitRevertHunksResultMessage>? _revertHunksSub;
  StreamSubscription<GitBranchesResultMessage>? _branchesSub;
  StreamSubscription<GitCheckoutBranchResultMessage>? _checkoutSub;
  final String? _projectPath;
  final String? _sessionId;

  GitViewCubit({
    required BridgeService bridge,
    String? initialDiff,
    String? projectPath,
    String? worktreePath,
    String? sessionId,
  }) : _bridge = bridge,
       _projectPath = projectPath,
       _sessionId = sessionId,
       super(
         _initialState(
           initialDiff,
           projectPath,
           isWorktree: worktreePath != null,
         ),
       ) {
    if (projectPath != null) {
      _requestDiff(projectPath);
      _diffImageSub = _bridge.diffImageResults.listen(_onDiffImageResult);
      _stageSub = _bridge.gitStageResults.listen(_onStageResult);
      _unstageSub = _bridge.gitUnstageResults.listen(_onUnstageResult);
      _unstageHunksSub = _bridge.gitUnstageHunksResults.listen(
        _onUnstageHunksResult,
      );
      _fetchSub = _bridge.gitFetchResults.listen(_onFetchResult);
      _pullSub = _bridge.gitPullResults.listen(_onPullResult);
      _pushResultSub = _bridge.gitPushResults.listen(_onPushResult);
      _commitResultSub = _bridge.gitCommitResults.listen(_onCommitResult);
      _revertSub = _bridge.gitRevertFileResults.listen(_onRevertResult);
      _revertHunksSub = _bridge.gitRevertHunksResults.listen(
        _onRevertHunksResult,
      );
      _remoteStatusSub = _bridge.gitRemoteStatusResults.listen(_onRemoteStatus);
      _branchesSub = _bridge.gitBranchesResults.listen(_onBranchesResult);
      _checkoutSub = _bridge.gitCheckoutBranchResults.listen(_onCheckoutResult);
      // Fetch on init to get fresh remote state + current branch
      _fetchAndUpdateStatus();
      _bridge.send(ClientMessage.gitBranches(projectPath));
    }
  }

  static GitViewState _initialState(
    String? initialDiff,
    String? projectPath, {
    bool isWorktree = false,
  }) {
    if (initialDiff != null) {
      return GitViewState(files: parseDiff(initialDiff));
    }
    if (projectPath != null) {
      return GitViewState(loading: true, isWorktree: isWorktree);
    }
    return const GitViewState();
  }

  void _requestDiff(String projectPath) {
    _diffSub = _bridge.diffResults.listen((result) {
      if (result.error != null) {
        emit(
          state.copyWith(
            loading: false,
            error: result.error,
            errorCode: result.errorCode,
          ),
        );
      } else if (result.diff.trim().isEmpty) {
        emit(state.copyWith(loading: false, files: []));
      } else {
        final files = _mergeImageChanges(
          parseDiff(result.diff),
          result.imageChanges,
        );
        emit(state.copyWith(loading: false, files: files));
      }
    });
    _bridge.send(
      ClientMessage.getDiff(projectPath, staged: _stagedParamForMode),
    );
  }

  /// Whether this cubit supports refresh (projectPath mode).
  bool get canRefresh => _projectPath != null;

  /// The project path (for branch selector sheet).
  String? get projectPath => _projectPath;

  /// Re-request `git diff` from Bridge (e.g. for manual refresh).
  void refresh() {
    refreshDiffOnly();
    // Also fetch + update remote status on refresh
    _fetchAndUpdateStatus();
  }

  /// Re-request `git diff` from Bridge without fetching remote status.
  void refreshDiffOnly() {
    final projectPath = _projectPath;
    if (projectPath == null) return;
    emit(state.copyWith(loading: true, error: null));
    _bridge.send(
      ClientMessage.getDiff(projectPath, staged: _stagedParamForMode),
    );
  }

  bool get _stagedParamForMode => state.viewMode == GitViewMode.staged;

  /// Merge image change data from the server into parsed diff files.
  ///
  /// For each image file, checks the in-memory cache first. If the cache
  /// contains matching bytes (same oldSize/newSize), the cached bytes are
  /// restored immediately so the image renders without a network round-trip.
  List<DiffFile> _mergeImageChanges(
    List<DiffFile> files,
    List<DiffImageChange> imageChanges,
  ) {
    if (imageChanges.isEmpty) return files;

    final projectPath = _projectPath;
    final imageMap = <String, DiffImageChange>{
      for (final ic in imageChanges) ic.filePath: ic,
    };

    return files.map((file) {
      final ic = imageMap[file.filePath];
      if (ic == null) return file;

      // Check cache: if sizes match, restore bytes without network request.
      if (projectPath != null) {
        final cached = _bridge.getDiffImageCache(projectPath, file.filePath);
        if (cached != null &&
            cached.oldSize == ic.oldSize &&
            cached.newSize == ic.newSize) {
          final imageData = DiffImageData(
            oldSize: ic.oldSize,
            newSize: ic.newSize,
            oldBytes: cached.oldBytes,
            newBytes: cached.newBytes,
            mimeType: ic.mimeType,
            isSvg: ic.isSvg,
            loadable: ic.loadable,
            loaded: true,
            autoDisplay: ic.autoDisplay,
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
        }
      }

      // No cache hit — use embedded data or leave for lazy loading.
      final hasEmbeddedData = ic.oldBase64 != null || ic.newBase64 != null;

      final imageData = DiffImageData(
        oldSize: ic.oldSize,
        newSize: ic.newSize,
        oldBytes: ic.oldBase64 != null ? base64Decode(ic.oldBase64!) : null,
        newBytes: ic.newBase64 != null ? base64Decode(ic.newBase64!) : null,
        mimeType: ic.mimeType,
        isSvg: ic.isSvg,
        loadable: ic.loadable,
        loaded: hasEmbeddedData,
        autoDisplay: ic.autoDisplay,
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

  /// Maximum number of concurrent image loads to prevent server overload.
  static const _maxConcurrentLoads = 3;

  /// Load image data on demand (for loadable or auto-display images).
  void loadImage(int fileIdx) {
    final projectPath = _projectPath;
    if (projectPath == null) return;
    if (fileIdx >= state.files.length) return;
    final file = state.files[fileIdx];
    final imageData = file.imageData;
    if (imageData == null || !imageData.loadable) return;
    if (imageData.loaded) return;
    if (state.loadingImageIndices.contains(fileIdx)) return;
    // Throttle concurrent loads to avoid overwhelming the server
    if (state.loadingImageIndices.length >= _maxConcurrentLoads) return;

    emit(
      state.copyWith(
        loadingImageIndices: {...state.loadingImageIndices, fileIdx},
      ),
    );

    _bridge.send(
      ClientMessage.getDiffImage(projectPath, file.filePath, 'both'),
    );
  }

  void _onDiffImageResult(DiffImageResultMessage result) {
    final files = state.files;
    final idx = files.indexWhere((f) => f.filePath == result.filePath);
    if (idx == -1) return;

    final file = files[idx];
    final existing = file.imageData;
    if (existing == null) return;

    DiffImageData updated;
    bool removeFromLoading;

    if (result.version == 'both') {
      // Both old and new in a single response — always complete
      final oldBytes = result.oldBase64 != null
          ? base64Decode(result.oldBase64!)
          : null;
      final newBytes = result.newBase64 != null
          ? base64Decode(result.newBase64!)
          : null;
      updated = existing.copyWith(
        oldBytes: oldBytes,
        newBytes: newBytes,
        loaded: true,
      );
      removeFromLoading = true;
    } else {
      Uint8List? bytes;
      if (result.base64 != null) {
        bytes = base64Decode(result.base64!);
      }
      updated = result.version == 'old'
          ? existing.copyWith(oldBytes: bytes, loaded: true)
          : existing.copyWith(newBytes: bytes, loaded: true);

      // Check if both sides are loaded (or not needed)
      removeFromLoading =
          (file.isNewFile || updated.oldBytes != null) &&
          (file.isDeleted || updated.newBytes != null);
    }

    final newFiles = List<DiffFile>.from(files);
    newFiles[idx] = file.copyWithImageData(updated);

    // Persist loaded image bytes to in-memory cache for instant reuse.
    if (removeFromLoading && _projectPath != null) {
      _bridge.setDiffImageCache(
        _projectPath,
        file.filePath,
        DiffImageCacheEntry(
          oldSize: updated.oldSize,
          newSize: updated.newSize,
          oldBytes: updated.oldBytes,
          newBytes: updated.newBytes,
        ),
      );
    }

    emit(
      state.copyWith(
        files: newFiles,
        loadingImageIndices: removeFromLoading
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

  void toggleLineWrap() {
    emit(state.copyWith(lineWrapEnabled: !state.lineWrapEnabled));
  }

  // ---------------------------------------------------------------------------
  // Staging operations
  // ---------------------------------------------------------------------------

  /// Switch between unstaged (working-tree) and staged (index) diff view.
  void switchMode(GitViewMode mode) {
    if (mode == state.viewMode) return;
    emit(state.copyWith(viewMode: mode, loading: true, error: null, files: []));
    final projectPath = _projectPath;
    if (projectPath != null) {
      _bridge.send(
        ClientMessage.getDiff(projectPath, staged: mode == GitViewMode.staged),
      );
    }
  }

  /// Stage a single file by index.
  void stageFile(int fileIdx) {
    final projectPath = _projectPath;
    if (projectPath == null || fileIdx >= state.files.length) return;
    emit(state.copyWith(staging: true));
    _bridge.send(
      ClientMessage.gitStage(
        projectPath,
        files: [state.files[fileIdx].filePath],
      ),
    );
  }

  /// Unstage a single file by index.
  void unstageFile(int fileIdx) {
    final projectPath = _projectPath;
    if (projectPath == null || fileIdx >= state.files.length) return;
    emit(state.copyWith(staging: true));
    _bridge.send(
      ClientMessage.gitUnstage(
        projectPath,
        files: [state.files[fileIdx].filePath],
      ),
    );
  }

  void stageHunk(int fileIdx, int hunkIdx) {
    final projectPath = _projectPath;
    if (projectPath == null || fileIdx >= state.files.length) return;
    emit(state.copyWith(staging: true));
    _bridge.send(
      ClientMessage.gitStage(
        projectPath,
        hunks: [
          {'file': state.files[fileIdx].filePath, 'hunkIndex': hunkIdx},
        ],
      ),
    );
  }

  void unstageHunk(int fileIdx, int hunkIdx) {
    final projectPath = _projectPath;
    if (projectPath == null || fileIdx >= state.files.length) return;
    emit(state.copyWith(staging: true));
    _bridge.send(
      ClientMessage.gitUnstageHunks(projectPath, [
        {'file': state.files[fileIdx].filePath, 'hunkIndex': hunkIdx},
      ]),
    );
  }

  /// Revert (discard) changes for a single file.
  void revertFile(int fileIdx) {
    final projectPath = _projectPath;
    if (projectPath == null || fileIdx >= state.files.length) return;
    emit(state.copyWith(staging: true));
    _bridge.send(
      ClientMessage.gitRevertFile(projectPath, [state.files[fileIdx].filePath]),
    );
  }

  void revertHunk(int fileIdx, int hunkIdx) {
    final projectPath = _projectPath;
    if (projectPath == null || fileIdx >= state.files.length) return;
    emit(state.copyWith(staging: true));
    _bridge.send(
      ClientMessage.gitRevertHunks(projectPath, [
        {'file': state.files[fileIdx].filePath, 'hunkIndex': hunkIdx},
      ]),
    );
  }

  /// Stage all files.
  void stageAll() {
    final projectPath = _projectPath;
    if (projectPath == null || state.files.isEmpty) return;
    emit(state.copyWith(staging: true));
    _bridge.send(
      ClientMessage.gitStage(
        projectPath,
        files: state.files.map((f) => f.filePath).toList(),
      ),
    );
  }

  /// Unstage all files.
  void unstageAll() {
    final projectPath = _projectPath;
    if (projectPath == null || state.files.isEmpty) return;
    emit(state.copyWith(staging: true));
    _bridge.send(
      ClientMessage.gitUnstage(
        projectPath,
        files: state.files.map((f) => f.filePath).toList(),
      ),
    );
  }

  /// Revert all visible files.
  void revertAll() {
    final projectPath = _projectPath;
    if (projectPath == null || state.files.isEmpty) return;
    emit(state.copyWith(staging: true));
    _bridge.send(
      ClientMessage.gitRevertFile(
        projectPath,
        state.files.map((f) => f.filePath).toList(),
      ),
    );
  }

  void _onStageResult(GitStageResultMessage result) {
    if (result.success) {
      emit(state.copyWith(staging: false));
      refreshDiffOnly();
    } else {
      emit(state.copyWith(staging: false, error: result.error));
    }
  }

  void _onRevertResult(GitRevertFileResultMessage result) {
    if (result.success) {
      emit(state.copyWith(staging: false));
      refreshDiffOnly();
    } else {
      emit(state.copyWith(staging: false, error: result.error));
    }
  }

  void _onRevertHunksResult(GitRevertHunksResultMessage result) {
    if (result.success) {
      emit(state.copyWith(staging: false));
      refreshDiffOnly();
    } else {
      emit(state.copyWith(staging: false, error: result.error));
    }
  }

  void _onUnstageResult(GitUnstageResultMessage result) {
    if (result.success) {
      emit(state.copyWith(staging: false));
      refreshDiffOnly();
    } else {
      emit(state.copyWith(staging: false, error: result.error));
    }
  }

  void _onUnstageHunksResult(GitUnstageHunksResultMessage result) {
    if (result.success) {
      emit(state.copyWith(staging: false));
      refreshDiffOnly();
    } else {
      emit(state.copyWith(staging: false, error: result.error));
    }
  }

  // ---------------------------------------------------------------------------
  // Remote operations (fetch / pull / push)
  // ---------------------------------------------------------------------------

  void _fetchAndUpdateStatus() {
    final projectPath = _projectPath;
    if (projectPath == null) return;
    emit(state.copyWith(fetching: true));
    _bridge.send(ClientMessage.gitFetch(projectPath));
  }

  void _onFetchResult(GitFetchResultMessage result) {
    emit(state.copyWith(fetching: false));
    // After fetch, request remote status to get ahead/behind counts
    final projectPath = _projectPath;
    if (projectPath != null) {
      _bridge.send(ClientMessage.gitRemoteStatus(projectPath));
    }
  }

  void _onRemoteStatus(GitRemoteStatusResultMessage result) {
    emit(
      state.copyWith(
        commitsAhead: result.ahead,
        commitsBehind: result.behind,
        hasUpstream: result.hasUpstream,
      ),
    );
  }

  /// Pull from remote.
  void pull() {
    final projectPath = _projectPath;
    if (projectPath == null) return;
    emit(state.copyWith(pulling: true));
    _bridge.send(ClientMessage.gitPull(projectPath));
  }

  void _onPullResult(GitPullResultMessage result) {
    emit(state.copyWith(pulling: false));
    if (result.success) {
      refresh(); // refresh diff + remote status
    } else {
      emit(state.copyWith(error: result.error));
    }
  }

  /// Push to remote.
  void push() {
    final projectPath = _projectPath;
    if (projectPath == null) return;
    emit(state.copyWith(pushing: true));
    _bridge.send(ClientMessage.gitPush(projectPath));
  }

  void _onPushResult(GitPushResultMessage result) {
    emit(state.copyWith(pushing: false));
    if (result.success) {
      refresh();
    } else {
      emit(state.copyWith(error: result.error));
    }
  }

  void _onCommitResult(GitCommitResultMessage result) {
    if (result.success) {
      refresh();
    }
  }

  // ---------------------------------------------------------------------------
  // Branch operations
  // ---------------------------------------------------------------------------

  void _onBranchesResult(GitBranchesResultMessage result) {
    if (result.error == null) {
      emit(state.copyWith(currentBranch: result.current));
    }
  }

  void _onCheckoutResult(GitCheckoutBranchResultMessage result) {
    if (result.success) {
      // Refresh diff + branch + remote status after checkout
      refresh();
      final projectPath = _projectPath;
      if (projectPath != null) {
        _bridge.send(ClientMessage.gitBranches(projectPath));
      }
      // Update session branch info so session list card reflects the change
      if (_sessionId != null) {
        _bridge.send(ClientMessage.refreshBranch(_sessionId));
      }
    }
  }

  @override
  Future<void> close() {
    _diffSub?.cancel();
    _diffImageSub?.cancel();
    _stageSub?.cancel();
    _unstageSub?.cancel();
    _unstageHunksSub?.cancel();
    _revertSub?.cancel();
    _revertHunksSub?.cancel();
    _fetchSub?.cancel();
    _pullSub?.cancel();
    _pushResultSub?.cancel();
    _commitResultSub?.cancel();
    _remoteStatusSub?.cancel();
    _branchesSub?.cancel();
    _checkoutSub?.cancel();
    return super.close();
  }
}
