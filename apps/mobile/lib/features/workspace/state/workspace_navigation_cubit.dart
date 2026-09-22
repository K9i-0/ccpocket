import 'package:flutter_bloc/flutter_bloc.dart';

import 'workspace_destination.dart';
import 'workspace_navigation_state.dart';

/// Resolves user intentions once; pane Navigators project the same state in
/// compact and expanded layouts. Widgets own their transient editing state.
class WorkspaceNavigationCubit extends Cubit<WorkspaceNavigationState> {
  WorkspaceNavigationCubit() : super(const WorkspaceNavigationState());

  void selectSession(
    WorkspaceSessionSelection selection, {
    WorkspaceToolPaneData? restoredTool,
  }) {
    if (state.liveSessionId == selection.sessionId &&
        (state.selection?.provider?.value ?? 'claude') ==
            (selection.provider?.value ?? 'claude')) {
      revealSession();
      return;
    }
    emit(
      state.copyWith(
        selection: selection,
        liveSessionId: selection.sessionId,
        sessionEntry: state.sessionEntry + 1,
        tool: restoredTool,
        toolEntry: state.toolEntry + 1,
        overlay: WorkspaceCenterOverlay.none,
        centerInFront: true,
      ),
    );
  }

  void updateLiveSession(String originalId, String liveId) {
    if (state.selection?.sessionId != originalId) return;
    emit(state.copyWith(liveSessionId: liveId));
  }

  void revealSession() => emit(
    state.copyWith(overlay: WorkspaceCenterOverlay.none, centerInFront: true),
  );

  void activateCenter() {
    if (state.selection == null &&
        state.overlay == WorkspaceCenterOverlay.none) {
      return;
    }
    emit(state.copyWith(centerInFront: true));
  }

  void activateTool() {
    if (state.tool == null) return;
    emit(state.copyWith(centerInFront: false));
  }

  void openTool(WorkspaceToolPaneData tool) => emit(
    state.copyWith(
      tool: tool,
      toolEntry: state.toolEntry + 1,
      centerInFront: false,
    ),
  );

  void updateTool(WorkspaceToolPaneData tool) {
    if (state.tool?.id != tool.id) return;
    emit(state.copyWith(tool: tool));
  }

  void closeTool({int? entry}) {
    if (entry != null && entry != state.toolEntry) return;
    emit(state.copyWith(tool: null));
  }

  void openOverlay(
    WorkspaceCenterOverlay overlay, {
    bool focusSupport = false,
    bool focusConnection = false,
    bool focusUsage = false,
  }) => emit(
    state.copyWith(
      overlay: overlay,
      overlayEntry: state.overlayEntry + 1,
      settingsFocusSupport: focusSupport,
      settingsFocusConnection: focusConnection,
      settingsFocusUsage: focusUsage,
      centerInFront: true,
    ),
  );

  void closeOverlay({int? entry}) {
    if (entry != null && entry != state.overlayEntry) return;
    emit(state.copyWith(overlay: WorkspaceCenterOverlay.none));
  }

  void closeSession({int? entry}) {
    if (entry != null && entry != state.sessionEntry) return;
    reset();
  }

  void reset() => emit(
    WorkspaceNavigationState(
      // Never reuse a removed page's identity while its transition is finishing.
      sessionEntry: state.sessionEntry,
      toolEntry: state.toolEntry,
      overlayEntry: state.overlayEntry,
    ),
  );
}
