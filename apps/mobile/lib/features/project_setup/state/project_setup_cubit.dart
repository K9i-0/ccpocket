import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../models/messages.dart';
import '../../../services/bridge_service.dart';
part 'project_setup_cubit.freezed.dart';

@freezed
abstract class ProjectSetupState with _$ProjectSetupState {
  const factory ProjectSetupState({
    @Default(false) bool busy,
    String? error,
    ProjectSetupResultMessage? result,
  }) = _ProjectSetupState;
}

class ProjectSetupCubit extends Cubit<ProjectSetupState> {
  ProjectSetupCubit(this.bridge) : super(const ProjectSetupState());
  final BridgeService bridge;
  Future<ProjectSetupResultMessage?> request(
    Map<String, dynamic> payload, {
    required String updateHint,
  }) async {
    if (state.busy) return null;
    if (!bridge.isConnected) {
      emit(const ProjectSetupState(error: 'Bridge is disconnected'));
      return null;
    }
    emit(const ProjectSetupState(busy: true));
    final requestId = bridge.createProjectRequestId('project-setup');
    final response = Completer<ProjectSetupResultMessage>();
    final subscription = bridge.messages.listen((message) {
      if (message is ProjectSetupResultMessage &&
          message.requestId == requestId) {
        if (!response.isCompleted) response.complete(message);
      } else if (message is ErrorMessage &&
          (message.requestId == requestId ||
              (message.errorCode == 'unsupported_message' &&
                  message.message.contains(payload['type'] as String)))) {
        if (!response.isCompleted) {
          response.completeError(
            message.errorCode == 'unsupported_message'
                ? updateHint
                : message.message,
          );
        }
      }
    });
    try {
      bridge.send(ClientMessage.raw({...payload, 'requestId': requestId}));
      final result = await response.future.timeout(const Duration(seconds: 30));
      if (!isClosed) {
        emit(ProjectSetupState(result: result, error: result.error));
      }
      return result.error == null ? result : null;
    } catch (error) {
      if (!isClosed) {
        emit(
          ProjectSetupState(
            error: error is TimeoutException ? updateHint : error.toString(),
          ),
        );
      }
      return null;
    } finally {
      await subscription.cancel();
    }
  }
}
