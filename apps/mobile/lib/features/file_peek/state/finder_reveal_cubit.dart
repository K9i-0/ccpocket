import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../models/messages.dart';
import '../../../services/bridge_service.dart';
import '../finder_local_proof.dart';
import 'finder_reveal_state.dart';

class FinderRevealCubit extends Cubit<FinderRevealState> {
  final BridgeService bridge;
  final Duration timeout;
  StreamSubscription<ServerMessage>? _subscription;
  Completer<String?>? _response;
  Future<void>? _operation;

  FinderRevealCubit(this.bridge, {this.timeout = const Duration(seconds: 10)})
    : super(const FinderRevealState());

  Future<void> reveal(String projectPath, String filePath) {
    if (isClosed || state.busy) return Future.value();
    return _operation = _reveal(projectPath, filePath);
  }

  Future<void> _reveal(String projectPath, String filePath) async {
    emit(const FinderRevealState(busy: true));
    FinderLocalProof? proof;
    String? errorCode;
    try {
      if (!bridge.isConnected) {
        errorCode = 'reveal_failed';
      } else {
        proof = await FinderLocalProof.create();
        if (isClosed) return;
        final requestId = const Uuid().v4();
        final response = _response = Completer<String?>();
        _subscription = bridge.messages.listen((message) {
          if (response.isCompleted) return;
          if (message is FileRevealResultMessage &&
              message.requestId == requestId) {
            response.complete(message.errorCode);
          } else if (message is ErrorMessage &&
              message.errorCode == 'unsupported_message' &&
              message.message == 'reveal_file') {
            response.complete('bridge_update_required');
          }
        });
        bridge.send(
          ClientMessage.revealFile(
            projectPath: projectPath,
            filePath: filePath,
            requestId: requestId,
            proofPath: proof.path,
            proofToken: proof.token,
          ),
        );
        errorCode = await response.future.timeout(timeout);
      }
    } catch (_) {
      errorCode = 'reveal_failed';
    } finally {
      await _subscription?.cancel();
      _subscription = null;
      _response = null;
      try {
        await proof?.dispose();
      } catch (_) {
        errorCode ??= 'reveal_failed';
      }
    }
    if (!isClosed) emit(FinderRevealState(errorCode: errorCode));
  }

  @override
  Future<void> close() async {
    final response = _response;
    if (response != null && !response.isCompleted) {
      response.complete('cancelled');
    }
    await super.close();
    await _operation;
  }
}
