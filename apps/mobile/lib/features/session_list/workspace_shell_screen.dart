import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/claude_session/claude_session_screen.dart';
import '../../features/codex_session/codex_session_screen.dart';
import '../../features/explore/explore_screen.dart';
import '../../features/explore/state/explore_state.dart';
import '../../features/gallery/gallery_screen.dart';
import '../../features/git/git_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/setup_guide/setup_guide_screen.dart';
import '../../l10n/app_localizations.dart';
import '../../models/messages.dart';
import '../../providers/bridge_cubits.dart';
import '../../router/app_router.dart';
import '../../router/session_stack_navigation.dart';
import '../../services/bridge_service.dart';
import '../../services/connection_url_parser.dart';
import '../../services/notification_service.dart';
import '../../utils/diff_parser.dart';
import 'session_list_screen.dart';
import '../workspace/state/workspace_navigation_cubit.dart';
import '../workspace/state/workspace_navigation_state.dart';
import '../workspace/state/workspace_destination.dart';
import '../workspace/widgets/workspace_pane_navigator.dart';

export '../workspace/state/workspace_destination.dart'
    show WorkspaceSessionSelection;

const workspaceMultiPaneBreakpoint = 862.0;
const _twoPaneDividerWidth = 1.0;
const _paneResizeHandleWidth = _twoPaneDividerWidth;
const _paneResizePointerHandleWidth = 12.0;
const _paneResizeTouchHandleWidth = 44.0;
const _minCenterPaneWidth = 360.0;
const _minRightPaneWidth = 240.0;

enum _WorkspaceLayoutMode { single, multiPane }

double _leftPaneWidth(double width) {
  if (width < 1024) return 260;
  return width >= 1280 ? 360 : 320;
}

double _rightPaneWidth(double width) {
  if (width < 820) return 240;
  if (width < 890) return 260;
  if (width < 1024) return 280;
  return width >= 1360 ? 380 : 320;
}

double _maxRightPaneWidth({required double totalWidth}) {
  final leftWidth = _leftPaneWidth(totalWidth);
  const dividerCount = 2;
  final reservedWidth =
      leftWidth + (dividerCount * _paneResizeHandleWidth) + _minCenterPaneWidth;
  final availableWidth = totalWidth - reservedWidth;
  return availableWidth.clamp(0.0, double.infinity);
}

double _minAllowedRightPaneWidth(double maxWidth) {
  if (maxWidth <= 0) return 0;
  return maxWidth < _minRightPaneWidth ? maxWidth : _minRightPaneWidth;
}

double _resizeHandleHitWidth(TargetPlatform platform) {
  if (platform == TargetPlatform.macOS ||
      platform == TargetPlatform.windows ||
      platform == TargetPlatform.linux) {
    return _paneResizePointerHandleWidth;
  }
  return _paneResizeTouchHandleWidth;
}

_WorkspaceLayoutMode _layoutModeForWidth(double width) {
  return width >= workspaceMultiPaneBreakpoint
      ? _WorkspaceLayoutMode.multiPane
      : _WorkspaceLayoutMode.single;
}

sealed class _WorkspaceToolPaneSnapshot {
  const _WorkspaceToolPaneSnapshot();

  WorkspaceToolPaneData restore();
}

class _GitToolPaneSnapshot extends _WorkspaceToolPaneSnapshot {
  final String projectPath;
  final String? sessionId;
  final String? worktreePath;

  const _GitToolPaneSnapshot({
    required this.projectPath,
    this.sessionId,
    this.worktreePath,
  });

  @override
  WorkspaceToolPaneData restore() => GitToolPaneData(
    projectPath: projectPath,
    sessionId: sessionId,
    worktreePath: worktreePath,
  );
}

class _ExploreToolPaneSnapshot extends _WorkspaceToolPaneSnapshot {
  final String sessionId;
  final String projectPath;
  final String initialPath;
  final List<String> recentPeekedFiles;

  const _ExploreToolPaneSnapshot({
    required this.sessionId,
    required this.projectPath,
    required this.initialPath,
    required this.recentPeekedFiles,
  });

  @override
  WorkspaceToolPaneData restore() => ExploreToolPaneData(
    sessionId: sessionId,
    projectPath: projectPath,
    initialFiles: const [],
    initialPath: initialPath,
    recentPeekedFiles: recentPeekedFiles,
  );
}

class _GalleryToolPaneSnapshot extends _WorkspaceToolPaneSnapshot {
  final String sessionId;

  const _GalleryToolPaneSnapshot({required this.sessionId});

  @override
  WorkspaceToolPaneData restore() => GalleryToolPaneData(sessionId: sessionId);
}

class _WorkspaceToolPaneBindings {
  final ValueNotifier<DiffSelection?>? diffSelectionNotifier;
  final ValueChanged<ExploreScreenResult>? onExploreResultChanged;
  final ValueChanged<String>? onFilePeekOpened;

  const _WorkspaceToolPaneBindings({
    this.diffSelectionNotifier,
    this.onExploreResultChanged,
    this.onFilePeekOpened,
  });
}

class WorkspaceShellScreen extends StatefulWidget {
  final ValueNotifier<ConnectionParams?>? deepLinkNotifier;
  final List<RecentSession>? debugRecentSessions;
  final WorkspaceSessionSelection? initialSession;

  const WorkspaceShellScreen({
    super.key,
    this.deepLinkNotifier,
    this.debugRecentSessions,
    this.initialSession,
  });

  static WorkspaceShellScreenState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<WorkspaceShellScreenState>();

  @override
  State<WorkspaceShellScreen> createState() => WorkspaceShellScreenState();
}

class WorkspaceShellScreenState extends State<WorkspaceShellScreen> {
  final WorkspaceNavigationCubit _navigation = WorkspaceNavigationCubit();
  final Map<String, _WorkspaceToolPaneSnapshot> _toolPaneSnapshots = {};
  final Map<String, _WorkspaceToolPaneBindings> _toolPaneBindings = {};
  Object? _homeRouteIdentity;
  bool _rootVisible = true;
  final _centerNavigatorKey = GlobalKey<NavigatorState>();
  final _toolNavigatorKey = GlobalKey<NavigatorState>();
  _WorkspaceLayoutMode _layoutMode = _WorkspaceLayoutMode.single;
  StreamSubscription<String>? _stoppedSessionSub;
  StreamSubscription<WorkspaceNavigationState>? _navigationSub;
  double? _rightPaneUserWidth;
  final ValueNotifier<int> _presentationVersion = ValueNotifier<int>(0);

  WorkspaceNavigationState get _state => _navigation.state;
  WorkspaceToolPaneData? get _toolPane => _state.tool;
  WorkspaceSessionSelection? get _selectedSession => _state.selection;
  WorkspaceCenterOverlay get _centerOverlay => _state.overlay;
  bool get canOpenToolPane => true;
  bool get isSinglePane => _layoutMode == _WorkspaceLayoutMode.single;
  bool get isLeftPaneVisible =>
      !isSinglePane ||
      (_selectedSession == null &&
          _centerOverlay == WorkspaceCenterOverlay.none &&
          _toolPane == null);
  WorkspaceSessionSelection? get selectedSession => _selectedSession;
  String? get liveSessionId => _state.liveSessionId;
  ValueNotifier<int> get presentationListenable => _presentationVersion;

  void _notifyPresentationChanged() {
    _presentationVersion.value++;
    final routeIdentity = _homeRouteIdentity;
    if (routeIdentity != null) {
      if (_state.liveSessionId case final id?) {
        SessionRouteRegistry.instance.update(
          routeIdentity: routeIdentity,
          owner: this,
          sessionId: id,
          provider: _selectedSession?.provider == Provider.codex
              ? 'codex'
              : 'claude',
        );
      } else {
        SessionRouteRegistry.instance.remove(
          routeIdentity: routeIdentity,
          owner: this,
        );
      }
    }
    final visible =
        _rootVisible &&
        _selectedSession != null &&
        _centerOverlay == WorkspaceCenterOverlay.none &&
        (!isSinglePane || _toolPane == null || _state.centerInFront);
    if (visible) {
      NotificationService.instance.setActiveSession(
        owner: this,
        sessionId: _state.liveSessionId!,
        provider: _selectedSession?.provider == Provider.codex
            ? 'codex'
            : 'claude',
      );
    } else {
      NotificationService.instance.clearActiveSession(owner: this);
    }
  }

  bool isToolPaneOpen(String paneId) => _toolPane?.id == paneId;

  @override
  void initState() {
    super.initState();
    if (widget.initialSession case final initial?) {
      _navigation.selectSession(initial);
    }
    _stoppedSessionSub = context.read<BridgeService>().stoppedSessions.listen(
      _clearSelectedSessionIfStopped,
    );
    _navigationSub = _navigation.stream.listen((_) {
      if (!mounted) return;
      setState(() {});
      _notifyPresentationChanged();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    final visible = route?.isCurrent ?? true;
    if (visible != _rootVisible) {
      _rootVisible = visible;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _notifyPresentationChanged();
      });
    }
    final identity = route?.settings;
    if (identical(identity, _homeRouteIdentity)) return;
    if (_homeRouteIdentity case final old?) {
      SessionRouteRegistry.instance.unregisterWorkspace(old, this);
    }
    _homeRouteIdentity = identity;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notifyPresentationChanged();
    });
    if (identity != null) {
      SessionRouteRegistry.instance.registerWorkspace(
        routeIdentity: identity,
        owner: this,
        reveal: _navigation.revealSession,
        open: selectSession,
      );
    }
  }

  void updateLiveSession(String originalId, String liveId) {
    _navigation.updateLiveSession(originalId, liveId);
  }

  void registerSessionToolPaneBindings({
    required String sessionId,
    ValueNotifier<DiffSelection?>? diffSelectionNotifier,
    ValueChanged<ExploreScreenResult>? onExploreResultChanged,
    ValueChanged<String>? onFilePeekOpened,
  }) {
    _toolPaneBindings[sessionId] = _WorkspaceToolPaneBindings(
      diffSelectionNotifier: diffSelectionNotifier,
      onExploreResultChanged: onExploreResultChanged,
      onFilePeekOpened: onFilePeekOpened,
    );
  }

  void unregisterSessionToolPaneBindings(String sessionId) {
    _toolPaneBindings.remove(sessionId);
  }

  void openGitPane({
    required String projectPath,
    String? sessionId,
    String? worktreePath,
    ValueNotifier<DiffSelection?>? diffSelectionNotifier,
    ValueChanged<String>? onFilePeekOpened,
  }) {
    if (sessionId != null &&
        (diffSelectionNotifier != null || onFilePeekOpened != null)) {
      final current = _toolPaneBindings[sessionId];
      _toolPaneBindings[sessionId] = _WorkspaceToolPaneBindings(
        diffSelectionNotifier:
            diffSelectionNotifier ?? current?.diffSelectionNotifier,
        onExploreResultChanged: current?.onExploreResultChanged,
        onFilePeekOpened: onFilePeekOpened ?? current?.onFilePeekOpened,
      );
    }
    _openToolPane(
      GitToolPaneData(
        projectPath: projectPath,
        sessionId: sessionId,
        worktreePath: worktreePath,
      ),
    );
  }

  void openExplorePane({
    required String sessionId,
    required String projectPath,
    List<String> initialFiles = const [],
    String initialPath = '',
    List<String> recentPeekedFiles = const [],
    ValueChanged<ExploreScreenResult>? onResultChanged,
  }) {
    if (onResultChanged != null) {
      final current = _toolPaneBindings[sessionId];
      _toolPaneBindings[sessionId] = _WorkspaceToolPaneBindings(
        diffSelectionNotifier: current?.diffSelectionNotifier,
        onExploreResultChanged: onResultChanged,
        onFilePeekOpened: current?.onFilePeekOpened,
      );
    }
    _openToolPane(
      ExploreToolPaneData(
        sessionId: sessionId,
        projectPath: projectPath,
        initialFiles: initialFiles,
        initialPath: initialPath,
        recentPeekedFiles: recentPeekedFiles,
      ),
    );
  }

  void openSessionGalleryPane({required String sessionId}) {
    _openToolPane(GalleryToolPaneData(sessionId: sessionId));
  }

  void openSettingsCenter({
    bool focusSupport = false,
    bool focusConnection = false,
    bool focusUsage = false,
  }) {
    if (_centerOverlay == WorkspaceCenterOverlay.settings &&
        !focusSupport &&
        !focusConnection &&
        !focusUsage) {
      popCenterOverlay();
      return;
    }
    _navigation.openOverlay(
      WorkspaceCenterOverlay.settings,
      focusSupport: focusSupport,
      focusConnection: focusConnection,
      focusUsage: focusUsage,
    );
  }

  void openGlobalGalleryCenter() {
    if (_centerOverlay == WorkspaceCenterOverlay.globalGallery) {
      popCenterOverlay();
    } else {
      _navigation.openOverlay(WorkspaceCenterOverlay.globalGallery);
    }
  }

  void openSetupGuideCenter() {
    if (_centerOverlay == WorkspaceCenterOverlay.setupGuide) {
      popCenterOverlay();
    } else {
      _navigation.openOverlay(WorkspaceCenterOverlay.setupGuide);
    }
  }

  void popCenterOverlay({int? entry}) => _navigation.closeOverlay(entry: entry);

  _WorkspaceToolPaneSnapshot? _snapshotForPane(
    WorkspaceToolPaneData pane, {
    String? fallbackSessionId,
  }) {
    return switch (pane) {
      GitToolPaneData(:final projectPath, :final sessionId, :final worktreePath)
          when sessionId != null || fallbackSessionId != null =>
        _GitToolPaneSnapshot(
          projectPath: projectPath,
          sessionId: sessionId ?? fallbackSessionId,
          worktreePath: worktreePath,
        ),
      GitToolPaneData() => null,
      ExploreToolPaneData(
        :final sessionId,
        :final projectPath,
        :final initialPath,
        :final recentPeekedFiles,
      ) =>
        _ExploreToolPaneSnapshot(
          sessionId: sessionId,
          projectPath: projectPath,
          initialPath: initialPath,
          recentPeekedFiles: List.unmodifiable(recentPeekedFiles),
        ),
      GalleryToolPaneData(:final sessionId) => _GalleryToolPaneSnapshot(
        sessionId: sessionId,
      ),
    };
  }

  void _rememberToolPaneForSession(String? sessionId) {
    final pane = _toolPane;
    if (pane == null || sessionId == null) return;
    final snapshot = _snapshotForPane(pane, fallbackSessionId: sessionId);
    if (snapshot == null) return;
    _toolPaneSnapshots[sessionId] = snapshot;
  }

  void _rememberVisibleToolPane() {
    _rememberToolPaneForSession(_state.liveSessionId ?? _toolPane?.sessionId);
  }

  void _forgetToolPaneForSession(String? sessionId) {
    if (sessionId == null) return;
    _toolPaneSnapshots.remove(sessionId);
  }

  WorkspaceToolPaneData? _restoreToolPaneForSession(String sessionId) {
    return _toolPaneSnapshots[sessionId]?.restore();
  }

  void _openToolPane(WorkspaceToolPaneData pane) {
    if (_toolPane?.id == pane.id) {
      closeToolPane();
      return;
    }
    _navigation.openTool(pane);
    _rememberVisibleToolPane();
  }

  void resizeRightPane(double nextWidth, double totalWidth) {
    if (_toolPane == null) return;
    final maxWidth = _maxRightPaneWidth(totalWidth: totalWidth);
    final minWidth = _minAllowedRightPaneWidth(maxWidth);
    setState(() {
      _rightPaneUserWidth = nextWidth.clamp(minWidth, maxWidth).toDouble();
    });
  }

  void closeToolPane({int? entry}) {
    if (entry != null && entry != _state.toolEntry) return;
    _forgetToolPaneForSession(_state.liveSessionId ?? _toolPane?.sessionId);
    _navigation.closeTool();
  }

  void resetWorkspace() {
    _toolPaneSnapshots.clear();
    _toolPaneBindings.clear();
    _navigation.reset();
  }

  void _handleExploreResult(ExploreScreenResult result, {int? entry}) {
    if (entry != null && entry != _state.toolEntry) return;
    final pane = _toolPane;
    if (pane is! ExploreToolPaneData) return;
    _navigation.updateTool(
      ExploreToolPaneData(
        sessionId: pane.sessionId,
        projectPath: pane.projectPath,
        initialFiles: pane.initialFiles,
        initialPath: result.currentPath,
        recentPeekedFiles: result.recentPeekedFiles,
      ),
    );
    _rememberToolPaneForSession(pane.sessionId);
    _toolPaneBindings[pane.sessionId]?.onExploreResultChanged?.call(result);
  }

  void _handleDiffSelection(DiffSelection selection, {int? entry}) {
    if (entry != null && entry != _state.toolEntry) return;
    final pane = _toolPane;
    if (pane is! GitToolPaneData) return;
    final sessionId = _state.liveSessionId ?? pane.sessionId;
    _toolPaneBindings[sessionId]?.diffSelectionNotifier?.value =
        selection.isEmpty ? null : selection;
    closeToolPane();
  }

  void _handleFilePeekOpened(String filePath, {int? entry}) {
    if (entry != null && entry != _state.toolEntry) return;
    final pane = _toolPane;
    if (pane is! GitToolPaneData) return;
    final sessionId = _state.liveSessionId ?? pane.sessionId;
    if (sessionId == null) return;
    _toolPaneBindings[sessionId]?.onFilePeekOpened?.call(filePath);
  }

  void selectSession(WorkspaceSessionSelection selection) {
    _rememberVisibleToolPane();
    _navigation.selectSession(
      selection,
      restoredTool: _restoreToolPaneForSession(selection.sessionId),
    );
  }

  void clearSelectedSession({int? entry}) {
    if (entry != null && entry != _state.sessionEntry) return;
    _toolPaneSnapshots.clear();
    _toolPaneBindings.clear();
    _navigation.closeSession();
  }

  void _clearSelectedSessionIfStopped(String sessionId) {
    if (_state.liveSessionId != sessionId) return;
    clearSelectedSession();
  }

  void _syncLayoutState(_WorkspaceLayoutMode nextMode) {
    if (nextMode == _layoutMode) return;
    _layoutMode = nextMode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notifyPresentationChanged();
    });
  }

  @override
  void dispose() {
    NotificationService.instance.clearActiveSession(owner: this);
    _stoppedSessionSub?.cancel();
    _navigationSub?.cancel();
    _navigation.close();
    if (_homeRouteIdentity case final identity?) {
      SessionRouteRegistry.instance.unregisterWorkspace(identity, this);
    }
    _presentationVersion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ConnectionCubit, BridgeConnectionState>(
      listener: (context, state) {
        if (state == BridgeConnectionState.disconnected) {
          resetWorkspace();
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final connectionState = context.watch<ConnectionCubit>().state;
          final padding = MediaQuery.paddingOf(context);
          final usableWidth = (constraints.maxWidth - padding.horizontal).clamp(
            0.0,
            double.infinity,
          );
          final layoutMode = _layoutModeForWidth(usableWidth);
          _syncLayoutState(layoutMode);
          final compact = isSinglePane;
          final sessionEntry = _state.sessionEntry;
          final toolEntry = _state.toolEntry;
          final overlayEntry = _state.overlayEntry;
          final hasCenter =
              _selectedSession != null ||
              _centerOverlay != WorkspaceCenterOverlay.none;
          final showRightPane = _toolPane != null;
          final centerActive =
              !compact ||
              (hasCenter && (!showRightPane || _state.centerInFront));
          final toolActive =
              showRightPane &&
              (!compact || !hasCenter || !_state.centerInFront);
          final leftWidth = compact
              ? constraints.maxWidth
              : padding.left + _leftPaneWidth(usableWidth);
          final maxRightWidth = _maxRightPaneWidth(totalWidth: usableWidth);
          final rightWidth = compact
              ? constraints.maxWidth
              : padding.right +
                    (_rightPaneUserWidth ?? _rightPaneWidth(usableWidth))
                        .clamp(
                          _minAllowedRightPaneWidth(maxRightWidth),
                          maxRightWidth,
                        )
                        .toDouble();
          final centerLeft = compact ? 0.0 : leftWidth + _twoPaneDividerWidth;
          final centerRight = !compact && showRightPane
              ? rightWidth + _twoPaneDividerWidth
              : 0.0;
          final center = Positioned(
            key: const ValueKey('workspace_center_slot'),
            top: 0,
            bottom: 0,
            left: centerLeft,
            right: centerRight,
            child: MediaQuery.removePadding(
              context: context,
              removeLeft: !compact,
              removeRight: !compact && showRightPane,
              child: WorkspacePaneNavigator(
                navigatorKey: _centerNavigatorKey,
                onInteraction: compact ? null : _navigation.activateCenter,
                compact: compact,
                active: centerActive,
                handlesBack: !showRightPane || _state.centerInFront,
                background: compact
                    ? const SizedBox.expand()
                    : _WorkspaceContentHost(
                        selection: null,
                        root: WorkspaceCenterRoot.offline,
                        overlay: WorkspaceCenterOverlay.none,
                        connectionState: connectionState,
                        settingsFocusSupport: false,
                        settingsFocusConnection: false,
                        settingsFocusUsage: false,
                        settingsPresentationVersion: 0,
                      ),
                pages: [
                  if (_selectedSession != null)
                    WorkspacePanePage(
                      key: ValueKey(('session', _state.sessionEntry)),
                      compact: compact,
                      child: _WorkspaceContentHost(
                        sessionEntry: sessionEntry,
                        selection: _selectedSession,
                        root: WorkspaceCenterRoot.session,
                        overlay: WorkspaceCenterOverlay.none,
                        connectionState: connectionState,
                        settingsFocusSupport: false,
                        settingsFocusConnection: false,
                        settingsFocusUsage: false,
                        settingsPresentationVersion: 0,
                      ),
                    ),
                  if (_centerOverlay != WorkspaceCenterOverlay.none)
                    WorkspacePanePage(
                      key: ValueKey(('overlay', _state.overlayEntry)),
                      compact: compact,
                      child: _WorkspaceContentHost(
                        selection: null,
                        root: WorkspaceCenterRoot.offline,
                        overlayEntry: overlayEntry,
                        overlay: _centerOverlay,
                        connectionState: connectionState,
                        settingsFocusSupport: _state.settingsFocusSupport,
                        settingsFocusConnection: _state.settingsFocusConnection,
                        settingsFocusUsage: _state.settingsFocusUsage,
                        settingsPresentationVersion: _state.overlayEntry,
                      ),
                    ),
                ],
                onDidRemovePage: (page) {
                  if (_selectedSession != null &&
                      page.key == ValueKey(('session', _state.sessionEntry))) {
                    clearSelectedSession();
                  } else if (_centerOverlay != WorkspaceCenterOverlay.none &&
                      page.key == ValueKey(('overlay', _state.overlayEntry))) {
                    popCenterOverlay();
                  }
                },
              ),
            ),
          );
          final tool = Positioned(
            key: const ValueKey('workspace_tool_slot'),
            top: 0,
            bottom: 0,
            right: 0,
            width: rightWidth,
            child: MediaQuery.removePadding(
              context: context,
              removeLeft: !compact,
              child: WorkspacePaneNavigator(
                navigatorKey: _toolNavigatorKey,
                onInteraction: compact ? null : _navigation.activateTool,
                compact: compact,
                active: toolActive,
                handlesBack: !hasCenter || !_state.centerInFront,
                visible: !compact || !centerActive || _toolPane == null,
                pages: [
                  if (_toolPane case final pane?)
                    WorkspacePanePage(
                      key: ValueKey(('tool', _state.toolEntry)),
                      compact: compact,
                      child: _WorkspaceToolPaneHost(
                        pane: pane,
                        onClose: () => closeToolPane(entry: toolEntry),
                        onExploreResultChanged: (result) =>
                            _handleExploreResult(result, entry: toolEntry),
                        onDiffSelection: (selection) =>
                            _handleDiffSelection(selection, entry: toolEntry),
                        onFilePeekOpened: (path) =>
                            _handleFilePeekOpened(path, entry: toolEntry),
                      ),
                    ),
                ],
                onDidRemovePage: (page) {
                  if (_toolPane != null &&
                      page.key == ValueKey(('tool', _state.toolEntry))) {
                    closeToolPane();
                  }
                },
              ),
            ),
          );
          final resizeHandleHitWidth = _resizeHandleHitWidth(
            Theme.of(context).platform,
          );
          return Stack(
            children: [
              Positioned(
                key: const ValueKey('workspace_list_slot'),
                top: 0,
                bottom: 0,
                left: 0,
                width: leftWidth,
                child: IgnorePointer(
                  ignoring: compact && (hasCenter || showRightPane),
                  child: ExcludeFocus(
                    excluding: compact && (hasCenter || showRightPane),
                    child: ExcludeSemantics(
                      excluding: compact && (hasCenter || showRightPane),
                      child: ColoredBox(
                        color: Theme.of(context).colorScheme.surface,
                        child: MediaQuery.removePadding(
                          context: context,
                          removeRight: !compact,
                          child: SessionListScreen(
                            deepLinkNotifier: widget.deepLinkNotifier,
                            debugRecentSessions: widget.debugRecentSessions,
                            embedded: !compact,
                            onSelectWorkspaceSession: selectSession,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (!compact)
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: leftWidth,
                  child: _WorkspacePaneDivider(
                    color: Theme.of(context).dividerColor
                        .withValues(alpha: 0.18),
                  ),
                ),
              if (_state.centerInFront) tool,
              center,
              if (!_state.centerInFront) tool,
              if (!compact && showRightPane)
                Positioned(
                  top: 0,
                  bottom: 0,
                  right:
                      rightWidth -
                      ((resizeHandleHitWidth - _twoPaneDividerWidth) / 2),
                  width: resizeHandleHitWidth,
                  child: _WorkspaceResizeHandle(
                    color: Theme.of(context).dividerColor
                        .withValues(alpha: 0.18),
                    onDragUpdate: (delta) => resizeRightPane(
                      rightWidth - padding.right - delta,
                      usableWidth,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

@RoutePage()
class AdaptiveHomeScreen extends StatefulWidget {
  final ValueNotifier<ConnectionParams?>? deepLinkNotifier;
  final List<RecentSession>? debugRecentSessions;
  final WorkspaceSessionSelection? initialSession;

  const AdaptiveHomeScreen({
    super.key,
    this.deepLinkNotifier,
    this.debugRecentSessions,
    this.initialSession,
  });

  @override
  State<AdaptiveHomeScreen> createState() => _AdaptiveHomeScreenState();
}

class _AdaptiveHomeScreenState extends State<AdaptiveHomeScreen> {
  @override
  Widget build(BuildContext context) {
    return WorkspaceShellScreen(
      deepLinkNotifier: widget.deepLinkNotifier,
      debugRecentSessions: widget.debugRecentSessions,
      initialSession: widget.initialSession,
    );
  }
}

class _WorkspacePaneDivider extends StatelessWidget {
  final Color color;

  const _WorkspacePaneDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(width: _twoPaneDividerWidth, color: color);
  }
}

class _WorkspaceResizeHandle extends StatefulWidget {
  final Color color;
  final ValueChanged<double> onDragUpdate;

  const _WorkspaceResizeHandle({
    required this.color,
    required this.onDragUpdate,
  });

  @override
  State<_WorkspaceResizeHandle> createState() => _WorkspaceResizeHandleState();
}

class _WorkspaceResizeHandleState extends State<_WorkspaceResizeHandle> {
  bool _dragging = false;

  void _setDragging(bool dragging) {
    if (_dragging == dragging) return;
    setState(() => _dragging = dragging);
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = Theme.of(context).colorScheme.primary
        .withValues(alpha: 0.55);

    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: Semantics(
        label: 'Resize right pane',
        hint: 'Drag horizontally to resize',
        enabled: true,
        onIncrease: () => widget.onDragUpdate(-48),
        onDecrease: () => widget.onDragUpdate(48),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: (_) => _setDragging(true),
          onHorizontalDragUpdate: (details) =>
              widget.onDragUpdate(details.delta.dx),
          onHorizontalDragEnd: (_) => _setDragging(false),
          onHorizontalDragCancel: () => _setDragging(false),
          child: Center(
            child: Container(
              width: _twoPaneDividerWidth,
              color: _dragging ? activeColor : widget.color,
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkspaceToolPaneHost extends StatelessWidget {
  final WorkspaceToolPaneData pane;
  final VoidCallback onClose;
  final ValueChanged<ExploreScreenResult> onExploreResultChanged;
  final ValueChanged<DiffSelection> onDiffSelection;
  final ValueChanged<String> onFilePeekOpened;

  const _WorkspaceToolPaneHost({
    required this.pane,
    required this.onClose,
    required this.onExploreResultChanged,
    required this.onDiffSelection,
    required this.onFilePeekOpened,
  });

  @override
  Widget build(BuildContext context) {
    final child = switch (pane) {
      GitToolPaneData(
        :final projectPath,
        :final sessionId,
        :final worktreePath,
      ) =>
        GitScreen(
          projectPath: projectPath,
          sessionId: sessionId,
          worktreePath: worktreePath,
          embedded: true,
          onClose: onClose,
          onRequestChange: onDiffSelection,
          onFilePeekOpened: onFilePeekOpened,
        ),
      ExploreToolPaneData(
        :final sessionId,
        :final projectPath,
        :final initialFiles,
        :final initialPath,
        :final recentPeekedFiles,
      ) =>
        ExploreScreen(
          sessionId: sessionId,
          projectPath: projectPath,
          initialFiles: initialFiles,
          initialPath: initialPath,
          recentPeekedFiles: recentPeekedFiles,
          embedded: true,
          onClose: onClose,
          onResultChanged: onExploreResultChanged,
        ),
      GalleryToolPaneData(:final sessionId) => GalleryScreen(
        sessionId: sessionId,
        embedded: true,
        onClose: onClose,
      ),
    };

    return Material(color: Theme.of(context).colorScheme.surface, child: child);
  }
}

class _WorkspaceContentHost extends StatelessWidget {
  final WorkspaceSessionSelection? selection;
  final WorkspaceCenterRoot root;
  final WorkspaceCenterOverlay overlay;
  final BridgeConnectionState connectionState;
  final bool settingsFocusSupport;
  final bool settingsFocusConnection;
  final bool settingsFocusUsage;
  final int settingsPresentationVersion;
  final int? sessionEntry;
  final int? overlayEntry;

  const _WorkspaceContentHost({
    required this.selection,
    required this.root,
    required this.overlay,
    required this.connectionState,
    required this.settingsFocusSupport,
    required this.settingsFocusConnection,
    required this.settingsFocusUsage,
    required this.settingsPresentationVersion,
    this.sessionEntry,
    this.overlayEntry,
  });

  @override
  Widget build(BuildContext context) {
    final selection = this.selection;
    final shell = WorkspaceShellScreen.maybeOf(context);
    final bridge = context.read<BridgeService>();
    final hasSessions =
        bridge.sessions.isNotEmpty || bridge.recentSessions.isNotEmpty;

    switch (overlay) {
      case WorkspaceCenterOverlay.settings:
        return SettingsScreen(
          key: ValueKey(
            'workspace_settings_$settingsPresentationVersion'
            '_$settingsFocusSupport'
            '_$settingsFocusConnection'
            '_$settingsFocusUsage',
          ),
          focusSupport: settingsFocusSupport,
          focusConnection: settingsFocusConnection,
          focusUsage: settingsFocusUsage,
          embedded: true,
          onBack: () => shell?.popCenterOverlay(entry: overlayEntry),
        );
      case WorkspaceCenterOverlay.globalGallery:
        return GalleryScreen(embedded: true, onBack: shell?.popCenterOverlay);
      case WorkspaceCenterOverlay.setupGuide:
        return SetupGuideScreen(
          embedded: true,
          onBack: () => shell?.popCenterOverlay(entry: overlayEntry),
          onClose: () => shell?.popCenterOverlay(entry: overlayEntry),
        );
      case WorkspaceCenterOverlay.none:
        break;
    }

    switch (root) {
      case WorkspaceCenterRoot.offline:
        return WorkspaceLandingScreen(
          isConnected: connectionState != BridgeConnectionState.disconnected,
          hasSessions: hasSessions,
        );
      case WorkspaceCenterRoot.session:
        if (selection == null) {
          return WorkspaceLandingScreen(
            isConnected: connectionState != BridgeConnectionState.disconnected,
            hasSessions: hasSessions,
          );
        }
    }

    return switch (selection.provider) {
      Provider.codex => CodexSessionScreen(
        key: ValueKey('workspace_codex_${selection.sessionId}'),
        sessionId: selection.sessionId,
        projectPath: selection.projectPath,
        workspace: selection.workspace,
        gitBranch: selection.gitBranch,
        worktreePath: selection.worktreePath,
        isPending: selection.isPending,
        initialSandboxMode: selection.sandboxMode,
        initialPermissionMode: selection.permissionMode,
        initialApprovalPolicy: selection.approvalPolicy,
        initialApprovalsReviewer: selection.approvalsReviewer,
        pendingSessionCreated: selection.pendingSessionCreated,
        onBackToSessions: () =>
            shell?.clearSelectedSession(entry: sessionEntry),
        hideSessionBackButton: !(shell?.isSinglePane ?? true),
      ),
      _ => ClaudeSessionScreen(
        key: ValueKey('workspace_claude_${selection.sessionId}'),
        sessionId: selection.sessionId,
        projectPath: selection.projectPath,
        workspace: selection.workspace,
        gitBranch: selection.gitBranch,
        worktreePath: selection.worktreePath,
        isPending: selection.isPending,
        initialPermissionMode: selection.permissionMode,
        initialSandboxMode: selection.sandboxMode,
        pendingSessionCreated: selection.pendingSessionCreated,
        onBackToSessions: () =>
            shell?.clearSelectedSession(entry: sessionEntry),
        hideSessionBackButton: !(shell?.isSinglePane ?? true),
      ),
    };
  }
}

@Deprecated('Use WorkspaceLandingScreen instead.')
@RoutePage(name: 'WorkspacePlaceholderRoute')
class WorkspacePlaceholderScreen extends StatelessWidget {
  const WorkspacePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const WorkspaceLandingScreen(isConnected: false);
  }
}

class WorkspaceLandingScreen extends StatelessWidget {
  final bool isConnected;
  final bool hasSessions;

  const WorkspaceLandingScreen({
    super.key,
    required this.isConnected,
    this.hasSessions = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final shell = WorkspaceShellScreen.maybeOf(context);

    return ListenableBuilder(
      listenable:
          shell?.presentationListenable ?? const _PlaceholderNoopListenable(),
      builder: (context, _) {
        return Scaffold(
          backgroundColor: theme.colorScheme.surfaceContainerLowest,
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: theme.dividerColor.withValues(alpha: 0.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 32,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.forum_outlined,
                            color: theme.colorScheme.onPrimaryContainer,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          l.appTitle,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isConnected
                              ? (hasSessions
                                    ? l.workspaceLandingSelectSessionMessage
                                    : l.workspaceLandingCreateSessionMessage)
                              : l.workspaceLandingDisconnectedMessage,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        if (!isConnected)
                          OutlinedButton.icon(
                            key: const ValueKey('workspace_setup_guide_button'),
                            onPressed:
                                shell?.openSetupGuideCenter ??
                                () => context.router.push(SetupGuideRoute()),
                            icon: const Icon(Icons.lightbulb_outline),
                            label: Text('${l.setupGuide} →'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlaceholderNoopListenable implements Listenable {
  const _PlaceholderNoopListenable();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
