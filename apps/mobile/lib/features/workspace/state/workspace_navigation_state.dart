import 'package:freezed_annotation/freezed_annotation.dart';

import 'workspace_destination.dart';

part 'workspace_navigation_state.freezed.dart';

enum WorkspaceCenterRoot { session, offline }

enum WorkspaceCenterOverlay { none, settings, globalGallery, setupGuide }

/// Logical navigation has no window dimensions. Entry identities survive
/// pending-session resolution and are independent of server session IDs.
@freezed
abstract class WorkspaceNavigationState with _$WorkspaceNavigationState {
  const factory WorkspaceNavigationState({
    WorkspaceSessionSelection? selection,
    String? liveSessionId,
    @Default(0) int sessionEntry,
    WorkspaceToolPaneData? tool,
    @Default(0) int toolEntry,
    @Default(WorkspaceCenterOverlay.none) WorkspaceCenterOverlay overlay,
    @Default(0) int overlayEntry,
    @Default(false) bool settingsFocusSupport,
    @Default(false) bool settingsFocusConnection,
    @Default(false) bool settingsFocusUsage,
    @Default(false) bool centerInFront,
  }) = _WorkspaceNavigationState;
}
