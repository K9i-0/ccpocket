import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../models/messages.dart';
import '../../../services/bridge_service.dart';
import 'github_list_cubit.dart';
import 'github_list_state.dart';

part 'github_item_cubit.freezed.dart';

@freezed
abstract class GitHubItemState with _$GitHubItemState {
  const factory GitHubItemState({
    /// The list row, shown while the detail loads.
    required GitHubItemSummary summary,
    @Default(true) bool loading,
    GitHubItemDetail? detail,
    GitHubFailure? failure,
  }) = _GitHubItemState;
}

/// Body and latest comments of one pull request or issue.
class GitHubItemCubit extends Cubit<GitHubItemState> {
  final BridgeService _bridge;
  final String projectPath;
  final GitHubItemKind kind;
  final Duration _timeout;
  late final StreamSubscription<ServerMessage> _sub;
  String? _requestId;
  Timer? _timer;

  GitHubItemCubit({
    required BridgeService bridge,
    required this.projectPath,
    required this.kind,
    required GitHubItemSummary summary,
    Duration timeout = GitHubListCubit.requestTimeout,
  }) : _bridge = bridge,
       _timeout = timeout,
       super(GitHubItemState(summary: summary)) {
    _sub = _bridge.messages.listen(_onMessage);
    load();
  }

  int get number => state.summary.number;

  void load() {
    _timer?.cancel();
    final requestId = _bridge.requestGitHubItem(
      projectPath: projectPath,
      kind: kind,
      number: number,
    );
    _requestId = requestId;
    _timer = Timer(
      _timeout,
      () => _fail(
        requestId,
        const GitHubFailure(kind: GitHubFailureKind.timeout),
      ),
    );
    emit(state.copyWith(loading: true, failure: null));
  }

  void _onMessage(ServerMessage message) {
    final requestId = _requestId;
    if (requestId == null) return;
    switch (message) {
      case GitHubItemResultMessage():
        if (message.requestId != requestId ||
            message.projectPath != projectPath ||
            message.kind != kind ||
            message.number != number) {
          return;
        }
        final error = message.error;
        final item = message.item;
        if (error != null || item == null) {
          _fail(
            requestId,
            error == null
                ? const GitHubFailure(kind: GitHubFailureKind.failed)
                : GitHubFailure.fromError(error),
          );
          return;
        }
        _settle();
        emit(
          state.copyWith(
            loading: false,
            detail: item,
            summary: item.summary,
            failure: null,
          ),
        );
      case ErrorMessage(
        errorCode: 'unsupported_message',
        message: 'github_item',
      ):
        _fail(
          requestId,
          const GitHubFailure(kind: GitHubFailureKind.unsupported),
        );
      case ErrorMessage(requestId: final id?, message: final text)
          when id == requestId:
        _fail(
          requestId,
          GitHubFailure(kind: GitHubFailureKind.failed, message: text),
        );
      default:
        break;
    }
  }

  void _settle() {
    _timer?.cancel();
    _timer = null;
    _requestId = null;
  }

  void _fail(String requestId, GitHubFailure failure) {
    if (_requestId != requestId) return;
    _settle();
    if (isClosed) return;
    emit(state.copyWith(loading: false, failure: failure));
  }

  @override
  Future<void> close() async {
    _settle();
    await _sub.cancel();
    return super.close();
  }
}
