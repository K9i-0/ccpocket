import 'package:freezed_annotation/freezed_annotation.dart';

part 'finder_reveal_state.freezed.dart';

@freezed
abstract class FinderRevealState with _$FinderRevealState {
  const factory FinderRevealState({
    @Default(false) bool busy,
    String? errorCode,
  }) = _FinderRevealState;
}
