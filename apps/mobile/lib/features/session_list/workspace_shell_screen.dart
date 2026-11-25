import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_constants.dart';
import '../../features/chat_session/state/chat_session_cubit.dart';
import '../../features/chat_session/widgets/session_mode_bar.dart';
import '../../features/claude_session/claude_session_screen.dart';
import '../../features/codex_session/codex_session_screen.dart';
import '../../features/explore/explore_screen.dart';
import '../../features/explore/state/explore_state.dart';
import '../../features/gallery/gallery_screen.dart';
import '../../features/git/git_screen.dart';
import '../../features/github/github_screen.dart';
import '../../features/local_bridge/local_bridge_screen.dart';
import '../../features/settings/changelog_screen.dart';
import '../../features/settings/models/settings_catalog.dart';
import '../../features/settings/sections/shortcuts_settings_section.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/state/settings_state.dart';
import '../../features/settings/widgets/keyboard_shortcuts_dialog.dart';
import '../../features/setup_guide/setup_guide_screen.dart';
import '../../l10n/app_localizations.dart';
import '../../models/machine.dart';
import '../../models/messages.dart';
import '../../providers/bridge_cubits.dart';
import '../../providers/machine_manager_cubit.dart';
import '../../router/app_router.dart';
import '../../router/session_stack_navigation.dart';
import '../../services/app_update_service.dart';
import '../../services/bridge_service.dart';
import '../../services/connection_url_parser.dart';
import '../../services/desktop_menu_service.dart';
import '../../services/notification_service.dart';
import '../../utils/diff_parser.dart';
import '../../utils/network_endpoint.dart';
import '../../utils/platform_helper.dart';
import '../../widgets/workspace_pane_chrome.dart';
import 'session_list_screen.dart';
import '../workspace/state/workspace_navigation_cubit.dart';
import '../workspace/state/workspace_navigation_state.dart';
import '../workspace/state/workspace_destination.dart';
import '../workspace/widgets/workspace_pane_navigator.dart';
import '../workspace/workspace_layout_metrics.dart';
import '../settings/state/settings_cubit.dart';
import '../../widgets/duo/duo_control_strip.dart';
import '../../widgets/soft_keyboard_dismissal.dart';

export '../workspace/state/workspace_destination.dart'
    show WorkspaceSessionSelection;

const _twoPaneDividerWidth = kWorkspacePaneDividerWidth;
const _paneResizeHandleWidth = _twoPaneDividerWidth;
const _paneResizePointerHandleWidth = 12.0;
const _paneResizeTouchHandleWidth = 44.0;
const _minCenterPaneWidth = kWorkspaceMinCenterPaneWidth;
const _minRightPaneWidth = kWorkspaceMinToolPaneWidth;
const _minUserLeftPaneWidth = 220.0;
const _maxUserLeftPaneWidth = 480.0;

const _prefKeyLeftPaneWidth = 'workspace_left_pane_width';
const _prefKeyRightPaneWidth = 'workspace_right_pane_width';
const _prefKeySidebarCollapsed = 'workspace_sidebar_collapsed';

enum _WorkspaceLayoutMode { single, multiPane }

double _leftPaneWidth(double width) {
  if (width < 1024) return kWorkspaceMinListPaneWidth;
  return width >= 1280 ? 360 : 320;
}

double _rightPaneWidth(double width) {
  if (width < 820) return 240;
  if (width < 890) return 260;
  if (width < 1024) return 280;
  return width >= 1360 ? 380 : 320;
}

/// Whether an open tool pane must cover the session list because list,
/// center and tool cannot all fit (only below a lowered split threshold).
bool _toolCoversListAtWidth(double width) =>
    width < kWorkspaceThreePaneMinWidth;

double _maxLeftPaneWidth({
  required double totalWidth,
  required bool rightVisible,
  required double currentRightWidth,
}) {
  final dividerCount = rightVisible ? 2 : 1;
  final rightReserved = rightVisible ? currentRightWidth : 0.0;
  final availableWidth =
      totalWidth -
      rightReserved -
      (dividerCount * _paneResizeHandleWidth) -
      _minCenterPaneWidth;
  return availableWidth.clamp(0.0, _maxUserLeftPaneWidth).toDouble();
}

double _minAllowedLeftPaneWidth(double maxWidth) {
  if (maxWidth <= 0) return 0;
  return maxWidth < _minUserLeftPaneWidth ? maxWidth : _minUserLeftPaneWidth;
}

double _maxRightPaneWidth({
  required double totalWidth,
  required bool listVisible,
  double? leftPaneWidthOverride,
}) {
  final leftWidth = listVisible
      ? (leftPaneWidthOverride ?? _leftPaneWidth(totalWidth))
      : 0.0;
  final dividerCount = listVisible ? 2 : 1;
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

_WorkspaceLayoutMode _layoutModeForWidth(double width, double breakpoint) {
  return width >= breakpoint
      ? _WorkspaceLayoutMode.multiPane
      : _WorkspaceLayoutMode.single;
}

enum _ToolPaneKind { none, git, explore, gallery, github }

@immutable
class _DesktopMenuSyncSnapshot {
  const _DesktopMenuSyncSnapshot({
    required this.localeTag,
    required this.showConnectedUI,
    required this.canDisconnect,
    required this.hasActiveSession,
    required this.hasActiveProjectPath,
    required this.overlay,
    required this.isSinglePane,
    required this.isSidebarCollapsed,
    required this.toolKind,
    required this.checkingForUpdates,
  });

  final String localeTag;
  final bool showConnectedUI;
  final bool canDisconnect;
  final bool hasActiveSession;
  final bool hasActiveProjectPath;
  final WorkspaceCenterOverlay overlay;
  final bool isSinglePane;
  final bool isSidebarCollapsed;
  final _ToolPaneKind toolKind;
  final bool checkingForUpdates;

  @override
  bool operator ==(Object other) =>
      other is _DesktopMenuSyncSnapshot &&
      other.localeTag == localeTag &&
      other.showConnectedUI == showConnectedUI &&
      other.canDisconnect == canDisconnect &&
      other.hasActiveSession == hasActiveSession &&
      other.hasActiveProjectPath == hasActiveProjectPath &&
      other.overlay == overlay &&
      other.isSinglePane == isSinglePane &&
      other.isSidebarCollapsed == isSidebarCollapsed &&
      other.toolKind == toolKind &&
      other.checkingForUpdates == checkingForUpdates;

  @override
  int get hashCode => Object.hash(
    localeTag,
    showConnectedUI,
    canDisconnect,
    hasActiveSession,
    hasActiveProjectPath,
    overlay,
    isSinglePane,
    isSidebarCollapsed,
    toolKind,
    checkingForUpdates,
  );
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
  final DesktopMenuService? desktopMenuService;
  final Future<AppUpdateInfo?> Function()? checkForUpdatesOverride;

  const WorkspaceShellScreen({
    super.key,
    this.deepLinkNotifier,
    this.debugRecentSessions,
    this.initialSession,
    this.desktopMenuService,
    this.checkForUpdatesOverride,
  });

  static WorkspaceShellScreenState? _activeShell;

  /// The currently mounted root workspace shell, if any.
  static WorkspaceShellScreenState? get activeShell => _activeShell;

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
  // Back-swipe progress of the pane navigators. A compact back swipe reveals
  // the list underneath, so it must be live (not obscured) during the drag.
  final Map<GlobalKey<NavigatorState>, ValueListenable<bool>>
  _paneGestureNotifiers = {};
  GlobalKey<NavigatorState> _browserNavigatorKey = GlobalKey<NavigatorState>();
  WidgetBuilder? _browserBuilder;
  VoidCallback? _browserBack;
  bool _listWasCovered = false;
  Completer<void>? _browserCompletion;

  Future<void> showFileBrowser({
    required Widget Function(VoidCallback close) builder,
    required VoidCallback Function(VoidCallback close) back,
  }) {
    closeFileBrowser();
    final completion = Completer<void>();
    void close() {
      if (identical(_browserCompletion, completion)) closeFileBrowser();
    }

    setState(() {
      _browserNavigatorKey = GlobalKey<NavigatorState>();
      _browserCompletion = completion;
      _browserBuilder = (_) => builder(close);
      _browserBack = back(close);
    });
    _notifyPresentationChanged();
    return completion.future;
  }

  void closeFileBrowser() {
    if (_browserCompletion == null) return;
    final completion = _browserCompletion;
    setState(() {
      _browserBuilder = null;
      _browserBack = null;
      _browserCompletion = null;
    });
    completion?.complete();
    _notifyPresentationChanged();
  }

  _WorkspaceLayoutMode _layoutMode = _WorkspaceLayoutMode.single;
  bool _toolCoversList = false;
  StreamSubscription<String>? _stoppedSessionSub;
  StreamSubscription<WorkspaceNavigationState>? _navigationSub;
  StreamSubscription<DesktopMenuAction>? _desktopMenuActionSub;
  double? _leftPaneUserWidth;
  double? _rightPaneUserWidth;
  bool _checkingForUpdates = false;
  bool _shortcutsDialogOpen = false;
  Set<String> _unseenSessionIds = const {};
  _DesktopMenuSyncSnapshot? _lastMenuSyncSnapshot;
  String? _lastWindowTitle;
  bool _dockBadgeInitialized = false;
  String? _lastDockBadge;
  final ValueNotifier<int> _presentationVersion = ValueNotifier<int>(0);

  DesktopMenuService get _desktopMenuService =>
      widget.desktopMenuService ?? DesktopMenuService.instance;

  WorkspaceNavigationState get _state => _navigation.state;
  WorkspaceToolPaneData? get _toolPane => _state.tool;
  WorkspaceSessionSelection? get _selectedSession => _state.selection;
  WorkspaceCenterOverlay get _centerOverlay => _state.overlay;
  bool get canOpenToolPane => true;

  /// Opens the new-session sheet of the session list, while it can start one
  /// (connected). Lets a chat offer New when the list is not in reach, as on
  /// the iPhone Duo control strip.
  VoidCallback? newSessionHandler;
  VoidCallback? openSearchHandler;
  VoidCallback? refreshHandler;
  VoidCallback? disconnectHandler;
  ValueChanged<int>? selectSessionByIndexHandler;
  bool get canRequestNewSession => newSessionHandler != null;
  void requestNewSession() => newSessionHandler?.call();
  bool get isSinglePane => _layoutMode == _WorkspaceLayoutMode.single;
  bool get isSidebarCollapsed => !isSinglePane && _state.isSidebarCollapsed;
  bool get isLeftPaneVisible => isSinglePane
      ? (_selectedSession == null &&
            _centerOverlay == WorkspaceCenterOverlay.none &&
            _toolPane == null)
      : (!_toolCoversList && !_state.isSidebarCollapsed);
  WorkspaceSessionSelection? get selectedSession => _selectedSession;
  String? get liveSessionId => _state.liveSessionId;
  ValueNotifier<int> get presentationListenable => _presentationVersion;

  void updateUnseenSessionIds(Set<String> unseenSessionIds) {
    if (setEquals(_unseenSessionIds, unseenSessionIds)) return;
    _unseenSessionIds = Set<String>.unmodifiable(unseenSessionIds);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncDockBadgeFromCurrentContext();
    });
  }

  void setSidebarCollapsed(bool collapsed) {
    if (_state.isSidebarCollapsed == collapsed) return;
    _navigation.setSidebarCollapsed(collapsed);
    unawaited(_persistSidebarCollapsed(collapsed));
  }

  void toggleSidebar() {
    if (isSinglePane) return;
    setSidebarCollapsed(!_state.isSidebarCollapsed);
  }

  Future<void> _loadPersistedPaneLayout() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final savedLeft = prefs.getDouble(_prefKeyLeftPaneWidth);
    final savedRight = prefs.getDouble(_prefKeyRightPaneWidth);
    final savedCollapsed = prefs.getBool(_prefKeySidebarCollapsed);
    final nextLeft =
        savedLeft != null &&
            savedLeft.isFinite &&
            savedLeft >= _minUserLeftPaneWidth &&
            savedLeft <= _maxUserLeftPaneWidth
        ? savedLeft
        : null;
    final nextRight =
        savedRight != null &&
            savedRight.isFinite &&
            savedRight >= _minRightPaneWidth
        ? savedRight
        : null;
    if (nextLeft != _leftPaneUserWidth || nextRight != _rightPaneUserWidth) {
      setState(() {
        _leftPaneUserWidth = nextLeft;
        _rightPaneUserWidth = nextRight;
      });
    }
    if (savedCollapsed != null && savedCollapsed != _state.isSidebarCollapsed) {
      _navigation.setSidebarCollapsed(savedCollapsed);
    }
  }

  Future<void> _persistLeftPaneWidth(double width) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefKeyLeftPaneWidth, width);
  }

  Future<void> _persistRightPaneWidth(double width) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefKeyRightPaneWidth, width);
  }

  Future<void> _persistSidebarCollapsed(bool collapsed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeySidebarCollapsed, collapsed);
  }

  void _notifyPresentationChanged() {
    _presentationVersion.value++;
    final routeIdentity = _homeRouteIdentity;
    if (routeIdentity != null) {
      if (_state.liveSessionId case final id?) {
        SessionRouteRegistry.instance.update(
          routeIdentity: routeIdentity,
          owner: this,
          sessionId: id,
          provider: (_selectedSession?.provider ?? Provider.claude).value,
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
        _browserBuilder == null &&
        _selectedSession != null &&
        _centerOverlay == WorkspaceCenterOverlay.none &&
        (!isSinglePane || _toolPane == null || _state.centerInFront);
    if (visible) {
      NotificationService.instance.setActiveSession(
        owner: this,
        sessionId: _state.liveSessionId!,
        provider: (_selectedSession?.provider ?? Provider.claude).value,
      );
    } else {
      NotificationService.instance.clearActiveSession(owner: this);
    }
  }

  bool isToolPaneOpen(String paneId) => _toolPane?.id == paneId;

  @override
  void initState() {
    super.initState();
    WorkspaceShellScreen._activeShell = this;
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
    _desktopMenuActionSub = _desktopMenuService.actions.listen(
      handleDesktopMenuAction,
    );
    unawaited(_loadPersistedPaneLayout());
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

  /// Opens the Issues / PRs pane for the chat of [sessionId]. Like the other
  /// tools, opening the pane that is already open closes it unless [toggle]
  /// is false.
  void openGitHubPane({
    required String projectPath,
    required String sessionId,
    bool toggle = true,
  }) {
    final pane = GitHubToolPaneData(
      projectPath: projectPath,
      sessionId: sessionId,
    );
    if (!toggle && _toolPane?.id == pane.id) return;
    _openToolPane(pane);
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
    SettingsCategory? initialCategory,
    bool focusSupport = false,
    bool focusConnection = false,
    bool focusUsage = false,
    bool focusAppUpdate = false,
    bool toggle = true,
  }) {
    final hasSpecificTarget =
        initialCategory != null ||
        focusSupport ||
        focusConnection ||
        focusUsage;
    // The update focus follows the settings badge, so the settings button
    // still toggles the overlay closed when settings is already open.
    if (_centerOverlay == WorkspaceCenterOverlay.settings &&
        !hasSpecificTarget) {
      if (toggle) {
        popCenterOverlay();
      } else {
        _navigation.activateCenter();
      }
      return;
    }
    if (!toggle &&
        _centerOverlay == WorkspaceCenterOverlay.settings &&
        initialCategory != null &&
        _state.settingsInitialCategory == initialCategory) {
      _navigation.activateCenter();
      return;
    }
    _navigation.openOverlay(
      WorkspaceCenterOverlay.settings,
      settingsInitialCategory: initialCategory,
      focusSupport: focusSupport,
      focusConnection: focusConnection,
      focusUsage: focusUsage,
      focusAppUpdate: focusAppUpdate,
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

  /// Shows the management screen of the Bridge on this Mac in the center.
  void openLocalBridgeCenter() {
    if (_centerOverlay != WorkspaceCenterOverlay.localBridge) {
      _navigation.openOverlay(WorkspaceCenterOverlay.localBridge);
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
      // Reopened from the empty chat's entry.
      GitHubToolPaneData() => null,
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

  void resizeLeftPane(
    double nextWidth,
    double totalWidth, {
    required bool rightVisible,
    required double currentRightWidth,
    bool persist = false,
  }) {
    if (isSinglePane || _state.isSidebarCollapsed) return;
    final maxWidth = _maxLeftPaneWidth(
      totalWidth: totalWidth,
      rightVisible: rightVisible,
      currentRightWidth: currentRightWidth,
    );
    final minWidth = _minAllowedLeftPaneWidth(maxWidth);
    final clamped = nextWidth.clamp(minWidth, maxWidth).toDouble();
    setState(() {
      _leftPaneUserWidth = clamped;
    });
    if (persist) {
      unawaited(_persistLeftPaneWidth(clamped));
    }
  }

  void resizeRightPane(
    double nextWidth,
    double totalWidth, {
    double? leftPaneWidth,
    bool persist = false,
  }) {
    if (_toolPane == null) return;
    final listVisible =
        !_toolCoversListAtWidth(totalWidth) && !_state.isSidebarCollapsed;
    final maxWidth = _maxRightPaneWidth(
      totalWidth: totalWidth,
      listVisible: listVisible,
      leftPaneWidthOverride: leftPaneWidth,
    );
    final minWidth = _minAllowedRightPaneWidth(maxWidth);
    final clamped = nextWidth.clamp(minWidth, maxWidth).toDouble();
    setState(() {
      _rightPaneUserWidth = clamped;
    });
    if (persist) {
      unawaited(_persistRightPaneWidth(clamped));
    }
  }

  void closeToolPane({int? entry}) {
    if (entry != null && entry != _state.toolEntry) return;
    _forgetToolPaneForSession(_state.liveSessionId ?? _toolPane?.sessionId);
    _navigation.closeTool();
  }

  /// Dispose the previous machine's chat before connecting to another target.
  /// Waiting for the frame prevents its reconnect listener from sending history
  /// requests or retrying messages against the new Bridge.
  Future<void> prepareForBridgeConnection(String url) async {
    final bridge = context.read<BridgeService>();
    final previousUrl = bridge.lastUrl;
    if (previousUrl == null || bridge.sameBridgeTarget(previousUrl, url)) {
      return;
    }
    resetWorkspace();
    await WidgetsBinding.instance.endOfFrame;
  }

  void resetWorkspace() {
    closeFileBrowser();
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
    closeFileBrowser();
    _rememberVisibleToolPane();
    _navigation.selectSession(
      selection,
      restoredTool: _restoreToolPaneForSession(selection.sessionId),
    );
  }

  void clearSelectedSession({int? entry}) {
    if (entry != null && entry != _state.sessionEntry) return;
    closeFileBrowser();
    _toolPaneSnapshots.clear();
    _toolPaneBindings.clear();
    _navigation.closeSession();
  }

  void _clearSelectedSessionIfStopped(String sessionId) {
    if (_state.liveSessionId != sessionId) return;
    clearSelectedSession();
  }

  void _syncLayoutState(_WorkspaceLayoutMode nextMode, bool toolCoversList) {
    if (nextMode == _layoutMode && toolCoversList == _toolCoversList) return;
    _layoutMode = nextMode;
    _toolCoversList = toolCoversList;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notifyPresentationChanged();
    });
  }

  void _popRootOverlaysToWorkspace() {
    final rootNav = Navigator.maybeOf(context, rootNavigator: true);
    if (rootNav != null && rootNav.canPop()) {
      rootNav.popUntil((route) => route.isFirst);
    }
  }

  SessionInfo? _activeSessionInfo(List<SessionInfo> sessions) {
    final activeId = _state.liveSessionId ?? _selectedSession?.sessionId;
    if (activeId == null) return null;
    for (final session in sessions) {
      if (session.id == activeId) return session;
    }
    return null;
  }

  String? _activeProjectPath(List<SessionInfo> sessions) {
    final liveInfo = _activeSessionInfo(sessions);
    final path = liveInfo?.projectPath ?? _selectedSession?.projectPath;
    if (path == null || path.trim().isEmpty) return null;
    return path;
  }

  String? _activeWorktreePath(List<SessionInfo> sessions) {
    final liveInfo = _activeSessionInfo(sessions);
    return liveInfo?.worktreePath ?? _selectedSession?.worktreePath;
  }

  BuildContext? _findActiveChatSessionContext() {
    final root = _centerNavigatorKey.currentContext;
    if (root == null) return null;
    BuildContext? found;
    void visit(Element element) {
      if (found != null) return;
      if (element.widget is BlocProvider<ChatSessionCubit>) {
        element.visitChildElements((child) {
          found ??= child;
        });
        return;
      }
      element.visitChildElements(visit);
    }

    (root as Element).visitChildElements(visit);
    return found;
  }

  Future<void> _handleCheckForUpdates() async {
    if (_checkingForUpdates || !mounted) return;
    setState(() => _checkingForUpdates = true);
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.settingsCheckingForUpdates)));
    try {
      final update =
          await (widget.checkForUpdatesOverride?.call() ??
              AppUpdateService.instance.checkForUpdate(force: true));
      if (!mounted) return;
      final currentL = AppLocalizations.of(context);
      final currentMessenger = ScaffoldMessenger.maybeOf(context);
      if (update != null) {
        currentMessenger
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(currentL.appUpdateAvailable(update.latestVersion)),
              action: SnackBarAction(
                label: update.canInstallInApp
                    ? currentL.update
                    : currentL.download,
                onPressed: () {
                  unawaited(AppUpdateService.instance.performUpdate(update));
                },
              ),
            ),
          );
      } else {
        currentMessenger
          ?..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(currentL.settingsUpToDate)));
      }
    } catch (_) {
      if (!mounted) return;
      final currentL = AppLocalizations.of(context);
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(currentL.settingsUpdateCheckFailed)),
        );
    } finally {
      if (mounted) {
        setState(() => _checkingForUpdates = false);
      }
    }
  }

  void _handleOpenSearch() {
    if (openSearchHandler == null) return;
    if (!isSinglePane && _state.isSidebarCollapsed) {
      setSidebarCollapsed(false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) openSearchHandler?.call();
      });
      return;
    }
    openSearchHandler?.call();
  }

  void _handleCloseActive() {
    final rootNav = Navigator.maybeOf(context, rootNavigator: true);
    if (rootNav != null && rootNav.canPop()) {
      unawaited(rootNav.maybePop());
      return;
    }
    if (_browserBuilder != null) {
      closeFileBrowser();
      return;
    }
    if (_centerOverlay != WorkspaceCenterOverlay.none) {
      popCenterOverlay();
      return;
    }
    if (_toolPane != null) {
      closeToolPane();
      return;
    }
    if (_selectedSession != null) {
      clearSelectedSession();
      return;
    }
    if (isMacOSPlatform) {
      unawaited(_desktopMenuService.closeWindow());
    }
  }

  void _handleStopGeneration() {
    final sessionId = _state.liveSessionId ?? _selectedSession?.sessionId;
    if (sessionId == null) return;
    final bridge = context.read<BridgeService>();
    final liveInfo = _activeSessionInfo(bridge.sessions);
    if (liveInfo != null && liveInfo.status == 'idle') return;
    bridge.interrupt(sessionId);
  }

  void _handlePermissionMode() {
    if (_selectedSession == null ||
        _centerOverlay != WorkspaceCenterOverlay.none) {
      return;
    }
    final chatContext = _findActiveChatSessionContext();
    if (chatContext == null || !chatContext.mounted) return;
    final cubit = chatContext.read<ChatSessionCubit>();
    if (_selectedSession?.provider == Provider.codex) {
      showCodexPermissionsMenu(chatContext, cubit);
    } else {
      showPermissionModeMenu(chatContext, cubit);
    }
  }

  Future<void> _handleShowShortcuts() async {
    if (_shortcutsDialogOpen) {
      final rootNav = Navigator.maybeOf(context, rootNavigator: true);
      if (rootNav != null && rootNav.canPop()) {
        unawaited(rootNav.maybePop());
      }
      return;
    }
    _shortcutsDialogOpen = true;
    try {
      await KeyboardShortcutsDialog.show(context);
    } finally {
      _shortcutsDialogOpen = false;
    }
  }

  void _handleOpenChangelog() {
    try {
      context.router.navigate(const ChangelogRoute());
    } catch (_) {
      Navigator.of(
        context,
        rootNavigator: true,
      ).push(MaterialPageRoute<void>(builder: (_) => const ChangelogScreen()));
    }
  }

  void selectSessionByIndex(int index) {
    if (index < 0 || index > 8) return;
    selectSessionByIndexHandler?.call(index);
  }

  /// Dispatches a desktop menu or global keyboard shortcut action.
  void handleDesktopMenuAction(DesktopMenuAction action) {
    if (!mounted) return;
    final bridge = context.read<BridgeService>();
    final connectionState = context.read<ConnectionCubit>().state;
    final showConnectedUI =
        connectionState == BridgeConnectionState.connected ||
        connectionState == BridgeConnectionState.reconnecting;
    final sessionId = _state.liveSessionId ?? _selectedSession?.sessionId;
    final sessions = bridge.sessions;
    final projectPath = _activeProjectPath(sessions);
    final worktreePath = _activeWorktreePath(sessions);

    switch (action) {
      case DesktopMenuAction.openSettings:
        _popRootOverlaysToWorkspace();
        openSettingsCenter(toggle: false);
      case DesktopMenuAction.openLocalBridge:
        _popRootOverlaysToWorkspace();
        openSettingsCenter(
          initialCategory: SettingsCategory.localBridge,
          toggle: false,
        );
      case DesktopMenuAction.checkForUpdates:
        unawaited(_handleCheckForUpdates());
      case DesktopMenuAction.newSession:
        if (showConnectedUI) {
          requestNewSession();
        }
      case DesktopMenuAction.openSearch:
        if (showConnectedUI) {
          _handleOpenSearch();
        }
      case DesktopMenuAction.closeActive:
        _handleCloseActive();
      case DesktopMenuAction.toggleSidebar:
        toggleSidebar();
      case DesktopMenuAction.toggleGitPane:
        if (!showConnectedUI || sessionId == null) return;
        if (_toolPane is GitToolPaneData) {
          closeToolPane();
        } else if (projectPath != null) {
          openGitPane(
            projectPath: projectPath,
            sessionId: sessionId,
            worktreePath: worktreePath,
          );
        }
      case DesktopMenuAction.toggleExplorePane:
        if (!showConnectedUI || sessionId == null) return;
        if (_toolPane is ExploreToolPaneData) {
          closeToolPane();
        } else if (projectPath != null) {
          openExplorePane(sessionId: sessionId, projectPath: projectPath);
        }
      case DesktopMenuAction.toggleGalleryPane:
        if (!showConnectedUI || sessionId == null) return;
        if (_toolPane is GalleryToolPaneData) {
          closeToolPane();
        } else {
          openSessionGalleryPane(sessionId: sessionId);
        }
      case DesktopMenuAction.reload:
        refreshHandler?.call();
      case DesktopMenuAction.disconnect:
        disconnectHandler?.call();
      case DesktopMenuAction.zoomIn:
        context.read<SettingsCubit>().zoomIn();
      case DesktopMenuAction.zoomOut:
        context.read<SettingsCubit>().zoomOut();
      case DesktopMenuAction.actualSize:
        context.read<SettingsCubit>().resetZoom();
      case DesktopMenuAction.stopGeneration:
        if (showConnectedUI) {
          _handleStopGeneration();
        }
      case DesktopMenuAction.permissionMode:
        if (showConnectedUI) {
          _handlePermissionMode();
        }
      case DesktopMenuAction.showShortcuts:
        unawaited(_handleShowShortcuts());
      case DesktopMenuAction.openSetupGuide:
        _popRootOverlaysToWorkspace();
        if (_centerOverlay != WorkspaceCenterOverlay.setupGuide) {
          _navigation.openOverlay(WorkspaceCenterOverlay.setupGuide);
        } else {
          _navigation.activateCenter();
        }
      case DesktopMenuAction.openChangelog:
        _handleOpenChangelog();
      case DesktopMenuAction.openGitHub:
        unawaited(
          launchUrl(
            Uri.parse(AppConstants.githubUrl),
            mode: LaunchMode.externalApplication,
          ),
        );
    }
  }

  Map<ShortcutActivator, VoidCallback> _desktopShortcutBindings() {
    if (isMacOSPlatform) {
      // macOS native NSMenu (AppMenuBridge.swift) handles all menu key
      // equivalents; only bind shortcuts not present in NSMenu to prevent
      // double-firing.
      return <ShortcutActivator, VoidCallback>{
        for (var i = 0; i < 9; i++)
          SingleActivator(
            _digitKeys[i],
            meta: true,
            includeRepeats: false,
          ): () =>
              selectSessionByIndex(i),
      };
    }
    if (isDesktopPlatform) {
      return <ShortcutActivator, VoidCallback>{
        const SingleActivator(
          LogicalKeyboardKey.comma,
          control: true,
          includeRepeats: false,
        ): () =>
            handleDesktopMenuAction(DesktopMenuAction.openSettings),
        const SingleActivator(
          LogicalKeyboardKey.keyN,
          control: true,
          includeRepeats: false,
        ): () =>
            handleDesktopMenuAction(DesktopMenuAction.newSession),
        const SingleActivator(
          LogicalKeyboardKey.keyK,
          control: true,
          includeRepeats: false,
        ): () =>
            handleDesktopMenuAction(DesktopMenuAction.openSearch),
        const SingleActivator(
          LogicalKeyboardKey.keyW,
          control: true,
          includeRepeats: false,
        ): () =>
            handleDesktopMenuAction(DesktopMenuAction.closeActive),
        const SingleActivator(
          LogicalKeyboardKey.keyR,
          control: true,
          includeRepeats: false,
        ): () =>
            handleDesktopMenuAction(DesktopMenuAction.reload),
        const SingleActivator(
          LogicalKeyboardKey.backslash,
          control: true,
          includeRepeats: false,
        ): () =>
            handleDesktopMenuAction(DesktopMenuAction.toggleSidebar),
        const SingleActivator(
          LogicalKeyboardKey.keyG,
          control: true,
          shift: true,
          includeRepeats: false,
        ): () =>
            handleDesktopMenuAction(DesktopMenuAction.toggleGitPane),
        const SingleActivator(
          LogicalKeyboardKey.keyE,
          control: true,
          shift: true,
          includeRepeats: false,
        ): () =>
            handleDesktopMenuAction(DesktopMenuAction.toggleExplorePane),
        const SingleActivator(
          LogicalKeyboardKey.keyI,
          control: true,
          shift: true,
          includeRepeats: false,
        ): () =>
            handleDesktopMenuAction(DesktopMenuAction.toggleGalleryPane),
        const SingleActivator(
          LogicalKeyboardKey.digit0,
          control: true,
          includeRepeats: false,
        ): () =>
            handleDesktopMenuAction(DesktopMenuAction.actualSize),
        const SingleActivator(
          LogicalKeyboardKey.numpad0,
          control: true,
          includeRepeats: false,
        ): () =>
            handleDesktopMenuAction(DesktopMenuAction.actualSize),
        const SingleActivator(LogicalKeyboardKey.equal, control: true): () =>
            handleDesktopMenuAction(DesktopMenuAction.zoomIn),
        const SingleActivator(LogicalKeyboardKey.add, control: true): () =>
            handleDesktopMenuAction(DesktopMenuAction.zoomIn),
        const SingleActivator(
          LogicalKeyboardKey.numpadAdd,
          control: true,
        ): () =>
            handleDesktopMenuAction(DesktopMenuAction.zoomIn),
        const SingleActivator(LogicalKeyboardKey.minus, control: true): () =>
            handleDesktopMenuAction(DesktopMenuAction.zoomOut),
        const SingleActivator(
          LogicalKeyboardKey.numpadSubtract,
          control: true,
        ): () =>
            handleDesktopMenuAction(DesktopMenuAction.zoomOut),
        const SingleActivator(
          LogicalKeyboardKey.period,
          control: true,
          includeRepeats: false,
        ): () =>
            handleDesktopMenuAction(DesktopMenuAction.stopGeneration),
        const SingleActivator(
          LogicalKeyboardKey.keyP,
          control: true,
          shift: true,
          includeRepeats: false,
        ): () =>
            handleDesktopMenuAction(DesktopMenuAction.permissionMode),
        const SingleActivator(
          LogicalKeyboardKey.slash,
          control: true,
          includeRepeats: false,
        ): () =>
            handleDesktopMenuAction(DesktopMenuAction.showShortcuts),
        for (var i = 0; i < 9; i++)
          SingleActivator(
            _digitKeys[i],
            control: true,
            includeRepeats: false,
          ): () =>
              selectSessionByIndex(i),
      };
    }
    if (isIOSPlatform) {
      // Preserve iPad hardware keyboard shortcuts.
      return <ShortcutActivator, VoidCallback>{
        const SingleActivator(
          LogicalKeyboardKey.keyN,
          meta: true,
          includeRepeats: false,
        ): () =>
            handleDesktopMenuAction(DesktopMenuAction.newSession),
        const SingleActivator(
          LogicalKeyboardKey.keyK,
          meta: true,
          includeRepeats: false,
        ): () =>
            handleDesktopMenuAction(DesktopMenuAction.openSearch),
      };
    }
    return const <ShortcutActivator, VoidCallback>{};
  }

  static const List<LogicalKeyboardKey> _digitKeys = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
  ];

  String _resolveConnectedBridgeTitle({
    required SettingsState settingsState,
    required MachineManagerState? machineState,
    required String? lastUrl,
  }) {
    final machines = machineState?.machines ?? const <MachineWithStatus>[];
    final activeMachineId = settingsState.activeMachineId;
    if (activeMachineId != null) {
      for (final item in machines) {
        if (item.machine.id == activeMachineId) {
          return item.machine.displayName;
        }
      }
    }
    if (lastUrl != null && lastUrl.isNotEmpty) {
      final uri = Uri.tryParse(
        lastUrl
            .replaceFirst('ws://', 'http://')
            .replaceFirst('wss://', 'https://'),
      );
      if (uri != null && uri.host.isNotEmpty) {
        final port = uri.hasPort ? uri.port : 8765;
        for (final item in machines) {
          if (endpointIdentityKey(item.machine.host, item.machine.port) ==
              endpointIdentityKey(uri.host, port)) {
            return item.machine.displayName;
          }
        }
        return formatHostPort(uri.host, port);
      }
    }
    return '';
  }

  String _resolveWindowTitle({
    required AppLocalizations l,
    required bool showConnectedUI,
    required List<SessionInfo> activeSessions,
    required SettingsState settingsState,
    required MachineManagerState? machineState,
    required String? lastUrl,
  }) {
    if (_centerOverlay == WorkspaceCenterOverlay.settings) {
      return '${l.settingsTitle} — ${l.appTitle}';
    }
    if (_selectedSession != null) {
      final liveInfo = _activeSessionInfo(activeSessions);
      final sessionLabel = _firstNonEmpty([
        liveInfo?.name,
        liveInfo?.projectName,
        _selectedSession?.workspace?.projectName,
        if (_selectedSession?.projectPath != null)
          pathBasename(_selectedSession!.projectPath!),
      ]);
      if (sessionLabel != null) {
        return '$sessionLabel — ${l.appTitle}';
      }
    }
    if (showConnectedUI) {
      final bridgeTitle = _resolveConnectedBridgeTitle(
        settingsState: settingsState,
        machineState: machineState,
        lastUrl: lastUrl,
      );
      if (bridgeTitle.isNotEmpty) {
        return '$bridgeTitle — ${l.appTitle}';
      }
    }
    return l.appTitle;
  }

  String? _firstNonEmpty(Iterable<String?> candidates) {
    for (final candidate in candidates) {
      final trimmed = candidate?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  String? _computeDockBadge({
    required bool showConnectedUI,
    required List<SessionInfo> activeSessions,
  }) {
    if (!showConnectedUI) return null;
    final activeSessionId = _centerOverlay == WorkspaceCenterOverlay.none
        ? (_state.liveSessionId ?? _selectedSession?.sessionId)
        : null;
    final attentionIds = <String>{
      for (final id in _unseenSessionIds)
        if (id != activeSessionId) id,
      for (final session in activeSessions)
        if (session.pendingPermission != null ||
            session.status == 'waiting_approval')
          session.id,
    };
    if (attentionIds.isEmpty) return null;
    return '${attentionIds.length}';
  }

  void _syncDockBadgeFromCurrentContext() {
    if (!_desktopMenuService.isSupported || !mounted) return;
    final connectionState = context.read<ConnectionCubit>().state;
    final showConnectedUI =
        connectionState == BridgeConnectionState.connected ||
        connectionState == BridgeConnectionState.reconnecting;
    final activeSessions =
        context.read<ActiveSessionsCubit?>()?.state ??
        context.read<BridgeService>().sessions;
    final badge = _computeDockBadge(
      showConnectedUI: showConnectedUI,
      activeSessions: activeSessions,
    );
    if (!_dockBadgeInitialized || badge != _lastDockBadge) {
      _dockBadgeInitialized = true;
      _lastDockBadge = badge;
      unawaited(_desktopMenuService.setDockBadge(badge));
    }
  }

  void _syncDesktopChrome({
    required AppLocalizations l,
    required BridgeConnectionState connectionState,
    required List<SessionInfo> activeSessions,
    required SettingsState settingsState,
    required MachineManagerState? machineState,
    required String? lastUrl,
    required bool compact,
  }) {
    if (!_desktopMenuService.isSupported) return;
    final showConnectedUI =
        connectionState == BridgeConnectionState.connected ||
        connectionState == BridgeConnectionState.reconnecting;
    final canDisconnect =
        showConnectedUI || connectionState == BridgeConnectionState.connecting;
    final hasActiveSession = _selectedSession != null;
    final hasActiveProjectPath = _activeProjectPath(activeSessions) != null;
    final toolKind = switch (_toolPane) {
      GitToolPaneData() => _ToolPaneKind.git,
      ExploreToolPaneData() => _ToolPaneKind.explore,
      GalleryToolPaneData() => _ToolPaneKind.gallery,
      GitHubToolPaneData() => _ToolPaneKind.github,
      null => _ToolPaneKind.none,
    };
    final snapshot = _DesktopMenuSyncSnapshot(
      localeTag: l.localeName,
      showConnectedUI: showConnectedUI,
      canDisconnect: canDisconnect,
      hasActiveSession: hasActiveSession,
      hasActiveProjectPath: hasActiveProjectPath,
      overlay: _centerOverlay,
      isSinglePane: compact,
      isSidebarCollapsed: _state.isSidebarCollapsed,
      toolKind: toolKind,
      checkingForUpdates: _checkingForUpdates,
    );
    final windowTitle = _resolveWindowTitle(
      l: l,
      showConnectedUI: showConnectedUI,
      activeSessions: activeSessions,
      settingsState: settingsState,
      machineState: machineState,
      lastUrl: lastUrl,
    );
    final dockBadge = _computeDockBadge(
      showConnectedUI: showConnectedUI,
      activeSessions: activeSessions,
    );

    final shouldUpdateMenu = snapshot != _lastMenuSyncSnapshot;
    final shouldUpdateTitle = windowTitle != _lastWindowTitle;
    final shouldUpdateBadge =
        !_dockBadgeInitialized || dockBadge != _lastDockBadge;
    if (!shouldUpdateMenu && !shouldUpdateTitle && !shouldUpdateBadge) return;

    if (shouldUpdateMenu) {
      _lastMenuSyncSnapshot = snapshot;
    }
    if (shouldUpdateTitle) {
      _lastWindowTitle = windowTitle;
    }
    if (shouldUpdateBadge) {
      _dockBadgeInitialized = true;
      _lastDockBadge = dockBadge;
    }

    final closeTitle = switch (_centerOverlay) {
      WorkspaceCenterOverlay.settings => l.menuCloseSettings,
      WorkspaceCenterOverlay.none when hasActiveSession => l.menuCloseSession,
      _ => l.menuCloseWindow,
    };

    final menuState = shouldUpdateMenu
        ? DesktopMenuState(
            menuTitles: {
              DesktopTopLevelMenu.file: l.menuFile,
              DesktopTopLevelMenu.view: l.menuView,
              DesktopTopLevelMenu.session: l.menuSession,
            },
            items: {
              DesktopMenuAction.openSettings: DesktopMenuItemState(
                title: '${l.settings}…',
                enabled: true,
              ),
              DesktopMenuAction.openLocalBridge: DesktopMenuItemState(
                title: l.menuLocalBridgeSettings,
                enabled: true,
              ),
              DesktopMenuAction.checkForUpdates: DesktopMenuItemState(
                title: l.menuCheckForUpdates,
                enabled: !_checkingForUpdates,
              ),
              DesktopMenuAction.newSession: DesktopMenuItemState(
                title: l.menuNewSession,
                enabled: showConnectedUI,
              ),
              DesktopMenuAction.closeActive: DesktopMenuItemState(
                title: closeTitle,
                enabled: true,
              ),
              DesktopMenuAction.reload: DesktopMenuItemState(
                title: l.menuReconnect,
                enabled: true,
              ),
              DesktopMenuAction.disconnect: DesktopMenuItemState(
                title: l.menuDisconnect,
                enabled: canDisconnect,
              ),
              DesktopMenuAction.toggleSidebar: DesktopMenuItemState(
                title: l.menuToggleSidebar,
                enabled: !compact,
                checked: !compact && !_state.isSidebarCollapsed,
              ),
              DesktopMenuAction.openSearch: DesktopMenuItemState(
                title: l.menuQuickSearch,
                enabled: showConnectedUI,
              ),
              DesktopMenuAction.toggleGitPane: DesktopMenuItemState(
                title: l.menuGitDiff,
                enabled:
                    showConnectedUI && hasActiveSession && hasActiveProjectPath,
                checked: toolKind == _ToolPaneKind.git,
              ),
              DesktopMenuAction.toggleExplorePane: DesktopMenuItemState(
                title: l.menuFileExplorer,
                enabled:
                    showConnectedUI && hasActiveSession && hasActiveProjectPath,
                checked: toolKind == _ToolPaneKind.explore,
              ),
              DesktopMenuAction.toggleGalleryPane: DesktopMenuItemState(
                title: l.menuGallery,
                enabled: showConnectedUI && hasActiveSession,
                checked: toolKind == _ToolPaneKind.gallery,
              ),
              DesktopMenuAction.actualSize: DesktopMenuItemState(
                title: l.menuActualSize,
                enabled: true,
              ),
              DesktopMenuAction.zoomIn: DesktopMenuItemState(
                title: l.menuZoomIn,
                enabled: true,
              ),
              DesktopMenuAction.zoomOut: DesktopMenuItemState(
                title: l.menuZoomOut,
                enabled: true,
              ),
              DesktopMenuAction.stopGeneration: DesktopMenuItemState(
                title: l.menuStopGeneration,
                enabled: showConnectedUI && hasActiveSession,
              ),
              DesktopMenuAction.permissionMode: DesktopMenuItemState(
                title: l.menuPermissionMode,
                enabled:
                    showConnectedUI &&
                    hasActiveSession &&
                    _centerOverlay == WorkspaceCenterOverlay.none,
              ),
              DesktopMenuAction.showShortcuts: DesktopMenuItemState(
                title: l.menuKeyboardShortcuts,
                enabled: true,
              ),
              DesktopMenuAction.openSetupGuide: DesktopMenuItemState(
                title: l.menuSetupGuide,
                enabled: true,
              ),
              DesktopMenuAction.openChangelog: DesktopMenuItemState(
                title: l.menuChangelog,
                enabled: true,
              ),
              DesktopMenuAction.openGitHub: DesktopMenuItemState(
                title: l.menuGitHubRepo,
                enabled: true,
              ),
            },
          )
        : null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (menuState != null) {
        unawaited(_desktopMenuService.updateMenuState(menuState));
      }
      if (shouldUpdateTitle) {
        unawaited(_desktopMenuService.setWindowTitle(windowTitle));
      }
      if (shouldUpdateBadge) {
        unawaited(_desktopMenuService.setDockBadge(dockBadge));
      }
    });
  }

  @override
  void dispose() {
    if (identical(WorkspaceShellScreen._activeShell, this)) {
      WorkspaceShellScreen._activeShell = null;
    }
    _browserCompletion?.complete();
    _browserCompletion = null;
    NotificationService.instance.clearActiveSession(owner: this);
    _stoppedSessionSub?.cancel();
    _navigationSub?.cancel();
    _desktopMenuActionSub?.cancel();
    _navigation.close();
    if (_homeRouteIdentity case final identity?) {
      SessionRouteRegistry.instance.unregisterWorkspace(identity, this);
    }
    _presentationVersion.dispose();
    for (final notifier in _paneGestureNotifiers.values) {
      notifier.removeListener(_handlePaneGestureChanged);
    }
    super.dispose();
  }

  bool get _paneBackGestureInProgress =>
      _paneGestureNotifiers.values.any((notifier) => notifier.value);

  /// Tracks the pane navigators' user gesture notifiers. The navigators only
  /// exist after the first build, so this runs after each frame and is a no-op
  /// once attached.
  void _attachPaneGestureListeners() {
    for (final key in [_centerNavigatorKey, _toolNavigatorKey]) {
      final notifier = key.currentState?.userGestureInProgressNotifier;
      final attached = _paneGestureNotifiers[key];
      if (identical(notifier, attached)) continue;
      attached?.removeListener(_handlePaneGestureChanged);
      if (notifier == null) {
        _paneGestureNotifiers.remove(key);
      } else {
        notifier.addListener(_handlePaneGestureChanged);
        _paneGestureNotifiers[key] = notifier;
      }
    }
  }

  /// A keyboard still up when a compact covering pane closes was left behind
  /// by that pane, unless a text field (e.g. in a sheet) still owns it.
  void _dismissKeyboardLeftOnList() {
    if (!mounted || !isSinglePane || !isSoftKeyboardVisible(context)) return;
    final focus = FocusManager.instance.primaryFocus;
    if (isTextInputFocus(focus)) return;
    focus?.unfocus();
    unawaited(hideSoftKeyboard());
  }

  void _handlePaneGestureChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final settingsState = context.watch<SettingsCubit>().state;
    final breakpoint = settingsState.multiPaneBreakpoint;
    final activeSessions =
        context.watch<ActiveSessionsCubit?>()?.state ??
        context.read<BridgeService>().sessions;
    final machineState = context.watch<MachineManagerCubit?>()?.state;
    final bridgeLastUrl = context.read<BridgeService>().lastUrl;
    final l = AppLocalizations.of(context);
    final shortcutBindings = _desktopShortcutBindings();

    return BlocListener<ConnectionCubit, BridgeConnectionState>(
      listener: (context, state) {
        if (state != BridgeConnectionState.disconnected) return;

        // Keep an open chat visible while disconnected, even if reconnecting
        // takes a long time. Only clear transient workspace overlays when
        // there is no selected chat to preserve.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted ||
              context.read<ConnectionCubit>().state !=
                  BridgeConnectionState.disconnected ||
              _selectedSession != null) {
            return;
          }
          resetWorkspace();
        });
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final connectionState = context.watch<ConnectionCubit>().state;
          final padding = MediaQuery.paddingOf(context);
          final usableWidth = (constraints.maxWidth - padding.horizontal).clamp(
            0.0,
            double.infinity,
          );
          final layoutMode = _layoutModeForWidth(usableWidth, breakpoint);
          final showRightPane = _toolPane != null;
          // Below the three-pane width (only reachable with a lowered split
          // threshold), an open tool pane takes the list's place.
          final toolCoversList =
              layoutMode == _WorkspaceLayoutMode.multiPane &&
              showRightPane &&
              _toolCoversListAtWidth(usableWidth);
          _syncLayoutState(layoutMode, toolCoversList);
          final compact = isSinglePane;
          final sidebarHidden =
              !compact && (toolCoversList || _state.isSidebarCollapsed);
          final showExpandSidebarInCenter =
              !compact && _state.isSidebarCollapsed;
          _syncDesktopChrome(
            l: l,
            connectionState: connectionState,
            activeSessions: activeSessions,
            settingsState: settingsState,
            machineState: machineState,
            lastUrl: bridgeLastUrl,
            compact: compact,
          );
          final sessionEntry = _state.sessionEntry;
          final toolEntry = _state.toolEntry;
          final overlayEntry = _state.overlayEntry;
          final hasCenter =
              _selectedSession != null ||
              _centerOverlay != WorkspaceCenterOverlay.none;
          // On compact layouts the list stays mounted underneath a covering
          // chat/tool pane so its state survives; it must not rebuild there.
          final listCovered =
              (compact && (hasCenter || showRightPane)) || sidebarHidden;
          // During an interactive back swipe the list is being revealed, so
          // it is kept live (fresh data, running tickers) for the drag.
          final listObscured = listCovered && !_paneBackGestureInProgress;
          if (_listWasCovered && !listCovered) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _dismissKeyboardLeftOnList(),
            );
          }
          _listWasCovered = listCovered;
          final centerActive =
              !compact ||
              (hasCenter && (!showRightPane || _state.centerInFront));
          final toolActive =
              showRightPane &&
              (!compact || !hasCenter || !_state.centerInFront);
          final defaultLeftWidth = _leftPaneWidth(usableWidth);
          final maxLeftContentWidth = _maxLeftPaneWidth(
            totalWidth: usableWidth,
            rightVisible: !compact && showRightPane && !toolCoversList,
            currentRightWidth: _minRightPaneWidth,
          );
          final leftContentWidth = compact
              ? constraints.maxWidth
              : _leftPaneUserWidth == null
              ? defaultLeftWidth
              : _leftPaneUserWidth!
                    .clamp(
                      _minAllowedLeftPaneWidth(maxLeftContentWidth),
                      maxLeftContentWidth,
                    )
                    .toDouble();
          final leftWidth = compact
              ? constraints.maxWidth
              : padding.left + leftContentWidth;
          final maxRightWidth = _maxRightPaneWidth(
            totalWidth: usableWidth,
            listVisible: !sidebarHidden,
            leftPaneWidthOverride: leftContentWidth,
          );
          final rightContentWidth = compact
              ? constraints.maxWidth
              : (_rightPaneUserWidth ?? _rightPaneWidth(usableWidth))
                    .clamp(
                      _minAllowedRightPaneWidth(maxRightWidth),
                      maxRightWidth,
                    )
                    .toDouble();
          final rightWidth = compact
              ? constraints.maxWidth
              : padding.right + rightContentWidth;
          final centerLeft = compact || sidebarHidden
              ? 0.0
              : leftWidth + _twoPaneDividerWidth;
          final centerRight = !compact && showRightPane
              ? rightWidth + _twoPaneDividerWidth
              : 0.0;
          final sidebarToggleTooltip = isDesktopPlatform
              ? '${l.menuToggleSidebar} (${isMacOSPlatform ? r'⌘\' : r'Ctrl+\'})'
              : l.menuToggleSidebar;
          final center = Positioned(
            key: const ValueKey('workspace_center_slot'),
            top: 0,
            bottom: 0,
            left: centerLeft,
            right: centerRight,
            child: WorkspaceSidebarChromeScope(
              showExpandSidebarButton: showExpandSidebarInCenter,
              onExpandSidebar: showExpandSidebarInCenter ? toggleSidebar : null,
              tooltip: sidebarToggleTooltip,
              child: MediaQuery.removePadding(
                context: context,
                removeLeft: !compact && !sidebarHidden,
                removeRight: !compact && showRightPane,
                child: WorkspacePaneNavigator(
                  navigatorKey: _centerNavigatorKey,
                  onInteraction: compact ? null : _navigation.activateCenter,
                  compact: compact,
                  active: centerActive && _browserBuilder == null,
                  handlesBack: !showRightPane || _state.centerInFront,
                  background: compact
                      ? const SizedBox.expand()
                      : _WorkspaceContentHost(
                          selection: null,
                          root: WorkspaceCenterRoot.offline,
                          overlay: WorkspaceCenterOverlay.none,
                          connectionState: connectionState,
                          settingsInitialCategory: null,
                          settingsFocusSupport: false,
                          settingsFocusConnection: false,
                          settingsFocusUsage: false,
                          settingsFocusAppUpdate: false,
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
                          settingsInitialCategory: null,
                          settingsFocusSupport: false,
                          settingsFocusConnection: false,
                          settingsFocusUsage: false,
                          settingsFocusAppUpdate: false,
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
                          settingsInitialCategory:
                              _state.settingsInitialCategory,
                          settingsFocusSupport: _state.settingsFocusSupport,
                          settingsFocusConnection:
                              _state.settingsFocusConnection,
                          settingsFocusUsage: _state.settingsFocusUsage,
                          settingsFocusAppUpdate: _state.settingsFocusAppUpdate,
                          settingsPresentationVersion: _state.overlayEntry,
                        ),
                      ),
                  ],
                  onDidRemovePage: (page) {
                    if (_selectedSession != null &&
                        page.key ==
                            ValueKey(('session', _state.sessionEntry))) {
                      clearSelectedSession();
                    } else if (_centerOverlay != WorkspaceCenterOverlay.none &&
                        page.key ==
                            ValueKey(('overlay', _state.overlayEntry))) {
                      popCenterOverlay();
                    }
                  },
                ),
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
                active: toolActive && _browserBuilder == null,
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
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _attachPaneGestureListeners();
          });
          final resizeHandleHitWidth = _resizeHandleHitWidth(
            Theme.of(context).platform,
          );
          final stack = Stack(
            children: [
              Positioned(
                key: const ValueKey('workspace_list_slot'),
                top: 0,
                bottom: 0,
                left: 0,
                width: leftWidth,
                child: IgnorePointer(
                  ignoring: listCovered,
                  child: ExcludeFocus(
                    excluding: listCovered,
                    child: ExcludeSemantics(
                      excluding: listCovered,
                      // Pause status-dot animations behind a covering pane,
                      // like Navigator does for covered routes.
                      child: TickerMode(
                        enabled: !listObscured,
                        child: ColoredBox(
                          color: Theme.of(context).colorScheme.surface,
                          child: MediaQuery.removePadding(
                            context: context,
                            removeRight: !compact,
                            child: DuoStripTouchRegion(
                              child: SessionListScreen(
                                deepLinkNotifier: widget.deepLinkNotifier,
                                debugRecentSessions: widget.debugRecentSessions,
                                embedded: !compact,
                                onSelectWorkspaceSession: selectSession,
                                obscured: listObscured,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_state.centerInFront) tool,
              center,
              if (!_state.centerInFront) tool,
              if (!compact && !sidebarHidden)
                Positioned(
                  top: 0,
                  bottom: 0,
                  left:
                      leftWidth -
                      ((resizeHandleHitWidth - _twoPaneDividerWidth) / 2),
                  width: resizeHandleHitWidth,
                  child: _WorkspaceResizeHandle(
                    key: const ValueKey('workspace_left_resize_handle'),
                    semanticsLabel: AppLocalizations.of(context).resizeSidebar,
                    invertSemanticStep: true,
                    color: Theme.of(context).dividerColor
                        .withValues(alpha: 0.18),
                    onDragUpdate: (delta) => resizeLeftPane(
                      leftContentWidth + delta,
                      usableWidth,
                      rightVisible: showRightPane,
                      currentRightWidth: rightContentWidth,
                    ),
                    onDragEnd: () {
                      final width = _leftPaneUserWidth;
                      if (width != null) {
                        unawaited(_persistLeftPaneWidth(width));
                      }
                    },
                    onSemanticStep: (delta) => resizeLeftPane(
                      leftContentWidth + delta,
                      usableWidth,
                      rightVisible: showRightPane,
                      currentRightWidth: rightContentWidth,
                      persist: true,
                    ),
                  ),
                ),
              if (!compact && showRightPane)
                Positioned(
                  top: 0,
                  bottom: 0,
                  right:
                      rightWidth -
                      ((resizeHandleHitWidth - _twoPaneDividerWidth) / 2),
                  width: resizeHandleHitWidth,
                  child: _WorkspaceResizeHandle(
                    key: const ValueKey('workspace_right_resize_handle'),
                    semanticsLabel: AppLocalizations.of(context)
                        .resizeRightPane,
                    color: Theme.of(context).dividerColor
                        .withValues(alpha: 0.18),
                    onDragUpdate: (delta) => resizeRightPane(
                      rightContentWidth - delta,
                      usableWidth,
                      leftPaneWidth: leftContentWidth,
                    ),
                    onDragEnd: () {
                      final width = _rightPaneUserWidth;
                      if (width != null) {
                        unawaited(_persistRightPaneWidth(width));
                      }
                    },
                    onSemanticStep: (delta) => resizeRightPane(
                      rightContentWidth - delta,
                      usableWidth,
                      leftPaneWidth: leftContentWidth,
                      persist: true,
                    ),
                  ),
                ),
              if (_browserBuilder != null)
                Positioned(
                  key: const ValueKey('workspace_browser_slot'),
                  top: 0,
                  bottom: 0,
                  left: centerLeft,
                  right: 0,
                  child: Navigator(
                    key: _browserNavigatorKey,
                    onGenerateRoute: (_) =>
                        MaterialPageRoute<void>(builder: _browserBuilder!),
                  ),
                ),
            ],
          );

          final body = PopScope(
            canPop: _browserBuilder == null,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) {
                final navigator = _browserNavigatorKey.currentState;
                if (navigator?.canPop() == true) {
                  navigator!.pop();
                } else {
                  _browserBack?.call();
                }
              }
            },
            child: stack,
          );

          if (shortcutBindings.isEmpty) {
            return body;
          }
          return CallbackShortcuts(
            bindings: shortcutBindings,
            child: Focus(
              autofocus: true,
              debugLabel: 'workspace_shell',
              child: body,
            ),
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

class _WorkspaceResizeHandle extends StatefulWidget {
  final Color color;
  final ValueChanged<double> onDragUpdate;
  final VoidCallback? onDragEnd;
  final ValueChanged<double>? onSemanticStep;
  final String semanticsLabel;
  final bool invertSemanticStep;

  const _WorkspaceResizeHandle({
    super.key,
    required this.color,
    required this.onDragUpdate,
    this.onDragEnd,
    this.onSemanticStep,
    required this.semanticsLabel,
    this.invertSemanticStep = false,
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
    final increaseDelta = widget.invertSemanticStep ? 48.0 : -48.0;
    final decreaseDelta = -increaseDelta;
    final applySemanticStep = widget.onSemanticStep ?? widget.onDragUpdate;

    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: Semantics(
        label: widget.semanticsLabel,
        hint: 'Drag horizontally to resize',
        enabled: true,
        onIncrease: () => applySemanticStep(increaseDelta),
        onDecrease: () => applySemanticStep(decreaseDelta),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: (_) => _setDragging(true),
          onHorizontalDragUpdate: (details) =>
              widget.onDragUpdate(details.delta.dx),
          onHorizontalDragEnd: (_) {
            _setDragging(false);
            widget.onDragEnd?.call();
          },
          onHorizontalDragCancel: () {
            _setDragging(false);
            widget.onDragEnd?.call();
          },
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
      GitHubToolPaneData(:final projectPath, :final sessionId) => GitHubScreen(
        projectPath: projectPath,
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
  final SettingsCategory? settingsInitialCategory;
  final bool settingsFocusSupport;
  final bool settingsFocusConnection;
  final bool settingsFocusUsage;
  final bool settingsFocusAppUpdate;
  final int settingsPresentationVersion;
  final int? sessionEntry;
  final int? overlayEntry;

  const _WorkspaceContentHost({
    required this.selection,
    required this.root,
    required this.overlay,
    required this.connectionState,
    required this.settingsInitialCategory,
    required this.settingsFocusSupport,
    required this.settingsFocusConnection,
    required this.settingsFocusUsage,
    required this.settingsFocusAppUpdate,
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
            '_${settingsInitialCategory?.name ?? ''}'
            '_$settingsFocusSupport'
            '_$settingsFocusConnection'
            '_$settingsFocusUsage'
            '_$settingsFocusAppUpdate',
          ),
          initialCategory: settingsInitialCategory,
          focusSupport: settingsFocusSupport,
          focusConnection: settingsFocusConnection,
          focusUsage: settingsFocusUsage,
          focusAppUpdate: settingsFocusAppUpdate,
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
      case WorkspaceCenterOverlay.localBridge:
        return LocalBridgeScreen(
          embedded: true,
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
      // Antigravity shares the Claude-style screen. An unknown provider is
      // Claude: Bridges that predate the field only ran Claude.
      Provider.claude || Provider.antigravity || null => ClaudeSessionScreen(
        key: ValueKey(
          'workspace_${(selection.provider ?? Provider.claude).value}_'
          '${selection.sessionId}',
        ),
        sessionId: selection.sessionId,
        provider: selection.provider ?? Provider.claude,
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
    final showDesktopPolish = isDesktopPlatform;
    final useMacOS = isMacOSPlatform;

    return ListenableBuilder(
      listenable:
          shell?.presentationListenable ?? const _PlaceholderNoopListenable(),
      builder: (context, _) {
        final sidebarScope = WorkspaceSidebarChromeScope.maybeOf(context);
        final showExpandSidebar =
            sidebarScope != null &&
            sidebarScope.showExpandSidebarButton &&
            sidebarScope.onExpandSidebar != null;
        final chrome = resolveWorkspacePaneChrome(
          platform: theme.platform,
          isAdaptiveWorkspace: shell != null && !shell.isSinglePane,
          isLeftPaneVisible: shell?.isLeftPaneVisible ?? false,
          slot: WorkspacePaneSlot.center,
        );

        return Scaffold(
          backgroundColor: theme.colorScheme.surfaceContainerLowest,
          body: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: showDesktopPolish ? 460 : 420,
                    ),
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
                            if (showDesktopPolish)
                              _DesktopLandingActions(
                                isConnected: isConnected,
                                useMacOS: useMacOS,
                                shell: shell,
                              )
                            else if (!isConnected)
                              OutlinedButton.icon(
                                key: const ValueKey(
                                  'workspace_setup_guide_button',
                                ),
                                onPressed:
                                    shell?.openSetupGuideCenter ??
                                    () =>
                                        context.router.push(SetupGuideRoute()),
                                icon: const Icon(Icons.lightbulb_outline),
                                label: Text('${l.setupGuide} →'),
                              ),
                            if (showDesktopPolish) ...[
                              const SizedBox(height: 24),
                              Divider(
                                height: 1,
                                color: theme.colorScheme.outlineVariant
                                    .withValues(alpha: 0.6),
                              ),
                              const SizedBox(height: 16),
                              _DesktopLandingShortcutHints(
                                isConnected: isConnected,
                                useMacOS: useMacOS,
                                onShowShortcuts: () {
                                  if (shell != null) {
                                    shell.handleDesktopMenuAction(
                                      DesktopMenuAction.showShortcuts,
                                    );
                                  } else {
                                    unawaited(
                                      KeyboardShortcutsDialog.show(context),
                                    );
                                  }
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (chrome.useMacOSAdaptiveChrome || showExpandSidebar)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: chrome.toolbarHeight,
                  child: _CollapsedSidebarLandingBar(
                    chrome: chrome,
                    showExpandSidebar: showExpandSidebar,
                    onExpandSidebar: sidebarScope?.onExpandSidebar,
                    tooltip: sidebarScope?.tooltip,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CollapsedSidebarLandingBar extends StatelessWidget {
  const _CollapsedSidebarLandingBar({
    required this.chrome,
    required this.showExpandSidebar,
    required this.onExpandSidebar,
    required this.tooltip,
  });

  final WorkspacePaneChrome chrome;
  final bool showExpandSidebar;
  final VoidCallback? onExpandSidebar;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final leadingPadding = chrome.ownsWindowControls
        ? kWorkspaceMacOSLeadingInset
        : kWorkspacePaneHorizontalPadding;
    return Row(
      children: [
        if (showExpandSidebar && onExpandSidebar != null)
          Padding(
            padding: EdgeInsets.only(left: leadingPadding),
            child: IconButton(
              key: const ValueKey('center_sidebar_toggle_button'),
              iconSize: chrome.useMacOSAdaptiveChrome ? 18 : 20,
              color: chrome.useMacOSAdaptiveChrome
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : null,
              style: chrome.useMacOSAdaptiveChrome
                  ? chrome.compactButtonStyle()
                  : null,
              onPressed: onExpandSidebar,
              tooltip: tooltip,
              icon: const Icon(Icons.view_sidebar_outlined),
            ),
          ),
        const Expanded(child: MacOSWindowDragHandle(child: SizedBox.expand())),
      ],
    );
  }
}

class _DesktopLandingActions extends StatelessWidget {
  const _DesktopLandingActions({
    required this.isConnected,
    required this.useMacOS,
    required this.shell,
  });

  final bool isConnected;
  final bool useMacOS;
  final WorkspaceShellScreenState? shell;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        if (isConnected)
          FilledButton.icon(
            key: const ValueKey('workspace_landing_new_session_button'),
            onPressed: shell?.canRequestNewSession == true
                ? shell!.requestNewSession
                : null,
            icon: const Icon(Icons.add, size: 18),
            label: Text(l.menuNewSession),
          ),
        if (!isConnected)
          OutlinedButton.icon(
            key: const ValueKey('workspace_setup_guide_button'),
            onPressed:
                shell?.openSetupGuideCenter ??
                () => context.router.push(SetupGuideRoute()),
            icon: const Icon(Icons.lightbulb_outline, size: 18),
            label: Text('${l.setupGuide} →'),
          ),
        OutlinedButton.icon(
          key: const ValueKey('workspace_landing_settings_button'),
          onPressed: () {
            if (shell != null) {
              shell!.openSettingsCenter(toggle: false);
            } else {
              context.router.push(SettingsRoute());
            }
          },
          icon: const Icon(Icons.settings_outlined, size: 18),
          label: Text(l.settings),
        ),
        if (useMacOS)
          OutlinedButton.icon(
            key: const ValueKey('workspace_landing_local_bridge_button'),
            onPressed: () {
              if (shell != null) {
                shell!.openSettingsCenter(
                  initialCategory: SettingsCategory.localBridge,
                  toggle: false,
                );
              } else {
                openLocalBridgeScreen(context);
              }
            },
            icon: const Icon(Icons.dns_outlined, size: 18),
            label: Text(l.settingsCategoryLocalBridge),
          ),
      ],
    );
  }
}

class _DesktopLandingShortcutHints extends StatelessWidget {
  const _DesktopLandingShortcutHints({
    required this.isConnected,
    required this.useMacOS,
    required this.onShowShortcuts,
  });

  final bool isConnected;
  final bool useMacOS;
  final VoidCallback onShowShortcuts;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mod = useMacOS ? '⌘' : 'Ctrl';
    final hints = [
      if (isConnected) (label: l.menuNewSession, keys: [mod, 'N']),
      if (isConnected) (label: l.menuQuickSearch, keys: [mod, 'K']),
      (label: l.settings, keys: [mod, ',']),
      (label: l.menuKeyboardShortcuts, keys: [mod, '/']),
    ];

    return Column(
      key: const ValueKey('workspace_landing_shortcut_hints'),
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final hint in hints)
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: hint.label == l.menuKeyboardShortcuts
                ? onShowShortcuts
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      hint.label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ShortcutKeyCaps(keys: hint.keys),
                ],
              ),
            ),
          ),
      ],
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
