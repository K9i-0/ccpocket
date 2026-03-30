import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/messages.dart';
import '../../../services/bridge_service.dart';
import 'branch_state.dart';

/// Manages branch listing, search, creation, and checkout.
class BranchCubit extends Cubit<BranchState> {
  final BridgeService _bridge;
  final String _projectPath;

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
    _bridge.send(ClientMessage.gitBranches(_projectPath));
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
    _bridge.send(
      ClientMessage.gitCreateBranch(_projectPath, name, checkout: checkout),
    );
  }

  /// Checkout an existing branch.
  void checkout(String branch) {
    emit(state.copyWith(loading: true, error: null));
    _bridge.send(ClientMessage.gitCheckoutBranch(_projectPath, branch));
  }

  // ---- Callbacks ----

  void _onBranchesResult(GitBranchesResultMessage result) {
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
    if (!result.success) {
      emit(state.copyWith(creating: false, error: result.error));
      return;
    }
    emit(state.copyWith(creating: false));
    // Refresh branch list to include the new branch
    loadBranches();
  }

  void _onCheckoutResult(GitCheckoutBranchResultMessage result) {
    if (!result.success) {
      emit(state.copyWith(loading: false, error: result.error));
      return;
    }
    // Refresh to update current branch
    loadBranches();
  }

  @override
  Future<void> close() {
    _branchesSub?.cancel();
    _createSub?.cancel();
    _checkoutSub?.cancel();
    return super.close();
  }
}
