import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../models/messages.dart';

part 'session_link_state.freezed.dart';

@freezed
sealed class SessionLinkState with _$SessionLinkState {
  const factory SessionLinkState.resolving() = SessionLinkResolving;

  const factory SessionLinkState.resuming() = SessionLinkResuming;

  const factory SessionLinkState.openLive({
    required String bridgeSessionId,
    required String provider,
  }) = SessionLinkOpenLive;

  const factory SessionLinkState.openResumed({
    required SystemMessage session,
    String? gitBranch,
  }) = SessionLinkOpenResumed;

  const factory SessionLinkState.openReadOnly({
    required String provider,
    required RecentSession recentSession,
    required SessionOwnershipProjection ownership,
    ErrorMessage? failure,
  }) = SessionLinkOpenReadOnly;

  const factory SessionLinkState.unavailable({
    String? reason,
    String? recoveryAction,
    ErrorMessage? failure,
  }) = SessionLinkUnavailable;
}
