import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../constants/app_constants.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/messages.dart';
import '../../../models/offline_pending_action.dart';
import '../../../services/app_update_service.dart';
import '../../../services/bridge_service.dart';
import '../../../services/draft_service.dart';
import '../../../services/notification_service.dart';
import '../../../services/revenuecat_service.dart';
import '../../../services/support_banner_service.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/provider_style.dart';
import '../../../router/app_router.dart';
import '../../../widgets/pin_toggle_button.dart';
import '../../../widgets/session_card.dart';
import '../../../widgets/workspace_pane_chrome.dart';

import 'package:intl/intl.dart';

import '../state/recent_session_filters.dart';
import '../state/session_list_cubit.dart';
import '../state/session_list_state.dart';
import '../workspace_shell_screen.dart';
import '../../settings/state/settings_state.dart';
import 'usage_summary.dart';
import 'section_header.dart';
import 'recent_session_filter_sheets.dart';
import 'session_filter_bar.dart';
import 'session_list_empty_state.dart';
import 'session_list_loading_view.dart';
import 'app_update_banner.dart';
import 'bridge_update_banner.dart';
import 'macos_native_app_banner.dart';
import 'session_reconnect_banner.dart';
import 'support_banner.dart';

class _ProjectSessionGroup {
  final String groupKey;
  final String projectPath;
  final String projectName;
  final String workspaceKind;
  final List<RecentSession> sessions;

  const _ProjectSessionGroup({
    required this.groupKey,
    required this.projectPath,
    required this.projectName,
    required this.workspaceKind,
    required this.sessions,
  });
}

List<_ProjectSessionGroup> _groupSessionsByProject({
  required Iterable<String> projectPaths,
  required List<RecentSession> sessions,
  required Map<String, String> currentProjectNames,
  Set<String> keepEmpty = const {},
}) {
  final grouped = <String, List<RecentSession>>{
    for (final path in projectPaths)
      if (path.isNotEmpty) path: <RecentSession>[],
  };
  for (final session in sessions) {
    grouped.putIfAbsent(session.workspaceGroupKey, () => <RecentSession>[]);
    grouped[session.workspaceGroupKey]!.add(session);
  }
  return [
    for (final entry in grouped.entries)
      if (entry.value.isNotEmpty ||
          !entry.key.contains(':') ||
          keepEmpty.contains(entry.key))
        _ProjectSessionGroup(
          groupKey: entry.key,
          projectPath: entry.value.firstOrNull?.projectPath ?? entry.key,
          projectName:
              currentProjectNames[entry.key] ??
              entry.value.firstOrNull?.projectName ??
              pathBasename(entry.key),
          workspaceKind: entry.value.firstOrNull?.workspaceKind ?? 'unassigned',
          sessions: entry.value,
        ),
  ];
}

class HomeContent extends StatefulWidget {
  final BridgeConnectionState connectionState;
  final String? bridgeVersion;
  final String? latestBridgeVersion;
  final List<SessionInfo> sessions;
  final List<OfflinePendingAction> offlinePendingActions;
  final List<RecentSession> recentSessions;
  final List<WorkspaceProject> workspaceProjects;
  final Set<String> accumulatedProjectPaths;
  final Set<String> collapsedProjectPaths;
  final Set<String> loadingProjectPaths;
  final Set<String> exhaustedProjectPaths;
  final Map<String, int> projectSessionDisplayLimits;
  final Set<String> pinnedSessionKeys;
  final Set<String> pinnedProjectPaths;
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
    SessionWorkspaceInfo? workspace,
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
  final ValueChanged<RecentSession>? onToggleRecentSessionPinned;
  final void Function(RecentSession session, Offset? position)
  onLongPressRecentSession;
  final ValueChanged<RecentSession> onArchiveSession;
  final void Function(SessionInfo session, Offset? position)
  onLongPressRunningSession;
  final ValueChanged<SessionInfo>? onToggleRunningSessionPinned;
  final ValueChanged<String?> onSelectProject;
  final VoidCallback onLoadMore;
  final ValueChanged<String>? onLoadMoreProject;
  final ValueChanged<String>? onToggleProjectCollapsed;
  final ValueChanged<String>? onToggleProjectPinned;
  final ProviderFilter providerFilter;
  final bool namedOnly;

  /// Projects, period, pinned only and content search.
  final RecentSessionFilters filters;

  /// Whether the Bridge supports `recent_sessions_filters_v1`.
  final bool supportsAdvancedFilters;

  /// AI tool options allowed by the enabled agents.
  final List<ProviderFilter> providerFilterOptions;
  final VoidCallback onToggleProvider;
  final VoidCallback onToggleNamed;
  final AppUpdateInfo? appUpdateInfo;
  final VoidCallback? onDismissAppUpdate;
  final bool showMacOSNativeAppBanner;
  final VoidCallback? onDismissMacOSNativeAppBanner;
  final VoidCallback? onOpenMacOSNativeAppReleases;
  final VoidCallback? onOpenBridgeSettings;
  final VoidCallback? onOpenSupportSettings;
  final VoidCallback? onOpenUsageSettings;
  final bool? showInlineStopButtonOverride;
  final String? connectedBridgeLabel;
  final BridgeService? usageBridgeService;
  final List<UsageInfo>? usageOverride;
  final UsageDisplayMode usageDisplayMode;

  const HomeContent({
    super.key,
    required this.connectionState,
    this.bridgeVersion,
    this.latestBridgeVersion,
    required this.sessions,
    this.offlinePendingActions = const [],
    required this.recentSessions,
    this.workspaceProjects = const [],
    required this.accumulatedProjectPaths,
    this.collapsedProjectPaths = const {},
    this.loadingProjectPaths = const {},
    this.exhaustedProjectPaths = const {},
    this.projectSessionDisplayLimits = const {},
    this.pinnedSessionKeys = const {},
    this.pinnedProjectPaths = const {},
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
    this.onToggleRecentSessionPinned,
    required this.onLongPressRecentSession,
    required this.onArchiveSession,
    required this.onLongPressRunningSession,
    this.onToggleRunningSessionPinned,
    required this.onSelectProject,
    required this.onLoadMore,
    this.onLoadMoreProject,
    this.onToggleProjectCollapsed,
    this.onToggleProjectPinned,
    required this.providerFilter,
    required this.namedOnly,
    this.filters = const RecentSessionFilters(),
    this.supportsAdvancedFilters = false,
    this.providerFilterOptions = const [
      ProviderFilter.all,
      ProviderFilter.codex,
      ProviderFilter.claude,
    ],
    required this.onToggleProvider,
    required this.onToggleNamed,
    this.appUpdateInfo,
    this.onDismissAppUpdate,
    this.showMacOSNativeAppBanner = false,
    this.onDismissMacOSNativeAppBanner,
    this.onOpenMacOSNativeAppReleases,
    this.onOpenBridgeSettings,
    this.onOpenSupportSettings,
    this.onOpenUsageSettings,
    this.showInlineStopButtonOverride,
    this.connectedBridgeLabel,
    this.usageBridgeService,
    this.usageOverride,
    this.usageDisplayMode = UsageDisplayMode.remaining,
  });

  @override
  State<HomeContent> createState() => HomeContentState();
}

class HomeContentState extends State<HomeContent> {
  static const _displayModePreferenceKey = 'session_list_display_mode';
  static const _groupRecentSessionsPreferenceKey =
      'session_list_group_recent_sessions';

  bool _isSearching = false;
  bool _updateBannerDismissed = false;
  bool _showSupportBanner = false;
  bool _groupRecentSessions = true;
  final _searchController = TextEditingController();
  SessionDisplayMode _displayMode = SessionDisplayMode.first;
  RevenueCatService? _revenueCatService;
  VoidCallback? _catalogStateListener;
  SupportBannerService? _supportBannerService;
  VoidCallback? _supportBannerListener;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString(_displayModePreferenceKey);
    final groupRecentSessions =
        prefs.getBool(_groupRecentSessionsPreferenceKey) ?? true;
    if (!mounted) return;
    setState(() {
      if (modeStr != null) {
        _displayMode = SessionDisplayMode.values.firstWhere(
          (m) => m.name == modeStr,
          orElse: () => SessionDisplayMode.first,
        );
      }
      _groupRecentSessions = groupRecentSessions;
    });
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

  Future<void> _setDisplayMode(SessionDisplayMode next) async {
    if (!mounted) return;
    setState(() => _displayMode = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_displayModePreferenceKey, next.name);
  }

  Future<void> _setRecentGrouping(bool next) async {
    if (!mounted) return;
    setState(() => _groupRecentSessions = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_groupRecentSessionsPreferenceKey, next);
  }

  void _openDisplaySettings() {
    showRecentDisplaySettings(
      context: context,
      grouped: _groupRecentSessions,
      displayMode: _displayMode,
      onGroupedChanged: _setRecentGrouping,
      onDisplayModeChanged: _setDisplayMode,
    );
  }

  SessionListCubit? _maybeCubit() {
    try {
      return context.read<SessionListCubit>();
    } catch (_) {
      return null;
    }
  }

  Future<void> _openProjectPicker(List<RecentProjectOption> projects) async {
    final result = await showRecentProjectPicker(
      context: context,
      projects: projects,
      selected: widget.filters.projectKeys.isNotEmpty
          ? widget.filters.projectKeys
          : {?widget.currentProjectFilter},
      favorites: widget.pinnedProjectPaths,
      multiSelect: widget.supportsAdvancedFilters,
      onToggleFavorite: widget.onToggleProjectPinned,
    );
    if (result == null || !mounted) return;
    if (result.length <= 1) {
      widget.onSelectProject(result.firstOrNull);
    } else {
      _maybeCubit()?.setProjectFilters(result);
    }
  }

  Future<void> _pickCustomDateRange() async {
    final picked = await pickCustomRecentDateRange(
      context,
      initial: widget.filters.dateFilter,
    );
    if (picked == null || !mounted) return;
    _maybeCubit()?.setDateFilter(picked);
  }

  Future<void> _openAdvancedSearch(List<RecentProjectOption> projects) async {
    final result = await showRecentAdvancedSearch(
      context: context,
      searchQuery: widget.searchQuery,
      filters:
          widget.filters.projectKeys.isEmpty &&
              widget.currentProjectFilter != null
          ? widget.filters.copyWith(projectKeys: {widget.currentProjectFilter!})
          : widget.filters,
      providerFilter: widget.providerFilter,
      providerOptions: widget.providerFilterOptions,
      namedOnly: widget.namedOnly,
      supportsAdvancedFilters: widget.supportsAdvancedFilters,
      projects: projects,
      favoriteProjects: widget.pinnedProjectPaths,
      onToggleFavoriteProject: widget.onToggleProjectPinned,
    );
    if (result == null || !mounted) return;
    final query = result.searchQuery;
    setState(() {
      _isSearching = query.isNotEmpty;
      _searchController.text = query;
    });
    _maybeCubit()?.applyAdvancedSearch(
      searchQuery: query,
      filters: result.filters,
      providerFilter: result.providerFilter,
      namedOnly: result.namedOnly,
    );
  }

  void _clearFilters() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
    });
    final cubit = _maybeCubit();
    if (cubit != null) {
      cubit.clearFilters();
    } else {
      widget.onSelectProject(null);
    }
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

  /// Opens or closes the search field, e.g. from the iPhone Duo strip.
  void toggleSearch() => _toggleSearch();

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
    final hasKnownProjects =
        widget.accumulatedProjectPaths.isNotEmpty ||
        widget.workspaceProjects.isNotEmpty;
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
    final selectedSessionId = shell?.liveSessionId;
    final selectedSessionProvider = selectedSession?.provider?.value;
    final showInlineStopButton =
        widget.showInlineStopButtonOverride ?? shell != null;
    final connectedBridgeBanner = _buildConnectedBridgeBanner(context);
    final usageSummary = switch ((
      widget.usageOverride,
      widget.usageBridgeService,
    )) {
      (final usage?, _) when usageSummaryProviders(usage).isNotEmpty =>
        UsageSummary(
          providers: usage,
          displayMode: widget.usageDisplayMode,
          onTap: widget.onOpenUsageSettings,
        ),
      (_, final bridge?) => UsageStreamSummary(
        bridgeService: bridge,
        displayMode: widget.usageDisplayMode,
        onTap: widget.onOpenUsageSettings,
      ),
      _ => null,
    };
    final runningSessionsHeader = _RunningSessionsHeader(
      label: l.running,
      emptyLabel: l.noActiveSessions,
      color: appColors.statusOnline,
      usageSummary: usageSummary,
      showEmptyMessage: !hasRunningSessions,
    );

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

    // Pins are matched by provider:sessionId; the stored key also holds a
    // projectPath that differs between running, grouped and Codex shapes.
    final pinnedIdentities = pinIdentitiesOf(widget.pinnedSessionKeys);
    bool isRecentPinned(RecentSession session) =>
        pinnedIdentities.contains(recentSessionPinIdentity(session));
    bool isRunningPinned(SessionInfo session) {
      final identity = runningSessionPinIdentity(session);
      return identity != null && pinnedIdentities.contains(identity);
    }

    // All filtering (project, provider, namedOnly, searchQuery, period,
    // pinned only) is applied server-side. Only deduplicate running sessions.
    final filteredSessions = prioritizePinned(
      widget.recentSessions.where((session) => !isDuplicate(session)),
      isPinned: isRecentPinned,
      isProjectPinned: (session) =>
          widget.pinnedProjectPaths.contains(session.workspaceGroupKey),
    );
    final assignedSessionPaths = widget.recentSessions
        .where((session) => session.workspaceKind != 'unassigned')
        .map((session) => session.projectPath)
        .toSet();
    final unassignedSessionPaths = widget.recentSessions
        .where((session) => session.workspaceKind == 'unassigned')
        .map((session) => session.projectPath)
        .toSet();
    final projectFilterNames = <String, String>{
      // Named Projects stay ahead of the usually much longer folder history.
      for (final project in widget.workspaceProjects)
        'project:${project.id}': project.name,
    };
    // Session-derived entries cover the short window before the Project
    // catalog response arrives, without replacing a renamed catalog entry.
    for (final session in widget.recentSessions) {
      if (session.workspaceKind == 'project' &&
          session.workspaceGroupKey.isNotEmpty) {
        projectFilterNames.putIfAbsent(
          session.workspaceGroupKey,
          () => session.projectName,
        );
      }
    }
    projectFilterNames.addAll({
      for (final project in widget.workspaceProjects)
        if (project.rootPaths.isNotEmpty)
          project.primaryPath: pathBasename(project.primaryPath),
      for (final path in widget.accumulatedProjectPaths)
        if (path.isNotEmpty &&
            (!assignedSessionPaths.contains(path) ||
                unassignedSessionPaths.contains(path)))
          path: pathBasename(path),
    });
    final duplicateProjectNames = <String, int>{};
    for (final project in widget.workspaceProjects) {
      duplicateProjectNames.update(
        project.name,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    for (final project in widget.workspaceProjects) {
      if ((duplicateProjectNames[project.name] ?? 0) <= 1) continue;
      final primaryName = pathBasename(project.primaryPath);
      final samePrimaryCount = widget.workspaceProjects
          .where(
            (candidate) =>
                candidate.name == project.name &&
                candidate.primaryPath == project.primaryPath,
          )
          .length;
      projectFilterNames['project:${project.id}'] = samePrimaryCount > 1
          ? '${project.name} · $primaryName · ${project.id.substring(0, project.id.length < 6 ? project.id.length : 6)}'
          : '${project.name} · $primaryName';
    }
    final currentProjectNames = {
      for (final project in widget.workspaceProjects)
        'project:${project.id}': project.name,
    };
    final projectPathsWithPinnedSessions = filteredSessions
        .where(isRecentPinned)
        .map((session) => session.workspaceGroupKey)
        .toSet();
    final selectedProjectKeys = widget.filters.projectKeys.isNotEmpty
        ? widget.filters.projectKeys
        : {?widget.currentProjectFilter};
    final hasActiveFilter =
        selectedProjectKeys.isNotEmpty ||
        widget.providerFilter != ProviderFilter.all ||
        widget.namedOnly ||
        widget.searchQuery.isNotEmpty ||
        widget.filters.isActive;
    // Favorite projects stay visible in grouped mode even when the loaded
    // pages hold none of their sessions; "show more" loads them.
    final keepEmptyGroups = hasActiveFilter
        ? const <String>{}
        : widget.pinnedProjectPaths;
    final allProjectPaths = prioritizePinned(
      <String>{
        ...selectedProjectKeys,
        if (selectedProjectKeys.isEmpty) ...widget.accumulatedProjectPaths,
        if (selectedProjectKeys.isEmpty) ...keepEmptyGroups,
        if (selectedProjectKeys.isEmpty)
          ...filteredSessions.map((session) => session.workspaceGroupKey),
      }.where((path) => path.isNotEmpty),
      isPinned: projectPathsWithPinnedSessions.contains,
      isProjectPinned: widget.pinnedProjectPaths.contains,
    );
    final groupedRecentSessions =
        _groupSessionsByProject(
              projectPaths: allProjectPaths,
              sessions: filteredSessions,
              currentProjectNames: currentProjectNames,
              keepEmpty: keepEmptyGroups,
            )
            .where(
              (group) =>
                  group.sessions.isNotEmpty ||
                  keepEmptyGroups.contains(group.groupKey),
            )
            .toList();
    final runningSessions = prioritizePinned(
      widget.sessions,
      isPinned: isRunningPinned,
      isProjectPinned: (session) =>
          widget.pinnedProjectPaths.contains(session.workspaceGroupKey),
    );
    final projectOptions = prioritizePinned(
      projectFilterNames.entries,
      isPinned: (entry) => widget.pinnedProjectPaths.contains(entry.key),
    ).map((entry) => (key: entry.key, name: entry.value)).toList();
    // List mode: pinned sessions first, then everything else by date.
    final pinnedListSessions = filteredSessions.where(isRecentPinned).toList();
    final unpinnedListSessions =
        filteredSessions.where((s) => !isRecentPinned(s)).toList()
          ..sort((a, b) => _modifiedMillis(b).compareTo(_modifiedMillis(a)));
    final advancedCount =
        widget.filters.advancedOnlyCount + (widget.namedOnly ? 1 : 0);
    final highlightQuery = widget.searchQuery.trim().isEmpty
        ? null
        : widget.searchQuery.trim();

    if (!hasRunningSessions &&
        !hasRecentSessions &&
        !hasKnownProjects &&
        !hasActiveFilter) {
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
            runningSessionsHeader,
            const SizedBox(height: 16),
            SectionHeader(
              icon: Icons.history,
              label: l.recentSessions,
              color: appColors.subtleText,
            ),
            const SizedBox(height: 8),
            const SessionListLoadingStatus(),
            const SizedBox(height: 12),
            const SessionListSkeleton(),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: runningSessionsHeader,
          ),
          const SizedBox(height: 48),
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
        runningSessionsHeader,
        if (hasRunningSessions) ...[
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
          for (final session in runningSessions)
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
                projectNameOverride:
                    currentProjectNames[session.workspaceGroupKey],
                isPinned: isRunningPinned(session),
                onTogglePinned:
                    runningSessionPinKey(session) == null ||
                        widget.onToggleRunningSessionPinned == null
                    ? null
                    : () => widget.onToggleRunningSessionPinned!(session),
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
                  workspace: session.workspace,
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
        ],
        const SizedBox(height: 16),
        if (widget.isInitialLoading ||
            hasRecentSessions ||
            hasKnownProjects ||
            hasActiveFilter) ...[
          SectionHeader(
            icon: Icons.history,
            label: l.recentSessions,
            color: appColors.subtleText,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: const ValueKey('search_button'),
                  icon: Icon(
                    _isSearching ? Icons.close : Icons.search,
                    size: 18,
                    color: appColors.subtleText,
                  ),
                  onPressed: _toggleSearch,
                  tooltip: l.search,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  key: const ValueKey('recent_display_settings_button'),
                  icon: Icon(Icons.tune, size: 18, color: appColors.subtleText),
                  onPressed: _openDisplaySettings,
                  tooltip: l.recentDisplaySettings,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
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
                suffixIcon: IconButton(
                  key: const ValueKey('search_field_advanced_button'),
                  icon: Icon(
                    Icons.manage_search,
                    size: 20,
                    color: appColors.subtleText,
                  ),
                  tooltip: l.recentAdvancedSearch,
                  onPressed: () => _openAdvancedSearch(projectOptions),
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
            filters: widget.filters.projectKeys.isEmpty
                ? widget.filters.copyWith(projectKeys: selectedProjectKeys)
                : widget.filters,
            supportsAdvancedFilters: widget.supportsAdvancedFilters,
            providerFilter: widget.providerFilter,
            providerOptions: widget.providerFilterOptions,
            onProviderSelected: (next) {
              final cubit = _maybeCubit();
              if (cubit != null) {
                cubit.setProviderFilter(next);
              } else {
                widget.onToggleProvider();
              }
            },
            projects: projectOptions,
            onOpenProjectPicker: () => _openProjectPicker(projectOptions),
            onTogglePinnedOnly: () => _maybeCubit()?.togglePinnedOnly(),
            onDateFilterChanged: (filter) =>
                _maybeCubit()?.setDateFilter(filter),
            onPickCustomDateRange: _pickCustomDateRange,
            advancedCount: advancedCount,
            onOpenAdvancedSearch: () => _openAdvancedSearch(projectOptions),
            onClearFilters:
                hasActiveFilter &&
                    (selectedProjectKeys.isNotEmpty ||
                        widget.namedOnly ||
                        widget.searchQuery.isNotEmpty ||
                        widget.filters.isActive)
                ? _clearFilters
                : null,
          ),
          const SizedBox(height: 8),
          if (widget.isInitialLoading)
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SessionListLoadingStatus(),
                SizedBox(height: 12),
                SessionListSkeleton(),
              ],
            )
          else ...[
            if ((!_groupRecentSessions && filteredSessions.isEmpty) ||
                (_groupRecentSessions &&
                    groupedRecentSessions.isEmpty &&
                    !widget.hasMoreSessions))
              _RecentSessionsEmptyResult(
                title: hasActiveFilter
                    ? l.noSessionsMatchFilters
                    : l.noRecentSessions,
                subtitle: hasActiveFilter ? l.adjustFiltersAndSearch : null,
              )
            else if (!_groupRecentSessions) ...[
              if (pinnedListSessions.isNotEmpty) ...[
                _RecentListSubheader(
                  key: const ValueKey('recent_pinned_section'),
                  icon: Icons.push_pin,
                  label: l.recentPinnedSection,
                ),
                for (final session in pinnedListSessions)
                  _RecentSessionSlidable(
                    session: session,
                    projectNameOverride:
                        currentProjectNames[session.workspaceGroupKey],
                    isPinned: true,
                    displayMode: _displayMode,
                    highlightQuery: highlightQuery,
                    archivingSessionIds: widget.archivingSessionIds,
                    onArchiveSession: widget.onArchiveSession,
                    onResumeSession: widget.onResumeSession,
                    onTogglePinned: widget.onToggleRecentSessionPinned == null
                        ? null
                        : () => widget.onToggleRecentSessionPinned!(session),
                    onLongPressRecentSession: widget.onLongPressRecentSession,
                  ),
              ],
              for (final (index, session) in unpinnedListSessions.indexed) ...[
                if (index == 0 ||
                    _localDay(session) !=
                        _localDay(unpinnedListSessions[index - 1]))
                  _RecentListSubheader(
                    key: ValueKey('recent_date_header_${_localDay(session)}'),
                    icon: Icons.calendar_today_outlined,
                    label: _dayLabel(context, session),
                  ),
                _RecentSessionSlidable(
                  session: session,
                  projectNameOverride:
                      currentProjectNames[session.workspaceGroupKey],
                  isPinned: false,
                  displayMode: _displayMode,
                  highlightQuery: highlightQuery,
                  archivingSessionIds: widget.archivingSessionIds,
                  onArchiveSession: widget.onArchiveSession,
                  onResumeSession: widget.onResumeSession,
                  onTogglePinned: widget.onToggleRecentSessionPinned == null
                      ? null
                      : () => widget.onToggleRecentSessionPinned!(session),
                  onLongPressRecentSession: widget.onLongPressRecentSession,
                ),
              ],
              if (widget.hasMoreSessions) ...[
                const SizedBox(height: 8),
                _LoadMoreRecentSessionsButton(
                  isLoadingMore: widget.isLoadingMore,
                  onLoadMore: widget.onLoadMore,
                ),
                const SizedBox(height: 8),
              ],
            ] else
              for (final group in groupedRecentSessions)
                _ProjectRecentSessionGroup(
                  group: group,
                  displayMode: _displayMode,
                  isCollapsed: widget.collapsedProjectPaths.contains(
                    group.groupKey,
                  ),
                  isLoadingMore: widget.loadingProjectPaths.contains(
                    group.groupKey,
                  ),
                  displayLimit:
                      widget.projectSessionDisplayLimits[group.groupKey] ?? 5,
                  canLoadFromBridge:
                      widget.currentProjectFilter == null &&
                      !widget.exhaustedProjectPaths.contains(group.groupKey),
                  archivingSessionIds: widget.archivingSessionIds,
                  isSessionPinned: isRecentPinned,
                  highlightQuery: highlightQuery,
                  isPinned: widget.pinnedProjectPaths.contains(group.groupKey),
                  onToggleCollapsed: () =>
                      widget.onToggleProjectCollapsed?.call(group.groupKey),
                  onTogglePinned: widget.onToggleProjectPinned == null
                      ? null
                      : () => widget.onToggleProjectPinned!(group.groupKey),
                  onLoadMore: () =>
                      widget.onLoadMoreProject?.call(group.groupKey),
                  onArchiveSession: widget.onArchiveSession,
                  onResumeSession: widget.onResumeSession,
                  onToggleSessionPinned: widget.onToggleRecentSessionPinned,
                  onLongPressRecentSession: widget.onLongPressRecentSession,
                ),
            if (_groupRecentSessions && widget.hasMoreSessions) ...[
              const SizedBox(height: 8),
              _LoadMoreRecentSessionsButton(
                isLoadingMore: widget.isLoadingMore,
                onLoadMore: widget.onLoadMore,
              ),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ],
    );
  }
}

class _RunningSessionsHeader extends StatelessWidget {
  final String label;
  final String emptyLabel;
  final Color color;
  final Widget? usageSummary;
  final bool showEmptyMessage;

  const _RunningSessionsHeader({
    required this.label,
    required this.emptyLabel,
    required this.color,
    required this.usageSummary,
    required this.showEmptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          key: const ValueKey('running_sessions_header'),
          icon: Icons.play_circle_filled,
          label: label,
          color: color,
        ),
        const SizedBox(height: 4),
        if (showEmptyMessage)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              emptyLabel,
              key: const ValueKey('running_sessions_empty_message'),
              style: TextStyle(fontSize: 12, color: appColors.subtleText),
            ),
          ),
      ],
    );
    if (usageSummary == null) return header;

    final labelPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: color,
        ),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final tapTargetLeft = 4 + 16 + 6 + labelPainter.width + 8;

    return LayoutBuilder(
      builder: (context, constraints) => Stack(
        children: [
          header,
          Positioned(
            top: 0,
            left: tapTargetLeft.clamp(0, constraints.maxWidth).toDouble(),
            right: 0,
            height: 44,
            child: usageSummary!,
          ),
        ],
      ),
    );
  }
}

class _LoadMoreRecentSessionsButton extends StatelessWidget {
  final bool isLoadingMore;
  final VoidCallback onLoadMore;

  const _LoadMoreRecentSessionsButton({
    required this.isLoadingMore,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: isLoadingMore
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
              onPressed: onLoadMore,
              icon: const Icon(Icons.expand_more, size: 18),
              label: const Text('Load More'),
            ),
    );
  }
}

class _RecentSessionSlidable extends StatelessWidget {
  final RecentSession session;
  final String? projectNameOverride;
  final bool isPinned;
  final SessionDisplayMode displayMode;
  final String? highlightQuery;
  final Set<String> archivingSessionIds;
  final ValueChanged<RecentSession> onArchiveSession;
  final ValueChanged<RecentSession> onResumeSession;
  final VoidCallback? onTogglePinned;
  final void Function(RecentSession session, Offset? position)
  onLongPressRecentSession;

  const _RecentSessionSlidable({
    required this.session,
    this.projectNameOverride,
    required this.isPinned,
    required this.displayMode,
    this.highlightQuery,
    required this.archivingSessionIds,
    required this.onArchiveSession,
    required this.onResumeSession,
    required this.onTogglePinned,
    required this.onLongPressRecentSession,
  });

  @override
  Widget build(BuildContext context) {
    return Slidable(
      key: ValueKey('recent_session_${session.sessionId}'),
      endActionPane: ActionPane(
        motion: const BehindMotion(),
        extentRatio: 0.18,
        children: [
          CustomSlidableAction(
            onPressed: (_) => onArchiveSession(session),
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
                Icons.archive_outlined,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
      child: RecentSessionCard(
        session: session,
        projectNameOverride: projectNameOverride,
        isPinned: isPinned,
        displayMode: displayMode,
        highlightQuery: highlightQuery,
        isSelected: false,
        draftText: context.read<DraftService>().getDraft(session.sessionId),
        isProcessing: archivingSessionIds.contains(session.sessionId),
        onTogglePinned: onTogglePinned,
        onTap: () => onResumeSession(session),
        onLongPress: () => onLongPressRecentSession(session, null),
        onShowActions: (position) =>
            onLongPressRecentSession(session, position),
      ),
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

class _ProjectRecentSessionGroup extends StatelessWidget {
  final _ProjectSessionGroup group;
  final SessionDisplayMode displayMode;
  final bool isCollapsed;
  final bool isLoadingMore;
  final int displayLimit;
  final bool canLoadFromBridge;
  final Set<String> archivingSessionIds;
  final bool Function(RecentSession session) isSessionPinned;
  final String? highlightQuery;
  final bool isPinned;
  final VoidCallback onToggleCollapsed;
  final VoidCallback? onTogglePinned;
  final VoidCallback onLoadMore;
  final ValueChanged<RecentSession> onArchiveSession;
  final ValueChanged<RecentSession> onResumeSession;
  final ValueChanged<RecentSession>? onToggleSessionPinned;
  final void Function(RecentSession session, Offset? position)
  onLongPressRecentSession;

  const _ProjectRecentSessionGroup({
    required this.group,
    required this.displayMode,
    required this.isCollapsed,
    required this.isLoadingMore,
    required this.displayLimit,
    required this.canLoadFromBridge,
    required this.archivingSessionIds,
    required this.isSessionPinned,
    this.highlightQuery,
    required this.isPinned,
    required this.onToggleCollapsed,
    required this.onTogglePinned,
    required this.onLoadMore,
    required this.onArchiveSession,
    required this.onResumeSession,
    required this.onToggleSessionPinned,
    required this.onLongPressRecentSession,
  });

  @override
  Widget build(BuildContext context) {
    final visibleSessions = group.sessions.take(displayLimit).toList();
    final hasHiddenLoadedSessions = group.sessions.length > displayLimit;
    final canShowMore = hasHiddenLoadedSessions || canLoadFromBridge;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProjectRecentSessionHeader(
            groupKey: group.groupKey,
            projectName: group.projectName,
            isCollapsed: isCollapsed,
            isPinned: isPinned,
            onTap: onToggleCollapsed,
            onTogglePinned: onTogglePinned,
          ),
          if (!isCollapsed) ...[
            const SizedBox(height: 4),
            for (final session in visibleSessions)
              _RecentSessionSlidable(
                session: session,
                projectNameOverride: group.projectName,
                isPinned: isSessionPinned(session),
                displayMode: displayMode,
                highlightQuery: highlightQuery,
                archivingSessionIds: archivingSessionIds,
                onArchiveSession: onArchiveSession,
                onResumeSession: onResumeSession,
                onTogglePinned: onToggleSessionPinned == null
                    ? null
                    : () => onToggleSessionPinned!(session),
                onLongPressRecentSession: onLongPressRecentSession,
              ),
            if (isLoadingMore)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (canShowMore)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 28, top: 2, bottom: 4),
                  child: InkWell(
                    key: ValueKey('project_show_more_${group.groupKey}'),
                    borderRadius: BorderRadius.circular(6),
                    onTap: onLoadMore,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      child: Text(
                        AppLocalizations.of(context).showMore,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else if (group.sessions.isEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 40, top: 4, bottom: 8),
                child: Text(
                  AppLocalizations.of(context).noRecentSessions,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ProjectRecentSessionHeader extends StatelessWidget {
  final String groupKey;
  final String projectName;
  final bool isCollapsed;
  final bool isPinned;
  final VoidCallback onTap;
  final VoidCallback? onTogglePinned;

  const _ProjectRecentSessionHeader({
    required this.groupKey,
    required this.projectName,
    required this.isCollapsed,
    required this.isPinned,
    required this.onTap,
    required this.onTogglePinned,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('project_header_$groupKey'),
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              AnimatedRotation(
                turns: isCollapsed ? 0 : 0.25,
                duration: const Duration(milliseconds: 160),
                child: Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  projectName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              PinToggleButton(
                key: ValueKey('pin_project_$groupKey'),
                isPinned: isPinned,
                onPressed: onTogglePinned,
                pinTooltip: AppLocalizations.of(context).pinProject,
                unpinTooltip: AppLocalizations.of(context).unpinProject,
              ),
            ],
          ),
        ),
      ),
    );
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
    final isProcessing = action.state == OfflinePendingActionState.processing;
    final status = isProcessing
        ? switch (action.kind) {
            OfflinePendingActionKind.start =>
              l.pendingActionProcessingStartStatus,
            OfflinePendingActionKind.resume => l.pendingActionProcessingStatus,
          }
        : l.pendingActionStatus;
    final subtitle = switch ((action.state, action.kind)) {
      (
        OfflinePendingActionState.queuedForReconnect,
        OfflinePendingActionKind.start,
      ) =>
        l.pendingActionWillCreateOnReconnect,
      (
        OfflinePendingActionState.queuedForReconnect,
        OfflinePendingActionKind.resume,
      ) =>
        l.pendingActionWillResumeOnReconnect,
      (OfflinePendingActionState.processing, OfflinePendingActionKind.start) =>
        l.pendingActionProcessingStartDescription,
      (OfflinePendingActionState.processing, OfflinePendingActionKind.resume) =>
        l.pendingActionProcessingResumeDescription,
    };
    final title = switch ((action.state, action.kind)) {
      (
        OfflinePendingActionState.queuedForReconnect,
        OfflinePendingActionKind.start,
      ) =>
        l.offlinePendingNewSessionTitle,
      (
        OfflinePendingActionState.queuedForReconnect,
        OfflinePendingActionKind.resume,
      ) =>
        l.offlinePendingResumeTitle,
      (OfflinePendingActionState.processing, OfflinePendingActionKind.start) =>
        l.pendingActionProcessingStartTitle,
      (OfflinePendingActionState.processing, OfflinePendingActionKind.resume) =>
        l.pendingActionProcessingResumeTitle,
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
                  status,
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
                      isProcessing ? Icons.cloud_sync : Icons.cloud_off,
                      size: 13,
                      color: appColors.subtleText,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        isProcessing ? l.processingOnBridge : l.queuedLocally,
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

int _modifiedMillis(RecentSession session) =>
    DateTime.tryParse(session.modified)?.millisecondsSinceEpoch ?? 0;

/// Local calendar day (yyyy-mm-dd) of the session's last update.
String _localDay(RecentSession session) {
  final modified = DateTime.tryParse(session.modified)?.toLocal();
  if (modified == null) return '';
  return '${modified.year}-${modified.month}-${modified.day}';
}

String _dayLabel(BuildContext context, RecentSession session) {
  final l = AppLocalizations.of(context);
  final modified = DateTime.tryParse(session.modified)?.toLocal();
  if (modified == null) return '-';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(modified.year, modified.month, modified.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return l.recentDateToday;
  if (diff == 1) return l.recentDateYesterday;
  if (diff == 2) return l.recentDateDayBeforeYesterday;
  final locale = Localizations.localeOf(context).toLanguageTag();
  final format = day.year == today.year
      ? DateFormat.MMMEd(locale)
      : DateFormat.yMMMEd(locale);
  return format.format(day);
}

class _RecentListSubheader extends StatelessWidget {
  final IconData icon;
  final String label;

  const _RecentListSubheader({
    super.key,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = Theme.of(context).extension<AppColors>()!;
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 10, bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: 12, color: appColors.subtleText),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: appColors.subtleText,
            ),
          ),
        ],
      ),
    );
  }
}
