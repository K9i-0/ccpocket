import 'package:freezed_annotation/freezed_annotation.dart';

part 'demo_state.freezed.dart';

enum DemoPhase { ready, approval, completed, rejected }

@freezed
abstract class DemoState with _$DemoState {
  const factory DemoState({
    @Default(DemoPhase.ready) DemoPhase phase,
    @Default('') String prompt,
    @Default(0) int generation,
  }) = _DemoState;
}
