import 'package:flutter_bloc/flutter_bloc.dart';

import 'demo_state.dart';

/// A local walkthrough. Deliberately has no Bridge or persistence dependency.
class DemoCubit extends Cubit<DemoState> {
  DemoCubit() : super(const DemoState());

  void send(String prompt) {
    if (state.phase != DemoPhase.ready || prompt.trim().isEmpty) return;
    emit(state.copyWith(phase: DemoPhase.approval, prompt: prompt.trim()));
  }

  void approve() {
    if (state.phase == DemoPhase.approval) {
      emit(state.copyWith(phase: DemoPhase.completed));
    }
  }

  void reject() {
    if (state.phase == DemoPhase.approval) {
      emit(state.copyWith(phase: DemoPhase.rejected));
    }
  }

  void restart() => emit(DemoState(generation: state.generation + 1));
}
