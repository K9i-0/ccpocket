import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../constants/app_constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/messages.dart';
import '../../../models/offline_pending_action.dart';
import '../../../services/app_update_service.dart';
import '../../../services/draft_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/revenuecat_service.dart';
import '../../../services/support_banner_service.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/provider_style.dart';
import '../../../router/app_router.dart';
import '../../../utils/command_parser.dart';
import '../../../widgets/adaptive_context_menu.dart';
import '../../../widgets/session_card.dart';
import '../../../widgets/workspace_pane_chrome.dart';
import '../state/session_list_cubit.dart';
import '../state/session_list_state.dart';
import '../workspace_shell_screen.dart';
import 'section_header.dart';
import 'session_filter_bar.dart';
import 'session_list_empty_state.dart';
import 'app_update_banner.dart';
import 'bridge_update_banner.dart';
import 'macos_native_app_banner.dart';
import 'session_reconnect_banner.dart';
import 'support_banner.dart';

class _ProjectSessionGroup {
  final String projectPath;
  final String projectName;
  final List<RecentSession> sessions;

  const _ProjectSessionGroup({
    required this.projectPath,
    required this.projectName,
    required this.sessions,
  });
}

List<_ProjectSessionGroup> _groupRecentSessionsByProject(
  List<RecentSession> sessions,
) {
  final grouped = <String, List<RecentSession>>{};
  final orderedPaths = <String>[];
  for (final session in sessions) {
    if (!grouped.containsKey(session.projectPath)) {
      orderedPaths.add(session.projectPath);
    }
    grouped
        .putIfAbsent(session.projectPath, () => <RecentSession>[])
        .add(session);
  }
  return [
    for (final path in orderedPaths)
      _ProjectSessionGroup(
        projectPath: path,
        projectName: pathBasename(path),
        sessions: grouped[path]!,
      ),
  ];
}

String compactProjectPath(String path) {
  if (path.isEmpty) return path;
  final normalized = path.replaceAll('\\', '/');
  final parts = normalized.split('/').where((part) => part.isNotEmpty).toList();
  if (parts.length <= 2) return normalized;
  return '.../${parts.sublist(parts.length - 2).join('/')}';
}

class HomeContent extends StatefulWidget {
  final BridgeConnectionState connectionState;
  final String? bridgeVersion;
  final String? latestBridgeVersion;
  final List<SessionInfo> sessions;
  final List<OfflinePendingAction> offlinePendingActions;
  final List<RecentSession> recentSessions;
  final Set<String> accumulatedProjectPaths;
  final String searchQuery;
  final bool isLoadingMore;
  final bool isInitialLoading;
  final bool hasMoreSessions;
  final Set<String> archivingSessionIds;
  final Set<String> unseenSessionIds;
  final String? currentProjectFilter;
  final VoidCallback onNewSession;
  final void Function(
    String sessionId, {
    String? projectPath,
    String? gitBranch,
    String? worktreePath,
    String? provider,
    String? permissionMode,
    String? sandboxMode,
    String? approvalPolicy,
    String? approvalsReviewer,
  })
  onTapRunning;
  final ValueChanged<String> onStopSession;
  final ValueChanged<String>? onCancelOfflinePendingAction;
  final void Function(String sessionId, String toolUseId, {bool clearContext})?
  onApprovePermission;
  final void Function(String sessionId, String toolUseId)? onApproveAlways;
  final void Function(String sessionId, String toolUseId, {String? message})?
  onRejectPermission;
  final void Function(String sessionId, String toolUseId, String result)?
  onAnswerQuestion;
  final ValueChanged<RecentSession> onResumeSession;
  final void Function(RecentSession session, Offset? position)
  onLongPressRecentSession;
  final ValueChanged<RecentSession> onArchiveSession;
  final void Function(SessionInfo session, Offset? position)
  onLongPressRunningSession;
  final ValueChanged<String?> onSelectProject;
  final VoidCallback onLoadMore;
  final ProviderFilter providerFilter;
  final bool namedOnly;
  final VoidCallback onToggleProvider;
  final VoidCallback onToggleNamed;
  final AppUpdateInfo? appUpdateInfo;
  final VoidCallback? onDismissAppUpdate;
  final bool showMacOSNativeAppBanner;
  final VoidCallback? onDismissMacOSNativeAppBanner;
  final VoidCallback? onOpenMacOSNativeAppReleases;
  final VoidCallback? onOpenBridgeSettings;
  final VoidCallback? onOpenSupportSettings;
  final bool? showInlineStopButtonOverride;
  final String? connectedBridgeLabel;

  const HomeContent({
    super.key,
    required this.connectionState,
    this.bridgeVersion,
    this.latestBridgeVersion,
    required this.sessions,
    this.offlinePendingActions = const [],
    required this.recentSessions,
    required this.accumulatedProjectPaths,
    required this.searchQuery,
    required this.isLoadingMore,
    required this.isInitialLoading,
    required this.hasMoreSessions,
    this.archivingSessionIds = const {},
    this.unseenSessionIds = const {},
    required this.currentProjectFilter,
    required this.onNewSession,
    required this.onTapRunning,
    required this.onStopSession,
    this.onCancelOfflinePendingAction,
    this.onApprovePermission,
    this.onApproveAlways,
    this.onRejectPermission,
    this.onAnswerQuestion,
    required this.onResumeSession,
    required this.onLongPressRecentSession,
    required this.onArchiveSession,
    required this.onLongPressRunningSession,
    required this.onSelectProject,
    required this.onLoadMore,
    required this.providerFilter,
    required this.namedOnly,
    required this.onToggleProvider,
    required this.onToggleNamed,
    this.appUpdateInfo,
    this.onDismissAppUpdate,
    this.showMacOSNativeAppBanner = false,
    this.onDismissMacOSNativeAppBanner,
    this.onOpenMacOSNativeAppReleases,
    this.onOpenBridgeSettings,
    this.onOpenSupportSettings,
    this.showInlineStopButtonOverride,
    this.connectedBridgeLabel,
  });

  @override
  State<HomeContent> createState() => HomeContentState();
}

class HomeContentState extends State<HomeContent> {
  bool _isSearching = false;
  bool _updateBannerDismissed = false;
  bool _showSupportBanner = false;
  final _searchController = TextEditingController();
  final Set<String> _expandedProjectPaths = <String>{};
  final Set<String> _expandedRecentSessionIds = <String>{};
  SessionDisplayMode _displayMode = SessionDisplayMode.first;
  RevenueCatService? _revenueCatService;
  VoidCallback? _catalogStateListener;
  SupportBannerService? _supportBannerService;
  VoidCallback? _supportBannerListener;

  @override
  void initState() {
    super.initState();
    _loadDisplayMode();
  }

  Future<void> _loadDisplayMode() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString('session_list_display_mode');
    if (modeStr != null && mounted) {
      setState(() {
        _displayMode = SessionDisplayMode.values.firstWhere(
          (m) => m.name == modeStr,
          orElse: () => SessionDisplayMode.first,
        );
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final revenueCatService = context.read<RevenueCatService>();
    if (!identical(_revenueCatService, revenueCatService)) {
      if (_revenueCatService != null && _catalogStateListener != null) {
        _revenueCatService!.catalogState.removeListener(_catalogStateListener!);
      }
      _revenueCatService = revenueCatService;
      _catalogStateListener = () => _refreshSupportBannerVisibility();
      revenueCatService.catalogState.addListener(_catalogStateListener!);
      _refreshSupportBannerVisibility();
    }

    final supportBannerService = context.read<SupportBannerService>();
    if (!identical(_supportBannerService, supportBannerService)) {
      if (_supportBannerService != null && _supportBannerListener != null) {
        _supportBannerService!.removeListener(_supportBannerListener!);
      }
      _supportBannerService = supportBannerService;
      _supportBannerListener = () => _refreshSupportBannerVisibility();
      supportBannerService.addListener(_supportBannerListener!);
      _refreshSupportBannerVisibility();
    }
  }

  void _toggleDisplayMode() async {
    final next = switch (_displayMode) {
      SessionDisplayMode.first => SessionDisplayMode.last,
      SessionDisplayMode.last => SessionDisplayMode.summary,
      SessionDisplayMode.summary => SessionDisplayMode.first,
    };
    setState(() => _displayMode = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_list_display_mode', next.name);
  }

  void _toggleProjectGroup(String projectPath) {
    setState(() {
      if (_expandedProjectPaths.contains(projectPath)) {
        _expandedProjectPaths.remove(projectPath);
      } else {
        _expandedProjectPaths.add(projectPath);
      }
    });
  }

  void _toggleRecentSessionDetails(String sessionId) {
    setState(() {
      if (_expandedRecentSessionIds.contains(sessionId)) {
        _expandedRecentSessionIds.remove(sessionId);
      } else {
        _expandedRecentSessionIds.add(sessionId);
      }
    });
  }

  @override
  void didUpdateWidget(covariant HomeContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外部から searchQuery がクリアされたら検索UIも閉じる
    if (widget.searchQuery.isEmpty && oldWidget.searchQuery.isNotEmpty) {
      setState(() => _isSearching = false);
      _searchController.clear();
    }
    // Reset dismiss state when reconnected (new bridgeVersion received)
    if (widget.bridgeVersion != oldWidget.bridgeVersion) {
      _updateBannerDismissed = false;
      _refreshSupportBannerVisibility();
    }
  }

  @override
  void dispose() {
    if (_revenueCatService != null && _catalogStateListener != null) {
      _revenueCatService!.catalogState.removeListener(_catalogStateListener!);
    }
    if (_supportBannerService != null && _supportBannerListener != null) {
      _supportBannerService!.removeListener(_supportBannerListener!);
    }
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        context.read<SessionListCubit>().setSearchQuery('');
      }
    });
  }

  /// Open search field programmatically (e.g. from keyboard shortcut).
  void openSearch() {
    if (!_isSearching) {
      _toggleSearch();
    }
  }

  Widget? _buildAppUpdateBanner() {
    if (widget.appUpdateInfo == null) return null;
    return AppUpdateBanner(
      updateInfo: widget.appUpdateInfo!,
      onDismiss: widget.onDismissAppUpdate,
    );
  }

  Widget? _buildMacOSNativeAppBanner() {
    if (!widget.showMacOSNativeAppBanner) return null;
    return MacOSNativeAppBanner(
      onDismiss: widget.onDismissMacOSNativeAppBanner,
      onOpen: widget.onOpenMacOSNativeAppReleases,
    );
  }

  Widget? _buildUpdateBanner() {
    if (_updateBannerDismissed) return null;
    if (!BridgeUpdateBanner.shouldShow(
      widget.bridgeVersion,
      AppConstants.expectedBridgeVersion,
      latestBridgeVersion: widget.latestBridgeVersion,
    )) {
      return null;
    }
    return BridgeUpdateBanner(
      currentVersion: widget.bridgeVersion!,
      expectedVersion: AppConstants.expectedBridgeVersion,
      latestBridgeVersion: widget.latestBridgeVersion,
      onTap:
          widget.onOpenBridgeSettings ??
          () => context.pushRoute(SettingsRoute(focusConnection: true)),
      onDismiss: () => setState(() => _updateBannerDismissed = true),
    );
  }

  bool _hasVisibleBridgeUpdateBanner() {
    return !_updateBannerDismissed &&
        BridgeUpdateBanner.shouldShow(
          widget.bridgeVersion,
          AppConstants.expectedBridgeVersion,
          latestBridgeVersion: widget.latestBridgeVersion,
        );
  }

  Future<void> _refreshSupportBannerVisibility() async {
    final revenueCatService = _revenueCatService;
    if (revenueCatService == null) return;

    final supportBannerService = context.read<SupportBannerService>();
    final shouldShow = await supportBannerService.shouldShow(
      hasBridgeUpdate: _hasVisibleBridgeUpdateBanner(),
      catalog: revenueCatService.catalogState.value,
    );
    if (!mounted || shouldShow == _showSupportBanner) return;
    setState(() {
      _showSupportBanner = shouldShow;
    });
  }

  Widget? _buildSupportBanner() {
    if (!_showSupportBanner) return null;
    return SupportBanner(
      onTap:
          widget.onOpenSupportSettings ??
          () => context.pushRoute(SettingsRoute(focusSupport: true)),
      onDismiss: () async {
        await context.read<SupportBannerService>().dismiss();
        if (!mounted) return;
        setState(() {
          _showSupportBanner = false;
        });
      },
    );
  }

  Widget? _buildConnectedBridgeBanner(BuildContext context) {
    final label = widget.connectedBridgeLabel;
    if (label == null || label.isEmpty) return null;
    if (WorkspaceShellScreen.maybeOf(context) == null) return null;
    final chrome = resolveWorkspacePaneChrome(
      platform: Theme.of(context).platform,
      isAdaptiveWorkspace: true,
      isLeftPaneVisible: true,
      slot: WorkspacePaneSlot.left,
    );
    if (!chrome.useMacOSAdaptiveChrome) return null;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.dns_outlined,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shell = WorkspaceShellScreen.maybeOf(context);
    return ListenableBuilder(
      listenable: Listenable.merge([
        NotificationService.instance,
        if (shell != null) shell.presentationListenable,
      ]),
      builder: (context, _) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final l = AppLocalizations.of(context);
    final appColors = Theme.of(context).extension<AppColors>()!;
    final hasPendingActions = widget.offlinePendingActions.isNotEmpty;
    final hasRunningSessions = widget.sessions.isNotEmpty || hasPendingActions;
    final hasRecentSessions = widget.recentSessions.isNotEmpty;
    final isReconnecting =
        widget.connectionState == BridgeConnectionState.reconnecting;
    final updateBanner = _buildUpdateBanner();
    final supportBannerService = context.read<SupportBannerService>();
    final supportBanner =
        updateBanner == null || supportBannerService.shouldForceShowInDebug
        ? _buildSupportBanner()
        : null;
    final appUpdateBanner = _buildAppUpdateBanner();
    final macOSNativeAppBanner = _buildMacOSNativeAppBanner();
    final shell = WorkspaceShellScreen.maybeOf(context);
    final selectedSession = shell?.selectedSession;
    final selectedSessionId = selectedSession?.sessionId;
    final selectedSessionProvider = selectedSession?.provider?.value;
    final showInlineStopButton =
        widget.showInlineStopButtonOverride ?? shell != null;
    final connectedBridgeBanner = _buildConnectedBridgeBanner(context);

    // Compute derived state
    // Exclude running sessions from recent list to avoid duplicates
    final runningSessionIds = widget.sessions
        .expand(
          (s) => [s.id, if (s.claudeSessionId != null) s.claudeSessionId!],
        )
        .toSet();
    final pendingResumeSessionIds = widget.offlinePendingActions
        .where((action) => action.kind == OfflinePendingActionKind.resume)
        .map((action) => action.sessionId)
        .whereType<String>()
        .toSet();

    // Fallback for Codex sessions which use a short proxy ID instead of UUID
    bool isDuplicate(RecentSession rs) {
      if (pendingResumeSessionIds.contains(rs.sessionId)) return true;
      if (runningSessionIds.contains(rs.sessionId)) return true;
      for (final s in widget.sessions) {
        if (s.provider == rs.provider &&
            s.projectPath == rs.projectPath &&
            s.createdAt == rs.created) {
          return true;
        }
      }
      return false;
    }

    // All filtering (project, provider, namedOnly, searchQuery) is applied
    // server-side. Only deduplicate running sessions here.
    final filteredSessions = widget.recentSessions
        .where((s) => !isDuplicate(s))
        .toList();
    final groupedRecentSessions = _groupRecentSessionsByProject(
      filteredSessions,
    );

    final hasActiveFilter =
        widget.currentProjectFilter != null ||
        widget.providerFilter != ProviderFilter.all ||
        widget.namedOnly ||
        widget.searchQuery.isNotEmpty;

    if (!hasRunningSessions && !hasRecentSessions && !hasActiveFilter) {
      // Show skeleton while initial data is loading
      if (widget.isInitialLoading) {
        return ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          children: [
            if (isReconnecting) const SessionReconnectBanner(),
            ?connectedBridgeBanner,
            ?updateBanner,
            ?supportBanner,
            ?appUpdateBanner,
            ?macOSNativeAppBanner,
            SectionHeader(
              icon: Icons.history,
              label: l.recentSessions,
              color: appColors.subtleText,
            ),
            const SizedBox(height: 8),
            const _SessionListSkeleton(),
          ],
        );
      }

      return ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (isReconnecting) const SessionReconnectBanner(),
          ?connectedBridgeBanner,
          ?updateBanner,
          ?supportBanner,
          ?macOSNativeAppBanner,
          const SizedBox(height: 80),
          SessionListEmptyState(onNewSession: widget.onNewSession),
        ],
      );
    }

    return ListView(
      key: const ValueKey('session_list'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      children: [
        if (isReconnecting) const SessionReconnectBanner(),
        ?connectedBridgeBanner,
        ?updateBanner,
        ?supportBanner,
        ?macOSNativeAppBanner,
        if (hasRunningSessions) ...[
          SectionHeader(
            icon: Icons.play_circle_filled,
            label: l.running,
            color: appColors.statusOnline,
          ),
          const SizedBox(height: 4),
          for (final action in widget.offlinePendingActions)
            OfflinePendingSessionCard(
              key: ValueKey('pending_session_${action.id}'),
              action: action,
              onCancel:
                  widget.onCancelOfflinePendingAction == null ||
                      !action.canCancel
                  ? null
                  : () => widget.onCancelOfflinePendingAction!(action.id),
            ),
          for (final session in widget.sessions)
            Slidable(
              key: ValueKey('running_session_${session.id}'),
              endActionPane: ActionPane(
                motion: const BehindMotion(),
                extentRatio: 0.18,
                children: [
                  CustomSlidableAction(
                    onPressed: (_) => widget.onStopSession(session.id),
                    backgroundColor: Colors.transparent,
                    padding: EdgeInsets.zero,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.stop_circle_outlined,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
              child: RunningSessionCard(
                session: session,
                isUnseen: widget.unseenSessionIds.contains(session.id),
                isSelected:
                    selectedSessionId == session.id &&
                    selectedSessionProvider == session.provider,
                onLongPress: () =>
                    widget.onLongPressRunningSession(session, null),
                onShowActions: (position) =>
                    widget.onLongPressRunningSession(session, position),
                onStop: showInlineStopButton
                    ? () => widget.onStopSession(session.id)
                    : null,
                onTap: () => widget.onTapRunning(
                  session.id,
                  projectPath: session.projectPath,
                  gitBranch: session.worktreePath != null
                      ? session.worktreeBranch
                      : session.gitBranch,
                  worktreePath: session.worktreePath,
                  provider: session.provider,
                  permissionMode: session.permissionMode,
                  sandboxMode: session.codexSandboxMode,
                  approvalPolicy: session.codexApprovalPolicy,
                  approvalsReviewer: session.codexApprovalsReviewer,
                ),
                onApprove: (toolUseId, {bool clearContext = false}) => widget
                    .onApprovePermission
                    ?.call(session.id, toolUseId, clearContext: clearContext),
                onApproveAlways: (toolUseId) =>
                    widget.onApproveAlways?.call(session.id, toolUseId),
                onReject: (toolUseId, {String? message}) => widget
                    .onRejectPermission
                    ?.call(session.id, toolUseId, message: message),
                onAnswer: (toolUseId, result) => widget.onAnswerQuestion?.call(
                  session.id,
                  toolUseId,
                  result,
                ),
              ),
            ),
          const SizedBox(height: 16),
        ],
        if (widget.isInitialLoading ||
            hasRecentSessions ||
            hasActiveFilter) ...[
          SectionHeader(
            icon: Icons.history,
            label: l.recentSessions,
            color: appColors.subtleText,
            trailing: IconButton(
              key: const ValueKey('search_button'),
              icon: Icon(
                _isSearching ? Icons.close : Icons.search,
                size: 18,
                color: appColors.subtleText,
              ),
              onPressed: _toggleSearch,
              tooltip: l.search,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              visualDensity: VisualDensity.compact,
            ),
          ),
          if (_isSearching) ...[
            const SizedBox(height: 4),
            TextField(
              key: const ValueKey('search_field'),
              controller: _searchController,
              autofocus: true,
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              decoration: InputDecoration(
                hintText: l.searchSessions,
                prefixIcon: Icon(
                  Icons.search,
                  size: 18,
                  color: appColors.subtleText,
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: appColors.subtleText.withValues(alpha: 0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: appColors.subtleText.withValues(alpha: 0.3),
                  ),
                ),
              ),
              style: const TextStyle(fontSize: 14),
              onChanged: (v) =>
                  context.read<SessionListCubit>().setSearchQuery(v),
            ),
          ],
          const SizedBox(height: 8),
          SessionFilterBar(
            displayMode: _displayMode,
            onToggleDisplayMode: _toggleDisplayMode,
            providerFilter: widget.providerFilter,
            onToggleProviderFilter: widget.onToggleProvider,
            projects: widget.accumulatedProjectPaths.map((path) {
              return (path: path, name: pathBasename(path));
            }).toList(),
            currentProjectFilter: widget.currentProjectFilter,
            onProjectFilterChanged: widget.onSelectProject,
            namedOnly: widget.namedOnly,
            onToggleNamed: widget.onToggleNamed,
          ),
          const SizedBox(height: 8),
          if (widget.isInitialLoading)
            const _SessionListSkeleton()
          else ...[
            if (filteredSessions.isEmpty)
              _RecentSessionsEmptyResult(
                title: hasActiveFilter
                    ? l.noSessionsMatchFilters
                    : l.noRecentSessions,
                subtitle: hasActiveFilter ? l.adjustFiltersAndSearch : null,
              )
            else
              for (final group in groupedRecentSessions) ...[
                Builder(
                  builder: (context) {
                    final isExpanded = _expandedProjectPaths.contains(
                      group.projectPath,
                    );
                    final visibleCount = isExpanded ? group.sessions.length : 0;
                    final visibleSessions = group.sessions.take(visibleCount);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ProjectGroupHeader(
                          projectName: group.projectName,
                          projectPath: group.projectPath,
                          sessionCount: group.sessions.length,
                          isExpanded: isExpanded,
                          onTap: () => _toggleProjectGroup(group.projectPath),
                        ),
                        for (final session in visibleSessions)
                          Column(
                            children: [
                              Slidable(
                                key: ValueKey(
                                  'recent_session_${session.sessionId}',
                                ),
                                endActionPane: ActionPane(
                                  motion: const BehindMotion(),
                                  extentRatio: 0.18,
                                  children: [
                                    CustomSlidableAction(
                                      onPressed: (_) =>
                                          widget.onArchiveSession(session),
                                      backgroundColor: Colors.transparent,
                                      padding: EdgeInsets.zero,
                                      child: Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.archive_outlined,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                child: _RecentSessionListRow(
                                  session: session,
                                  displayMode: _displayMode,
                                  draftText: context
                                      .read<DraftService>()
                                      .getDraft(session.sessionId),
                                  isProcessing: widget.archivingSessionIds
                                      .contains(session.sessionId),
                                  isDetailExpanded: _expandedRecentSessionIds
                                      .contains(session.sessionId),
                                  onTap: () => widget.onResumeSession(session),
                                  onLongPress: () => widget
                                      .onLongPressRecentSession(session, null),
                                  onShowActions: (position) =>
                                      widget.onLongPressRecentSession(
                                        session,
                                        position,
                                      ),
                                  onToggleDetails: () =>
                                      _toggleRecentSessionDetails(
                                        session.sessionId,
                                      ),
                                ),
                              ),
                              if (_expandedRecentSessionIds.contains(
                                session.sessionId,
                              ))
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 20,
                                    bottom: 8,
                                  ),
                                  child: RecentSessionCard(
                                    session: session,
                                    displayMode: _displayMode,
                                    hideProjectBadge: true,
                                    isSelected: false,
                                    draftText: context
                                        .read<DraftService>()
                                        .getDraft(session.sessionId),
                                    isProcessing: widget.archivingSessionIds
                                        .contains(session.sessionId),
                                    onTap: () =>
                                        widget.onResumeSession(session),
                                    onLongPress: () =>
                                        widget.onLongPressRecentSession(
                                          session,
                                          null,
                                        ),
                                    onShowActions: (position) =>
                                        widget.onLongPressRecentSession(
                                          session,
                                          position,
                                        ),
                                  ),
                                ),
                            ],
                          ),
                      ],
                    );
                  },
                ),
              ],
            if (widget.hasMoreSessions) ...[
              const SizedBox(height: 8),
              Center(
                child: widget.isLoadingMore
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : TextButton.icon(
                        key: const ValueKey('load_more_button'),
                        onPressed: widget.onLoadMore,
                        icon: const Icon(Icons.expand_more, size: 18),
                        label: const Text('Load More'),
                      ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ],
    );
  }
}

class _RecentSessionsEmptyResult extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _RecentSessionsEmptyResult({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            Icon(Icons.filter_alt_off, color: appColors.subtleText),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color: appColors.subtleText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectGroupHeader extends StatelessWidget {
  final String projectName;
  final String projectPath;
  final int sessionCount;
  final bool isExpanded;
  final VoidCallback onTap;

  const _ProjectGroupHeader({
    required this.projectName,
    required this.projectPath,
    required this.sessionCount,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: isExpanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.folder_outlined,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        projectName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        compactProjectPath(projectPath),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$sessionCount',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentSessionListRow extends StatelessWidget {
  final RecentSession session;
  final SessionDisplayMode displayMode;
  final String? draftText;
  final bool isProcessing;
  final bool isDetailExpanded;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<Offset?>? onShowActions;
  final VoidCallback onToggleDetails;

  const _RecentSessionListRow({
    required this.session,
    required this.displayMode,
    required this.draftText,
    required this.isProcessing,
    required this.isDetailExpanded,
    required this.onTap,
    this.onLongPress,
    this.onShowActions,
    required this.onToggleDetails,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final previewText = draftText != null && draftText!.trim().isNotEmpty
        ? draftText!.trim()
        : _displayTextForMode(session, displayMode);
    final hasSeparateTitle =
        session.name != null &&
        session.name!.trim().isNotEmpty &&
        session.name!.trim() != previewText.trim();
    final title = hasSeparateTitle ? session.name!.trim() : previewText;
    final subtitle = hasSeparateTitle ? previewText : null;

    final content = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: isProcessing ? null : onTap,
        onLongPress: isProcessing || onShowActions != null ? null : onLongPress,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatCompactDate(session.modified, session.created),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: onToggleDetails,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: AnimatedRotation(
                            turns: isDetailExpanded ? 0.25 : 0,
                            duration: const Duration(milliseconds: 180),
                            child: Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isProcessing)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.55),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (isProcessing || onShowActions == null) return content;
    return AdaptiveContextMenuRegion(onOpen: onShowActions!, child: content);
  }
}

String _displayTextForMode(RecentSession session, SessionDisplayMode mode) {
  final String raw;
  switch (mode) {
    case SessionDisplayMode.first:
      raw = session.firstPrompt.isNotEmpty
          ? session.firstPrompt
          : session.displayText;
    case SessionDisplayMode.last:
      final text = session.lastPrompt ?? session.firstPrompt;
      raw = text.isNotEmpty ? text : '(no description)';
    case SessionDisplayMode.summary:
      final text = session.summary ?? session.firstPrompt;
      raw = text.isNotEmpty ? text : '(no description)';
  }
  return formatCommandText(raw);
}

String _formatCompactDate(String modifiedIso, String createdIso) {
  final iso = modifiedIso.isNotEmpty ? modifiedIso : createdIso;
  if (iso.isEmpty) return '';
  try {
    final dt = DateTime.parse(iso).toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dtDate = DateTime(dt.year, dt.month, dt.day);
    final days = today.difference(dtDate).inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (days < 7) return '$days d ago';
    if (days < 30) return '${(days / 7).floor()} w ago';
    if (days < 365) return '${(days / 30).floor()} mo ago';
    return '${dt.year}/${dt.month}/${dt.day}';
  } catch (_) {
    return '';
  }
}

class OfflinePendingSessionCard extends StatelessWidget {
  const OfflinePendingSessionCard({
    super.key,
    required this.action,
    this.onCancel,
  });

  final OfflinePendingAction action;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppColors>()!;
    final l = AppLocalizations.of(context);
    final provider = providerFromRaw(action.provider);
    final providerStyle = providerStyleFor(context, provider);
    final statusColor = colorScheme.tertiary;
    final subtitle = switch (action.kind) {
      OfflinePendingActionKind.start => l.pendingActionWillCreateOnReconnect,
      OfflinePendingActionKind.resume => l.pendingActionWillResumeOnReconnect,
    };
    final title = switch (action.kind) {
      OfflinePendingActionKind.start => l.offlinePendingNewSessionTitle,
      OfflinePendingActionKind.resume => l.offlinePendingResumeTitle,
    };

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 0),
      elevation: 0,
      color: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: statusColor.withValues(alpha: 0.5), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: statusColor.withValues(alpha: 0.08),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  l.pendingActionStatus,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: statusColor.withValues(alpha: 0.82),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onCancel != null)
                  IconButton(
                    key: const ValueKey('pending_session_cancel_button'),
                    onPressed: onCancel,
                    tooltip: l.tooltipCancelPendingAction,
                    icon: const Icon(Icons.close),
                    iconSize: 18,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 28,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: providerStyle.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: providerStyle.border,
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        action.projectName,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                          color: providerStyle.foreground,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.cloud_off,
                      size: 13,
                      color: appColors.subtleText,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        l.queuedLocally,
                        style: TextStyle(
                          fontSize: 11,
                          color: appColors.subtleText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton placeholder that mimics a list of [RecentSessionCard] widgets.
///
/// Uses [Skeletonizer] to render dummy cards with a shimmer animation,
/// providing visual feedback while the initial session list is loading.
class _SessionListSkeleton extends StatelessWidget {
  const _SessionListSkeleton();

  static const _dummySessions = [
    RecentSession(
      sessionId: 'skeleton-1',
      firstPrompt: 'Implement the new feature for user authentication flow',
      created: '2025-01-01T00:00:00Z',
      modified: '2025-01-01T01:00:00Z',
      gitBranch: 'feat/auth',
      projectPath: '/projects/my-app',
      isSidechain: false,
    ),
    RecentSession(
      sessionId: 'skeleton-2',
      firstPrompt: 'Fix the CI pipeline build failure on main branch',
      created: '2025-01-01T00:00:00Z',
      modified: '2025-01-01T01:00:00Z',
      gitBranch: 'fix/ci',
      projectPath: '/projects/backend',
      isSidechain: false,
    ),
    RecentSession(
      sessionId: 'skeleton-3',
      firstPrompt: 'Add dark mode support to the settings page',
      created: '2025-01-01T00:00:00Z',
      modified: '2025-01-01T01:00:00Z',
      gitBranch: 'main',
      projectPath: '/projects/mobile',
      isSidechain: false,
    ),
    RecentSession(
      sessionId: 'skeleton-4',
      firstPrompt: 'Refactor database queries for better performance',
      created: '2025-01-01T00:00:00Z',
      modified: '2025-01-01T01:00:00Z',
      gitBranch: 'perf/db',
      projectPath: '/projects/api',
      isSidechain: false,
    ),
    RecentSession(
      sessionId: 'skeleton-5',
      firstPrompt: 'Update documentation for the REST API endpoints',
      created: '2025-01-01T00:00:00Z',
      modified: '2025-01-01T01:00:00Z',
      gitBranch: 'docs',
      projectPath: '/projects/docs',
      isSidechain: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      child: Column(
        children: [
          for (final session in _dummySessions)
            RecentSessionCard(session: session, onTap: () {}),
        ],
      ),
    );
  }
}
