import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/explore/explore_screen.dart';
import '../../features/explore/state/explore_state.dart';
import '../../features/git/git_screen.dart';
import '../../l10n/app_localizations.dart';
import '../../models/messages.dart';
import '../../providers/bridge_cubits.dart';
import '../../services/connection_url_parser.dart';
import '../../utils/diff_parser.dart';
import 'session_list_screen.dart';

const _twoPaneBreakpoint = 600.0;
const _threePaneBreakpoint = 1100.0;
const _twoPaneDividerWidth = 1.0;

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

class WorkspaceShellScreen extends StatefulWidget {
  final ValueNotifier<ConnectionParams?>? deepLinkNotifier;
  final List<RecentSession>? debugRecentSessions;
  final Widget content;
  final String? currentChildRouteName;

  const WorkspaceShellScreen({
    super.key,
    this.deepLinkNotifier,
    this.debugRecentSessions,
    required this.content,
    required this.currentChildRouteName,
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
  String? _activeChildRouteName;

  bool get canOpenToolPane => _layoutMode != _WorkspaceLayoutMode.single;
  bool get isSinglePane => _layoutMode == _WorkspaceLayoutMode.single;
  bool get isLeftPaneVisible => _showLeftPane;
  bool get shouldShowLeftPaneButton =>
      _layoutMode != _WorkspaceLayoutMode.single && !_showLeftPane;

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
    setState(() {
      _toolPane = pane;
      if (_layoutMode == _WorkspaceLayoutMode.doublePane) {
        _shouldRestoreLeftPaneOnToolClose = _showLeftPane;
        _showLeftPane = false;
      } else {
        _shouldRestoreLeftPaneOnToolClose = false;
      }
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
  }

  void resetWorkspace() {
    if (_toolPane == null && _showLeftPane) return;
    setState(() {
      _toolPane = null;
      _showLeftPane = true;
      _shouldRestoreLeftPaneOnToolClose = false;
    });
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

  void resetToPlaceholder() {
    resetWorkspace();
  }

  void _syncLayoutState(_WorkspaceLayoutMode nextMode, String? childRouteName) {
    final shouldCloseToolForRoute =
        _toolPane != null && !_isSessionRoute(childRouteName);

    if (nextMode == _layoutMode &&
        childRouteName == _activeChildRouteName &&
        !shouldCloseToolForRoute) {
      return;
    }

    _layoutMode = nextMode;
    _activeChildRouteName = childRouteName;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (shouldCloseToolForRoute) {
        closeToolPane();
        return;
      }
      if (nextMode == _WorkspaceLayoutMode.single) {
        if (_toolPane != null || !_showLeftPane) {
          setState(() {
            _toolPane = null;
            _showLeftPane = true;
            _shouldRestoreLeftPaneOnToolClose = false;
          });
        }
        return;
      }

      if (nextMode == _WorkspaceLayoutMode.triplePane &&
          _toolPane != null &&
          _shouldRestoreLeftPaneOnToolClose) {
        setState(() {
          _showLeftPane = true;
          _shouldRestoreLeftPaneOnToolClose = false;
        });
        return;
      }

      if (nextMode == _WorkspaceLayoutMode.doublePane &&
          _toolPane != null &&
          _showLeftPane) {
        setState(() {
          _shouldRestoreLeftPaneOnToolClose = true;
          _showLeftPane = false;
        });
      }
    });
  }

  bool _isSessionRoute(String? routeName) =>
      routeName == 'WorkspaceClaudeSessionRoute' ||
      routeName == 'WorkspaceCodexSessionRoute';

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
          _syncLayoutState(layoutMode, widget.currentChildRouteName);
          final sessionList = SessionListScreen(
            deepLinkNotifier: widget.deepLinkNotifier,
            debugRecentSessions: widget.debugRecentSessions,
            embedded: true,
            onTogglePaneVisibility: toggleLeftPaneVisibility,
          );

          final showLeftPane = _showLeftPane;
          final showRightPane = _toolPane != null;
          final leftWidth = _leftPaneWidth(constraints.maxWidth, layoutMode);
          final rightWidth = _rightPaneWidth(constraints.maxWidth, layoutMode);
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
            Expanded(child: widget.content),
            if (showRightPane)
              _WorkspacePaneDivider(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.18),
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

        return AutoRouter(
          builder: (routerContext, content) {
            final currentChildName = AutoRouter.of(
              routerContext,
              watch: true,
            ).currentChild?.name;

            if (isSinglePane) {
              return SessionListScreen(
                deepLinkNotifier: widget.deepLinkNotifier,
                debugRecentSessions: widget.debugRecentSessions,
              );
            }

            return WorkspaceShellScreen(
              deepLinkNotifier: widget.deepLinkNotifier,
              debugRecentSessions: widget.debugRecentSessions,
              content: content,
              currentChildRouteName: currentChildName,
            );
          },
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

@RoutePage()
class WorkspacePlaceholderScreen extends StatelessWidget {
  const WorkspacePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);

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
  }
}
