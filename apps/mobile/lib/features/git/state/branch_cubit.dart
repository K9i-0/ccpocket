import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/messages.dart';
import '../../../services/bridge_service.dart';
import 'branch_state.dart';

/// Manages branch listing, search, creation, and checkout.
class BranchCubit extends Cubit<BranchState> {
  static int _nextConsumerId = 0;
  static const _branchesResponseFamily = 'git-branches';
  static const _createResponseFamily = 'git-create-branch';
  static const _checkoutResponseFamily = 'git-checkout-branch';

  final BridgeService _bridge;
  final String _projectPath;
  final String _consumerId = 'branch-${++_nextConsumerId}';
  String? _branchesRequestId;
  String? _createRequestId;
  String? _checkoutRequestId;

  StreamSubscription<GitBranchesResultMessage>? _branchesSub;
  StreamSubscription<GitCreateBranchResultMessage>? _createSub;
  StreamSubscription<GitCheckoutBranchResultMessage>? _checkoutSub;

  BranchCubit({required BridgeService bridge, required String projectPath})
    : _bridge = bridge,
      _projectPath = projectPath,
      super(const BranchState()) {
    _branchesSub = _bridge.gitBranchesResults.listen(_onBranchesResult);
    _createSub = _bridge.gitCreateBranchResults.listen(_onCreateResult);
    _checkoutSub = _bridge.gitCheckoutBranchResults.listen(_onCheckoutResult);
  }

  // ---- Public API ----

  /// Load (or refresh) the branch list from the Bridge.
  void loadBranches() {
    emit(state.copyWith(loading: true, error: null));
    if (_branchesRequestId != null) {
      _bridge.unregisterProjectResponseConsumer(
        _branchesResponseFamily,
        _consumerId,
      );
    }
    final requestId = _bridge.createProjectRequestId('git-branches');
    _branchesRequestId = requestId;
    _bridge.registerProjectResponseConsumer(
      _branchesResponseFamily,
      _consumerId,
    );
    _bridge.send(
      ClientMessage.gitBranches(
        _projectPath,
        requestId: _bridge.projectRequestIdForWire(requestId),
      ),
    );
  }

  /// Filter branches locally by [query].
  void search(String query) {
    emit(state.copyWith(query: query));
  }

  /// Branches filtered by the current search query.
  List<String> get filteredBranches {
    if (state.query.isEmpty) return state.branches;
    final q = state.query.toLowerCase();
    return state.branches.where((b) => b.toLowerCase().contains(q)).toList();
  }

  /// Create a new branch and optionally check it out.
  void createBranch(String name, {bool checkout = true}) {
    emit(state.copyWith(creating: true, error: null));
    if (_createRequestId != null) {
      _bridge.unregisterProjectResponseConsumer(
        _createResponseFamily,
        _consumerId,
      );
    }
    final requestId = _bridge.createProjectRequestId('git-create-branch');
    _createRequestId = requestId;
    _bridge.registerProjectResponseConsumer(_createResponseFamily, _consumerId);
    _bridge.send(
      ClientMessage.gitCreateBranch(
        _projectPath,
        name,
        checkout: checkout,
        requestId: _bridge.projectRequestIdForWire(requestId),
      ),
    );
  }

  /// Checkout an existing branch.
  void checkout(String branch) {
    emit(state.copyWith(loading: true, error: null));
    if (_checkoutRequestId != null) {
      _bridge.unregisterProjectResponseConsumer(
        _checkoutResponseFamily,
        _consumerId,
      );
    }
    final requestId = _bridge.createProjectRequestId('git-checkout-branch');
    _checkoutRequestId = requestId;
    _bridge.registerProjectResponseConsumer(
      _checkoutResponseFamily,
      _consumerId,
    );
    _bridge.send(
      ClientMessage.gitCheckoutBranch(
        _projectPath,
        branch,
        requestId: _bridge.projectRequestIdForWire(requestId),
      ),
    );
  }

  // ---- Callbacks ----

  void _onBranchesResult(GitBranchesResultMessage result) {
    if (!_accept(result, _branchesRequestId, _branchesResponseFamily)) return;
    _bridge.unregisterProjectResponseConsumer(
      _branchesResponseFamily,
      _consumerId,
    );
    _branchesRequestId = null;
    if (result.error != null) {
      emit(state.copyWith(loading: false, error: result.error));
      return;
    }
    emit(
      state.copyWith(
        loading: false,
        current: result.current,
        branches: result.branches,
        checkedOutBranches: result.checkedOutBranches,
        remoteStatusByBranch: result.remoteStatusByBranch,
      ),
    );
  }

  void _onCreateResult(GitCreateBranchResultMessage result) {
    if (!_accept(result, _createRequestId, _createResponseFamily)) return;
    _bridge.unregisterProjectResponseConsumer(
      _createResponseFamily,
      _consumerId,
    );
    _createRequestId = null;
    if (!result.success) {
      emit(state.copyWith(creating: false, error: result.error));
      return;
    }
    emit(state.copyWith(creating: false));
    // Refresh branch list to include the new branch
    loadBranches();
  }

  void _onCheckoutResult(GitCheckoutBranchResultMessage result) {
    if (!_accept(result, _checkoutRequestId, _checkoutResponseFamily)) return;
    _bridge.unregisterProjectResponseConsumer(
      _checkoutResponseFamily,
      _consumerId,
    );
    _checkoutRequestId = null;
    if (!result.success) {
      emit(state.copyWith(loading: false, error: result.error));
      return;
    }
    // Refresh to update current branch
    loadBranches();
  }

  @override
  Future<void> close() {
    _bridge.unregisterProjectResponseConsumer(
      _branchesResponseFamily,
      _consumerId,
      all: true,
    );
    _bridge.unregisterProjectResponseConsumer(
      _createResponseFamily,
      _consumerId,
      all: true,
    );
    _bridge.unregisterProjectResponseConsumer(
      _checkoutResponseFamily,
      _consumerId,
      all: true,
    );
    _branchesSub?.cancel();
    _createSub?.cancel();
    _checkoutSub?.cancel();
    return super.close();
  }

  bool _accept(
    ProjectCorrelatedMessage result,
    String? pendingRequestId,
    String responseFamily,
  ) {
    if (result.projectPath != null && result.projectPath != _projectPath) {
      return false;
    }
    final requestId = result.requestId;
    if (requestId != null) return requestId == pendingRequestId;
    return pendingRequestId != null &&
        _bridge.canAcceptLegacyProjectResponse(responseFamily, _consumerId);
  }
}
