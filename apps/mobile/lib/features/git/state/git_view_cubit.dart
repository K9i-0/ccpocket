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
  static int _nextConsumerId = 0;
  static const _responseFamilies = <String>{
    'git-diff',
    'git-diff-image',
    'git-stage',
    'git-unstage',
    'git-unstage-hunks',
    'git-fetch',
    'git-pull',
    'git-push',
    'git-remote-status',
    'git-revert-file',
    'git-revert-hunks',
    'git-branches',
    'git-checkout-branch',
  };

  final BridgeService _bridge;
  final String _consumerId = 'git-view-${++_nextConsumerId}';
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
  final void Function({bool forceRemote})? _onStatusRefreshRequested;
  String? _latestDiffRequestId;
  final Map<String, String> _latestDiffImageRequestIds = {};
  final Map<String, String> _latestOperationRequestIds = {};

  String? _newWireRequestId(String family) {
    if (_latestOperationRequestIds.containsKey(family)) {
      _bridge.unregisterProjectResponseConsumer(family, _consumerId);
    }
    final requestId = _bridge.createProjectRequestId(family);
    _latestOperationRequestIds[family] = requestId;
    _bridge.registerProjectResponseConsumer(family, _consumerId);
    return _bridge.projectRequestIdForWire(requestId);
  }

  GitViewCubit({
    required BridgeService bridge,
    String? initialDiff,
    String? projectPath,
    String? worktreePath,
    String? sessionId,
    void Function({bool forceRemote})? onStatusRefreshRequested,
  }) : _bridge = bridge,
       _projectPath = projectPath,
       _sessionId = sessionId,
       _onStatusRefreshRequested = onStatusRefreshRequested,
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
      _bridge.send(
        ClientMessage.gitBranches(
          projectPath,
          requestId: _newWireRequestId('git-branches'),
        ),
      );
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
      if (!_acceptDiffResult(result)) return;
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
    _sendDiffRequest(projectPath);
  }

  void _sendDiffRequest(String projectPath) {
    if (_latestDiffRequestId != null) {
      _bridge.unregisterProjectResponseConsumer('git-diff', _consumerId);
    }
    final requestId = _bridge.createProjectRequestId('git-diff');
    _latestDiffRequestId = requestId;
    _bridge.registerProjectResponseConsumer('git-diff', _consumerId);
    _bridge.send(
      ClientMessage.getDiff(
        projectPath,
        staged: _stagedParamForMode,
        requestId: _bridge.projectRequestIdForWire(requestId),
      ),
    );
  }

  bool _acceptProjectResponse(
    ProjectCorrelatedMessage result,
    String responseFamily,
  ) {
    final responsePath = result.projectPath;
    if (responsePath != null && responsePath != _projectPath) return false;
    if (result.requestId != null) return true;
    return _bridge.canAcceptLegacyProjectResponse(responseFamily, _consumerId);
  }

  bool _acceptOperationResponse(
    ProjectCorrelatedMessage result,
    String responseFamily,
  ) {
    if (!_acceptProjectResponse(result, responseFamily)) return false;
    final requestId = result.requestId;
    final pendingRequestId = _latestOperationRequestIds[responseFamily];
    if (requestId != null && requestId != pendingRequestId) return false;
    if (pendingRequestId == null) return false;
    _latestOperationRequestIds.remove(responseFamily);
    _bridge.unregisterProjectResponseConsumer(responseFamily, _consumerId);
    return true;
  }

  bool _acceptDiffResult(DiffResultMessage result) {
    if (!_acceptProjectResponse(result, 'git-diff')) return false;
    final requestId = result.requestId;
    if (requestId != null && requestId != _latestDiffRequestId) return false;
    final staged = result.staged;
    if (staged != null && staged != _stagedParamForMode) return false;
    _latestDiffRequestId = null;
    _bridge.unregisterProjectResponseConsumer('git-diff', _consumerId);
    return true;
  }

  /// Whether this cubit supports refresh (projectPath mode).
  bool get canRefresh => _projectPath != null;

  /// The project path (for branch selector sheet).
  String? get projectPath => _projectPath;

  /// Re-request `git diff` from Bridge (e.g. for manual refresh).
  void refresh() {
    refreshDiffOnly(requestStatus: true, forceRemote: true);
    // Also fetch + update remote status on refresh
    _fetchAndUpdateStatus();
  }

  /// Re-request `git diff` from Bridge without fetching remote status.
  void refreshDiffOnly({bool requestStatus = false, bool forceRemote = false}) {
    final projectPath = _projectPath;
    if (projectPath == null) return;
    emit(state.copyWith(loading: true, error: null));
    _sendDiffRequest(projectPath);
    if (requestStatus) {
      _onStatusRefreshRequested?.call(forceRemote: forceRemote);
    }
  }

  /// Refresh after an external agent turn changed files.
  void refreshAfterExternalChange() {
    refreshDiffOnly(requestStatus: true);
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

    final requestId = _bridge.createProjectRequestId('git-diff-image');
    if (_latestDiffImageRequestIds.containsKey(file.filePath)) {
      _bridge.unregisterProjectResponseConsumer('git-diff-image', _consumerId);
    }
    _latestDiffImageRequestIds[file.filePath] = requestId;
    _bridge.registerProjectResponseConsumer('git-diff-image', _consumerId);
    _bridge.send(
      ClientMessage.getDiffImage(
        projectPath,
        file.filePath,
        'both',
        requestId: _bridge.projectRequestIdForWire(requestId),
      ),
    );
  }

  void _onDiffImageResult(DiffImageResultMessage result) {
    if (!_acceptProjectResponse(result, 'git-diff-image')) return;
    final requestId = result.requestId;
    if (requestId != null &&
        requestId != _latestDiffImageRequestIds[result.filePath]) {
      return;
    }
    _latestDiffImageRequestIds.remove(result.filePath);
    _bridge.unregisterProjectResponseConsumer('git-diff-image', _consumerId);
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
      _sendDiffRequest(projectPath);
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
        requestId: _newWireRequestId('git-stage'),
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
        requestId: _newWireRequestId('git-unstage'),
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
        requestId: _newWireRequestId('git-stage'),
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
      ], requestId: _newWireRequestId('git-unstage-hunks')),
    );
  }

  /// Revert (discard) changes for a single file.
  void revertFile(int fileIdx) {
    final projectPath = _projectPath;
    if (projectPath == null || fileIdx >= state.files.length) return;
    emit(state.copyWith(staging: true));
    _bridge.send(
      ClientMessage.gitRevertFile(projectPath, [
        state.files[fileIdx].filePath,
      ], requestId: _newWireRequestId('git-revert-file')),
    );
  }

  void revertHunk(int fileIdx, int hunkIdx) {
    final projectPath = _projectPath;
    if (projectPath == null || fileIdx >= state.files.length) return;
    emit(state.copyWith(staging: true));
    _bridge.send(
      ClientMessage.gitRevertHunks(projectPath, [
        {'file': state.files[fileIdx].filePath, 'hunkIndex': hunkIdx},
      ], requestId: _newWireRequestId('git-revert-hunks')),
    );
  }

  bool _pendingSwitchToStaged = false;
  bool _pendingSwitchToUnstaged = false;

  /// Stage all files.
  void stageAll() {
    final projectPath = _projectPath;
    if (projectPath == null || state.files.isEmpty) return;
    _pendingSwitchToStaged = true;
    emit(state.copyWith(staging: true));
    _bridge.send(
      ClientMessage.gitStage(
        projectPath,
        files: state.files.map((f) => f.filePath).toList(),
        requestId: _newWireRequestId('git-stage'),
      ),
    );
  }

  /// Unstage all files.
  void unstageAll() {
    final projectPath = _projectPath;
    if (projectPath == null || state.files.isEmpty) return;
    _pendingSwitchToUnstaged = true;
    emit(state.copyWith(staging: true));
    _bridge.send(
      ClientMessage.gitUnstage(
        projectPath,
        files: state.files.map((f) => f.filePath).toList(),
        requestId: _newWireRequestId('git-unstage'),
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
        requestId: _newWireRequestId('git-revert-file'),
      ),
    );
  }

  void _onStageResult(GitStageResultMessage result) {
    if (!_acceptOperationResponse(result, 'git-stage')) return;
    if (result.success) {
      emit(state.copyWith(staging: false));
      if (_pendingSwitchToStaged) {
        _pendingSwitchToStaged = false;
        switchMode(GitViewMode.staged);
        _onStatusRefreshRequested?.call();
      } else {
        refreshDiffOnly(requestStatus: true);
      }
    } else {
      _pendingSwitchToStaged = false;
      emit(state.copyWith(staging: false, error: result.error));
    }
  }

  void _onRevertResult(GitRevertFileResultMessage result) {
    if (!_acceptOperationResponse(result, 'git-revert-file')) return;
    if (result.success) {
      emit(state.copyWith(staging: false));
      refreshDiffOnly(requestStatus: true);
    } else {
      emit(state.copyWith(staging: false, error: result.error));
    }
  }

  void _onRevertHunksResult(GitRevertHunksResultMessage result) {
    if (!_acceptOperationResponse(result, 'git-revert-hunks')) return;
    if (result.success) {
      emit(state.copyWith(staging: false));
      refreshDiffOnly(requestStatus: true);
    } else {
      emit(state.copyWith(staging: false, error: result.error));
    }
  }

  void _onUnstageResult(GitUnstageResultMessage result) {
    if (!_acceptOperationResponse(result, 'git-unstage')) return;
    if (result.success) {
      emit(state.copyWith(staging: false));
      if (_pendingSwitchToUnstaged) {
        _pendingSwitchToUnstaged = false;
        switchMode(GitViewMode.unstaged);
        _onStatusRefreshRequested?.call();
      } else {
        refreshDiffOnly(requestStatus: true);
      }
    } else {
      _pendingSwitchToUnstaged = false;
      emit(state.copyWith(staging: false, error: result.error));
    }
  }

  void _onUnstageHunksResult(GitUnstageHunksResultMessage result) {
    if (!_acceptOperationResponse(result, 'git-unstage-hunks')) return;
    if (result.success) {
      emit(state.copyWith(staging: false));
      refreshDiffOnly(requestStatus: true);
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
    _bridge.send(
      ClientMessage.gitFetch(
        projectPath,
        requestId: _newWireRequestId('git-fetch'),
      ),
    );
  }

  void _onFetchResult(GitFetchResultMessage result) {
    if (!_acceptOperationResponse(result, 'git-fetch')) return;
    emit(state.copyWith(fetching: false, error: result.error));
    if (!result.success) return;
    // After fetch, request remote status to get ahead/behind counts
    final projectPath = _projectPath;
    if (projectPath != null) {
      _bridge.send(
        ClientMessage.gitRemoteStatus(
          projectPath,
          requestId: _newWireRequestId('git-remote-status'),
        ),
      );
    }
  }

  void _onRemoteStatus(GitRemoteStatusResultMessage result) {
    if (!_acceptOperationResponse(result, 'git-remote-status')) return;
    if (result.error != null) {
      emit(state.copyWith(error: result.error));
      return;
    }
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
    _bridge.send(
      ClientMessage.gitPull(
        projectPath,
        requestId: _newWireRequestId('git-pull'),
      ),
    );
  }

  void _onPullResult(GitPullResultMessage result) {
    if (!_acceptOperationResponse(result, 'git-pull')) return;
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
    _bridge.send(
      ClientMessage.gitPush(
        projectPath,
        requestId: _newWireRequestId('git-push'),
      ),
    );
  }

  void _onPushResult(GitPushResultMessage result) {
    if (!_acceptOperationResponse(result, 'git-push')) return;
    emit(state.copyWith(pushing: false));
    if (result.success) {
      refresh();
    } else {
      emit(state.copyWith(error: result.error));
    }
  }

  void _onCommitResult(GitCommitResultMessage result) {
    if (!_acceptProjectResponse(result, 'git-commit') ||
        result.requestId == null) {
      return;
    }
    if (result.success) {
      refresh();
    }
  }

  // ---------------------------------------------------------------------------
  // Branch operations
  // ---------------------------------------------------------------------------

  void _onBranchesResult(GitBranchesResultMessage result) {
    if (!_acceptOperationResponse(result, 'git-branches')) return;
    if (result.error == null) {
      emit(state.copyWith(currentBranch: result.current));
    }
  }

  void _onCheckoutResult(GitCheckoutBranchResultMessage result) {
    if (!_acceptOperationResponse(result, 'git-checkout-branch')) return;
    if (result.success) {
      // Refresh diff + branch + remote status after checkout
      refresh();
      final projectPath = _projectPath;
      if (projectPath != null) {
        _bridge.send(
          ClientMessage.gitBranches(
            projectPath,
            requestId: _newWireRequestId('git-branches'),
          ),
        );
      }
      // Update session branch info so session list card reflects the change
      if (_sessionId != null) {
        _bridge.send(ClientMessage.refreshBranch(_sessionId));
      }
    }
  }

  @override
  Future<void> close() {
    for (final family in _responseFamilies) {
      _bridge.unregisterProjectResponseConsumer(family, _consumerId, all: true);
    }
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
