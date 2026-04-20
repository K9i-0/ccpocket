import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/claude_session/claude_session_screen.dart';
import '../../features/codex_session/codex_session_screen.dart';
import '../../features/explore/explore_screen.dart';
import '../../features/explore/state/explore_state.dart';
import '../../features/git/git_screen.dart';
import '../../l10n/app_localizations.dart';
import '../../models/messages.dart';
import '../../providers/bridge_cubits.dart';
import '../../services/connection_url_parser.dart';
import '../../services/notification_service.dart';
import '../../utils/diff_parser.dart';
import 'session_list_screen.dart';

const _twoPaneBreakpoint = 600.0;
const _threePaneBreakpoint = 1100.0;
const _twoPaneDividerWidth = 1.0;
const _paneResizeHandleWidth = _twoPaneDividerWidth;
const _minCenterPaneWidth = 360.0;
const _minRightPaneWidth = 320.0;

enum _WorkspaceLayoutMode { single, doublePane, triplePane }

double _leftPaneWidth(double width, _WorkspaceLayoutMode mode) {
  if (mode == _WorkspaceLayoutMode.triplePane) {
    return width >= 1280 ? 360 : 320;
  }
  if (width >= 1024) return 360;
  if (width >= 720) return 320;
  return 320;
}

double _rightPaneWidth(double width, _WorkspaceLayoutMode mode) {
  if (mode == _WorkspaceLayoutMode.triplePane) {
    return width >= 1360 ? 380 : 320;
  }
  return width >= 900 ? 360 : 320;
}

double _maxRightPaneWidth({
  required double totalWidth,
  required _WorkspaceLayoutMode mode,
  required bool showLeftPane,
}) {
  final leftWidth = showLeftPane ? _leftPaneWidth(totalWidth, mode) : 0.0;
  final dividerCount = (showLeftPane ? 1 : 0) + 1;
  final reservedWidth =
      leftWidth + (dividerCount * _paneResizeHandleWidth) + _minCenterPaneWidth;
  final availableWidth = totalWidth - reservedWidth;
  return availableWidth < _minRightPaneWidth ? availableWidth : availableWidth;
}

double _minAllowedRightPaneWidth(double maxWidth) {
  if (maxWidth <= 0) return 0;
  return maxWidth < _minRightPaneWidth ? maxWidth : _minRightPaneWidth;
}

_WorkspaceLayoutMode _layoutModeForWidth(double width) {
  if (width >= _threePaneBreakpoint) return _WorkspaceLayoutMode.triplePane;
  if (width >= _twoPaneBreakpoint) return _WorkspaceLayoutMode.doublePane;
  return _WorkspaceLayoutMode.single;
}

sealed class _WorkspaceToolPaneData {
  const _WorkspaceToolPaneData();

  String get id;
  String get title;
}

class _GitToolPaneData extends _WorkspaceToolPaneData {
  final String projectPath;
  final String? sessionId;
  final String? worktreePath;
  final ValueNotifier<DiffSelection?>? diffSelectionNotifier;

  const _GitToolPaneData({
    required this.projectPath,
    this.sessionId,
    this.worktreePath,
    this.diffSelectionNotifier,
  });

  @override
  String get id => 'git:$projectPath:${sessionId ?? ''}:${worktreePath ?? ''}';

  @override
  String get title => 'Git';
}

class _ExploreToolPaneData extends _WorkspaceToolPaneData {
  final String sessionId;
  final String projectPath;
  final List<String> initialFiles;
  final String initialPath;
  final List<String> recentPeekedFiles;
  final ValueChanged<ExploreScreenResult>? onResultChanged;

  const _ExploreToolPaneData({
    required this.sessionId,
    required this.projectPath,
    required this.initialFiles,
    required this.initialPath,
    required this.recentPeekedFiles,
    this.onResultChanged,
  });

  @override
  String get id => 'explore:$sessionId:$projectPath';

  @override
  String get title => 'Explorer';
}

class WorkspaceSessionSelection {
  final String sessionId;
  final String? projectPath;
  final String? gitBranch;
  final String? worktreePath;
  final bool isPending;
  final Provider? provider;
  final String? permissionMode;
  final String? sandboxMode;
  final String? approvalPolicy;
  final ValueNotifier<SystemMessage?>? pendingSessionCreated;

  const WorkspaceSessionSelection({
    required this.sessionId,
    this.projectPath,
    this.gitBranch,
    this.worktreePath,
    this.isPending = false,
    this.provider,
    this.permissionMode,
    this.sandboxMode,
    this.approvalPolicy,
    this.pendingSessionCreated,
  });
}

class WorkspaceShellScreen extends StatefulWidget {
  final ValueNotifier<ConnectionParams?>? deepLinkNotifier;
  final List<RecentSession>? debugRecentSessions;

  const WorkspaceShellScreen({
    super.key,
    this.deepLinkNotifier,
    this.debugRecentSessions,
  });

  static WorkspaceShellScreenState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<WorkspaceShellScreenState>();

  @override
  State<WorkspaceShellScreen> createState() => WorkspaceShellScreenState();
}

class WorkspaceShellScreenState extends State<WorkspaceShellScreen> {
  _WorkspaceToolPaneData? _toolPane;
  bool _showLeftPane = true;
  bool _shouldRestoreLeftPaneOnToolClose = false;
  _WorkspaceLayoutMode _layoutMode = _WorkspaceLayoutMode.single;
  WorkspaceSessionSelection? _selectedSession;
  double? _rightPaneUserWidth;
  final ValueNotifier<int> _presentationVersion = ValueNotifier<int>(0);

  bool get canOpenToolPane => _layoutMode != _WorkspaceLayoutMode.single;
  bool get isSinglePane => _layoutMode == _WorkspaceLayoutMode.single;
  bool get isLeftPaneVisible => _showLeftPane;
  bool get shouldShowLeftPaneButton =>
      _layoutMode != _WorkspaceLayoutMode.single && !_showLeftPane;
  ValueNotifier<int> get presentationListenable => _presentationVersion;

  void _notifyPresentationChanged() {
    _presentationVersion.value++;
  }

  bool isToolPaneOpen(String paneId) => _toolPane?.id == paneId;

  void openGitPane({
    required String projectPath,
    String? sessionId,
    String? worktreePath,
    ValueNotifier<DiffSelection?>? diffSelectionNotifier,
  }) {
    _openToolPane(
      _GitToolPaneData(
        projectPath: projectPath,
        sessionId: sessionId,
        worktreePath: worktreePath,
        diffSelectionNotifier: diffSelectionNotifier,
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
    _openToolPane(
      _ExploreToolPaneData(
        sessionId: sessionId,
        projectPath: projectPath,
        initialFiles: initialFiles,
        initialPath: initialPath,
        recentPeekedFiles: recentPeekedFiles,
        onResultChanged: onResultChanged,
      ),
    );
  }

  void _openToolPane(_WorkspaceToolPaneData pane) {
    if (_layoutMode == _WorkspaceLayoutMode.single) {
      return;
    }
    if (_toolPane?.id == pane.id) {
      closeToolPane();
      return;
    }
    setState(() {
      _toolPane = pane;
      if (_layoutMode == _WorkspaceLayoutMode.doublePane) {
        _shouldRestoreLeftPaneOnToolClose = _showLeftPane;
        _showLeftPane = false;
      } else {
        _shouldRestoreLeftPaneOnToolClose = false;
      }
    });
    _notifyPresentationChanged();
  }

  void resizeRightPane(double nextWidth, double totalWidth) {
    if (_toolPane == null) return;
    final maxWidth = _maxRightPaneWidth(
      totalWidth: totalWidth,
      mode: _layoutMode,
      showLeftPane: _showLeftPane,
    );
    final minWidth = _minAllowedRightPaneWidth(maxWidth);
    setState(() {
      _rightPaneUserWidth = nextWidth.clamp(minWidth, maxWidth).toDouble();
    });
  }

  void closeToolPane() {
    if (_toolPane == null) return;
    setState(() {
      _toolPane = null;
      if (_shouldRestoreLeftPaneOnToolClose) {
        _showLeftPane = true;
      }
      _shouldRestoreLeftPaneOnToolClose = false;
    });
    _notifyPresentationChanged();
  }

  void resetWorkspace() {
    final hadSelection = _selectedSession != null;
    if (_toolPane == null && _showLeftPane && !hadSelection) return;
    setState(() {
      _toolPane = null;
      _showLeftPane = true;
      _shouldRestoreLeftPaneOnToolClose = false;
      _selectedSession = null;
    });
    if (hadSelection) {
      NotificationService.instance.clearActiveSession();
    }
    _notifyPresentationChanged();
  }

  void toggleLeftPaneVisibility() {
    setState(() {
      if (_layoutMode == _WorkspaceLayoutMode.doublePane && _toolPane != null) {
        _toolPane = null;
        _showLeftPane = true;
        _shouldRestoreLeftPaneOnToolClose = false;
        return;
      }
      _showLeftPane = !_showLeftPane;
      _shouldRestoreLeftPaneOnToolClose = false;
    });
    _notifyPresentationChanged();
  }

  void _handleExploreResult(ExploreScreenResult result) {
    final pane = _toolPane;
    if (pane is! _ExploreToolPaneData) return;
    pane.onResultChanged?.call(result);
  }

  void _handleDiffSelection(DiffSelection selection) {
    final pane = _toolPane;
    if (pane is! _GitToolPaneData) return;
    pane.diffSelectionNotifier?.value = selection.isEmpty ? null : selection;
    closeToolPane();
  }

  void selectSession(WorkspaceSessionSelection selection) {
    setState(() {
      _selectedSession = selection;
      if (_layoutMode == _WorkspaceLayoutMode.doublePane && _toolPane != null) {
        _showLeftPane = false;
        _shouldRestoreLeftPaneOnToolClose = true;
      }
    });
    NotificationService.instance.setActiveSession(
      sessionId: selection.sessionId,
      provider: selection.provider == Provider.codex ? 'codex' : 'claude',
    );
    _notifyPresentationChanged();
  }

  void clearSelectedSession() {
    if (_selectedSession == null) return;
    setState(() {
      _selectedSession = null;
      _toolPane = null;
      _showLeftPane = true;
      _shouldRestoreLeftPaneOnToolClose = false;
    });
    NotificationService.instance.clearActiveSession();
    _notifyPresentationChanged();
  }

  void _syncLayoutState(_WorkspaceLayoutMode nextMode) {
    if (nextMode == _layoutMode) {
      return;
    }

    final previousMode = _layoutMode;
    _layoutMode = nextMode;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final crossedSinglePane =
          (previousMode == _WorkspaceLayoutMode.single) !=
          (nextMode == _WorkspaceLayoutMode.single);
      if (crossedSinglePane) {
        resetWorkspace();
        return;
      }
      if (nextMode == _WorkspaceLayoutMode.triplePane &&
          _toolPane != null &&
          _shouldRestoreLeftPaneOnToolClose) {
        setState(() {
          _showLeftPane = true;
          _shouldRestoreLeftPaneOnToolClose = false;
        });
        _notifyPresentationChanged();
        return;
      }

      if (nextMode == _WorkspaceLayoutMode.doublePane &&
          _toolPane != null &&
          _showLeftPane) {
        setState(() {
          _shouldRestoreLeftPaneOnToolClose = true;
          _showLeftPane = false;
        });
        _notifyPresentationChanged();
      }
    });
  }

  @override
  void dispose() {
    NotificationService.instance.clearActiveSession();
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
          final layoutMode = _layoutModeForWidth(constraints.maxWidth);
          _syncLayoutState(layoutMode);
          final sessionList = SessionListScreen(
            deepLinkNotifier: widget.deepLinkNotifier,
            debugRecentSessions: widget.debugRecentSessions,
            embedded: true,
            onTogglePaneVisibility: toggleLeftPaneVisibility,
            onSelectWorkspaceSession: selectSession,
          );

          final showLeftPane = _showLeftPane;
          final showRightPane = _toolPane != null;
          final leftWidth = _leftPaneWidth(constraints.maxWidth, layoutMode);
          final rightWidth = showRightPane
              ? (() {
                  final maxWidth = _maxRightPaneWidth(
                    totalWidth: constraints.maxWidth,
                    mode: layoutMode,
                    showLeftPane: showLeftPane,
                  );
                  final minWidth = _minAllowedRightPaneWidth(maxWidth);
                  return (_rightPaneUserWidth ??
                          _rightPaneWidth(constraints.maxWidth, layoutMode))
                      .clamp(minWidth, maxWidth)
                      .toDouble();
                })()
              : _rightPaneWidth(constraints.maxWidth, layoutMode);
          final children = <Widget>[
            if (showLeftPane)
              SizedBox(
                width: leftWidth,
                child: ColoredBox(
                  color: Theme.of(context).colorScheme.surface,
                  child: sessionList,
                ),
              ),
            if (showLeftPane)
              _WorkspacePaneDivider(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.18),
              ),
            Expanded(child: _WorkspaceContentHost(selection: _selectedSession)),
            if (showRightPane)
              _WorkspaceResizeDivider(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.18),
                onDragUpdate: (delta) =>
                    resizeRightPane(rightWidth - delta, constraints.maxWidth),
              ),
            if (showRightPane)
              SizedBox(
                width: rightWidth,
                child: _WorkspaceToolPaneHost(
                  pane: _toolPane!,
                  onClose: closeToolPane,
                  onExploreResultChanged: _handleExploreResult,
                  onDiffSelection: _handleDiffSelection,
                ),
              ),
          ];

          return Row(children: children);
        },
      ),
    );
  }
}

@RoutePage()
class AdaptiveHomeScreen extends StatefulWidget {
  final ValueNotifier<ConnectionParams?>? deepLinkNotifier;
  final List<RecentSession>? debugRecentSessions;

  const AdaptiveHomeScreen({
    super.key,
    this.deepLinkNotifier,
    this.debugRecentSessions,
  });

  @override
  State<AdaptiveHomeScreen> createState() => _AdaptiveHomeScreenState();
}

class _AdaptiveHomeScreenState extends State<AdaptiveHomeScreen> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSinglePane =
            _layoutModeForWidth(constraints.maxWidth) ==
            _WorkspaceLayoutMode.single;

        if (isSinglePane) {
          return SessionListScreen(
            deepLinkNotifier: widget.deepLinkNotifier,
            debugRecentSessions: widget.debugRecentSessions,
          );
        }

        return WorkspaceShellScreen(
          deepLinkNotifier: widget.deepLinkNotifier,
          debugRecentSessions: widget.debugRecentSessions,
        );
      },
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

class _WorkspaceResizeDivider extends StatelessWidget {
  final Color color;
  final ValueChanged<double> onDragUpdate;

  const _WorkspaceResizeDivider({
    required this.color,
    required this.onDragUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) => onDragUpdate(details.delta.dx),
        child: SizedBox(
          width: _paneResizeHandleWidth,
          child: Center(
            child: Container(width: _twoPaneDividerWidth, color: color),
          ),
        ),
      ),
    );
  }
}

class _WorkspaceToolPaneHost extends StatelessWidget {
  final _WorkspaceToolPaneData pane;
  final VoidCallback onClose;
  final ValueChanged<ExploreScreenResult> onExploreResultChanged;
  final ValueChanged<DiffSelection> onDiffSelection;

  const _WorkspaceToolPaneHost({
    required this.pane,
    required this.onClose,
    required this.onExploreResultChanged,
    required this.onDiffSelection,
  });

  @override
  Widget build(BuildContext context) {
    final child = switch (pane) {
      _GitToolPaneData(
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
        ),
      _ExploreToolPaneData(
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
    };

    return Material(color: Theme.of(context).colorScheme.surface, child: child);
  }
}

class _WorkspaceContentHost extends StatelessWidget {
  final WorkspaceSessionSelection? selection;

  const _WorkspaceContentHost({required this.selection});

  @override
  Widget build(BuildContext context) {
    final selection = this.selection;
    if (selection == null) {
      return const WorkspacePlaceholderScreen();
    }

    return switch (selection.provider) {
      Provider.codex => CodexSessionScreen(
        key: ValueKey('workspace_codex_${selection.sessionId}'),
        sessionId: selection.sessionId,
        projectPath: selection.projectPath,
        gitBranch: selection.gitBranch,
        worktreePath: selection.worktreePath,
        isPending: selection.isPending,
        initialSandboxMode: selection.sandboxMode,
        initialPermissionMode: selection.permissionMode,
        initialApprovalPolicy: selection.approvalPolicy,
        pendingSessionCreated: selection.pendingSessionCreated,
        onBackToSessions: WorkspaceShellScreen.maybeOf(
          context,
        )?.clearSelectedSession,
      ),
      _ => ClaudeSessionScreen(
        key: ValueKey('workspace_claude_${selection.sessionId}'),
        sessionId: selection.sessionId,
        projectPath: selection.projectPath,
        gitBranch: selection.gitBranch,
        worktreePath: selection.worktreePath,
        isPending: selection.isPending,
        initialPermissionMode: selection.permissionMode,
        initialSandboxMode: selection.sandboxMode,
        pendingSessionCreated: selection.pendingSessionCreated,
        onBackToSessions: WorkspaceShellScreen.maybeOf(
          context,
        )?.clearSelectedSession,
      ),
    };
  }
}

class WorkspacePlaceholderScreen extends StatelessWidget {
  const WorkspacePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final shell = WorkspaceShellScreen.maybeOf(context);

    return ListenableBuilder(
      listenable:
          shell?.presentationListenable ?? const _PlaceholderNoopListenable(),
      builder: (context, _) {
        final currentShell = WorkspaceShellScreen.maybeOf(context);
        final fabTheme = theme.floatingActionButtonTheme;

        return Scaffold(
          backgroundColor: theme.colorScheme.surfaceContainerLowest,
          appBar: currentShell?.shouldShowLeftPaneButton ?? false
              ? AppBar(
                  leadingWidth: 64,
                  leading: IconButton.filled(
                    key: const ValueKey('show_left_pane_button'),
                    onPressed: currentShell!.toggleLeftPaneVisibility,
                    tooltip: 'Show sessions',
                    style: IconButton.styleFrom(
                      backgroundColor:
                          fabTheme.backgroundColor ??
                          theme.colorScheme.primaryContainer,
                      foregroundColor:
                          fabTheme.foregroundColor ??
                          theme.colorScheme.onPrimaryContainer,
                    ),
                    icon: const Icon(Icons.chevron_right),
                  ),
                )
              : null,
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
                          'Select a session on the left, or start a new one.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
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
