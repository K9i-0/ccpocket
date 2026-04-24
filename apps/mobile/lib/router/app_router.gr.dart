// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'app_router.dart';

/// generated route for
/// [AdaptiveHomeScreen]
class AdaptiveHomeRoute extends PageRouteInfo<AdaptiveHomeRouteArgs> {
  AdaptiveHomeRoute({
    Key? key,
    ValueNotifier<ConnectionParams?>? deepLinkNotifier,
    List<RecentSession>? debugRecentSessions,
    List<PageRouteInfo>? children,
  }) : super(
         AdaptiveHomeRoute.name,
         args: AdaptiveHomeRouteArgs(
           key: key,
           deepLinkNotifier: deepLinkNotifier,
           debugRecentSessions: debugRecentSessions,
         ),
         initialChildren: children,
       );

  static const String name = 'AdaptiveHomeRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<AdaptiveHomeRouteArgs>(
        orElse: () => const AdaptiveHomeRouteArgs(),
      );
      return AdaptiveHomeScreen(
        key: args.key,
        deepLinkNotifier: args.deepLinkNotifier,
        debugRecentSessions: args.debugRecentSessions,
      );
    },
  );
}

class AdaptiveHomeRouteArgs {
  const AdaptiveHomeRouteArgs({
    this.key,
    this.deepLinkNotifier,
    this.debugRecentSessions,
  });

  final Key? key;

  final ValueNotifier<ConnectionParams?>? deepLinkNotifier;

  final List<RecentSession>? debugRecentSessions;

  @override
  String toString() {
    return 'AdaptiveHomeRouteArgs{key: $key, deepLinkNotifier: $deepLinkNotifier, debugRecentSessions: $debugRecentSessions}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AdaptiveHomeRouteArgs) return false;
    return key == other.key &&
        deepLinkNotifier == other.deepLinkNotifier &&
        const ListEquality<RecentSession>().equals(
          debugRecentSessions,
          other.debugRecentSessions,
        );
  }

  @override
  int get hashCode =>
      key.hashCode ^
      deepLinkNotifier.hashCode ^
      const ListEquality<RecentSession>().hash(debugRecentSessions);
}

/// generated route for
/// [AuthHelpScreen]
class AuthHelpRoute extends PageRouteInfo<void> {
  const AuthHelpRoute({List<PageRouteInfo>? children})
    : super(AuthHelpRoute.name, initialChildren: children);

  static const String name = 'AuthHelpRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const AuthHelpScreen();
    },
  );
}

/// generated route for
/// [ChangelogScreen]
class ChangelogRoute extends PageRouteInfo<void> {
  const ChangelogRoute({List<PageRouteInfo>? children})
    : super(ChangelogRoute.name, initialChildren: children);

  static const String name = 'ChangelogRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const ChangelogScreen();
    },
  );
}

/// generated route for
/// [ClaudeSessionScreen]
class ClaudeSessionRoute extends PageRouteInfo<ClaudeSessionRouteArgs> {
  ClaudeSessionRoute({
    Key? key,
    required String sessionId,
    String? projectPath,
    String? gitBranch,
    String? worktreePath,
    bool isPending = false,
    String? initialPermissionMode,
    String? initialSandboxMode,
    ValueNotifier<SystemMessage?>? pendingSessionCreated,
    VoidCallback? onBackToSessions,
    bool hideSessionBackButton = false,
    List<PageRouteInfo>? children,
  }) : super(
         ClaudeSessionRoute.name,
         args: ClaudeSessionRouteArgs(
           key: key,
           sessionId: sessionId,
           projectPath: projectPath,
           gitBranch: gitBranch,
           worktreePath: worktreePath,
           isPending: isPending,
           initialPermissionMode: initialPermissionMode,
           initialSandboxMode: initialSandboxMode,
           pendingSessionCreated: pendingSessionCreated,
           onBackToSessions: onBackToSessions,
           hideSessionBackButton: hideSessionBackButton,
         ),
         initialChildren: children,
       );

  static const String name = 'ClaudeSessionRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ClaudeSessionRouteArgs>();
      return ClaudeSessionScreen(
        key: args.key,
        sessionId: args.sessionId,
        projectPath: args.projectPath,
        gitBranch: args.gitBranch,
        worktreePath: args.worktreePath,
        isPending: args.isPending,
        initialPermissionMode: args.initialPermissionMode,
        initialSandboxMode: args.initialSandboxMode,
        pendingSessionCreated: args.pendingSessionCreated,
        onBackToSessions: args.onBackToSessions,
        hideSessionBackButton: args.hideSessionBackButton,
      );
    },
  );
}

class ClaudeSessionRouteArgs {
  const ClaudeSessionRouteArgs({
    this.key,
    required this.sessionId,
    this.projectPath,
    this.gitBranch,
    this.worktreePath,
    this.isPending = false,
    this.initialPermissionMode,
    this.initialSandboxMode,
    this.pendingSessionCreated,
    this.onBackToSessions,
    this.hideSessionBackButton = false,
  });

  final Key? key;

  final String sessionId;

  final String? projectPath;

  final String? gitBranch;

  final String? worktreePath;

  final bool isPending;

  final String? initialPermissionMode;

  final String? initialSandboxMode;

  final ValueNotifier<SystemMessage?>? pendingSessionCreated;

  final VoidCallback? onBackToSessions;

  final bool hideSessionBackButton;

  @override
  String toString() {
    return 'ClaudeSessionRouteArgs{key: $key, sessionId: $sessionId, projectPath: $projectPath, gitBranch: $gitBranch, worktreePath: $worktreePath, isPending: $isPending, initialPermissionMode: $initialPermissionMode, initialSandboxMode: $initialSandboxMode, pendingSessionCreated: $pendingSessionCreated, onBackToSessions: $onBackToSessions, hideSessionBackButton: $hideSessionBackButton}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ClaudeSessionRouteArgs) return false;
    return key == other.key &&
        sessionId == other.sessionId &&
        projectPath == other.projectPath &&
        gitBranch == other.gitBranch &&
        worktreePath == other.worktreePath &&
        isPending == other.isPending &&
        initialPermissionMode == other.initialPermissionMode &&
        initialSandboxMode == other.initialSandboxMode &&
        pendingSessionCreated == other.pendingSessionCreated &&
        onBackToSessions == other.onBackToSessions &&
        hideSessionBackButton == other.hideSessionBackButton;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      sessionId.hashCode ^
      projectPath.hashCode ^
      gitBranch.hashCode ^
      worktreePath.hashCode ^
      isPending.hashCode ^
      initialPermissionMode.hashCode ^
      initialSandboxMode.hashCode ^
      pendingSessionCreated.hashCode ^
      onBackToSessions.hashCode ^
      hideSessionBackButton.hashCode;
}

/// generated route for
/// [CodexSessionScreen]
class CodexSessionRoute extends PageRouteInfo<CodexSessionRouteArgs> {
  CodexSessionRoute({
    Key? key,
    required String sessionId,
    String? projectPath,
    String? gitBranch,
    String? worktreePath,
    bool isPending = false,
    String? initialSandboxMode,
    String? initialPermissionMode,
    String? initialApprovalPolicy,
    String? initialApprovalsReviewer,
    ValueNotifier<SystemMessage?>? pendingSessionCreated,
    VoidCallback? onBackToSessions,
    bool hideSessionBackButton = false,
    List<PageRouteInfo>? children,
  }) : super(
         CodexSessionRoute.name,
         args: CodexSessionRouteArgs(
           key: key,
           sessionId: sessionId,
           projectPath: projectPath,
           gitBranch: gitBranch,
           worktreePath: worktreePath,
           isPending: isPending,
           initialSandboxMode: initialSandboxMode,
           initialPermissionMode: initialPermissionMode,
           initialApprovalPolicy: initialApprovalPolicy,
           initialApprovalsReviewer: initialApprovalsReviewer,
           pendingSessionCreated: pendingSessionCreated,
           onBackToSessions: onBackToSessions,
           hideSessionBackButton: hideSessionBackButton,
         ),
         initialChildren: children,
       );

  static const String name = 'CodexSessionRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<CodexSessionRouteArgs>();
      return CodexSessionScreen(
        key: args.key,
        sessionId: args.sessionId,
        projectPath: args.projectPath,
        gitBranch: args.gitBranch,
        worktreePath: args.worktreePath,
        isPending: args.isPending,
        initialSandboxMode: args.initialSandboxMode,
        initialPermissionMode: args.initialPermissionMode,
        initialApprovalPolicy: args.initialApprovalPolicy,
        initialApprovalsReviewer: args.initialApprovalsReviewer,
        pendingSessionCreated: args.pendingSessionCreated,
        onBackToSessions: args.onBackToSessions,
        hideSessionBackButton: args.hideSessionBackButton,
      );
    },
  );
}

class CodexSessionRouteArgs {
  const CodexSessionRouteArgs({
    this.key,
    required this.sessionId,
    this.projectPath,
    this.gitBranch,
    this.worktreePath,
    this.isPending = false,
    this.initialSandboxMode,
    this.initialPermissionMode,
    this.initialApprovalPolicy,
    this.initialApprovalsReviewer,
    this.pendingSessionCreated,
    this.onBackToSessions,
    this.hideSessionBackButton = false,
  });

  final Key? key;

  final String sessionId;

  final String? projectPath;

  final String? gitBranch;

  final String? worktreePath;

  final bool isPending;

  final String? initialSandboxMode;

  final String? initialPermissionMode;

  final String? initialApprovalPolicy;

  final String? initialApprovalsReviewer;

  final ValueNotifier<SystemMessage?>? pendingSessionCreated;

  final VoidCallback? onBackToSessions;

  final bool hideSessionBackButton;

  @override
  String toString() {
    return 'CodexSessionRouteArgs{key: $key, sessionId: $sessionId, projectPath: $projectPath, gitBranch: $gitBranch, worktreePath: $worktreePath, isPending: $isPending, initialSandboxMode: $initialSandboxMode, initialPermissionMode: $initialPermissionMode, initialApprovalPolicy: $initialApprovalPolicy, initialApprovalsReviewer: $initialApprovalsReviewer, pendingSessionCreated: $pendingSessionCreated, onBackToSessions: $onBackToSessions, hideSessionBackButton: $hideSessionBackButton}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CodexSessionRouteArgs) return false;
    return key == other.key &&
        sessionId == other.sessionId &&
        projectPath == other.projectPath &&
        gitBranch == other.gitBranch &&
        worktreePath == other.worktreePath &&
        isPending == other.isPending &&
        initialSandboxMode == other.initialSandboxMode &&
        initialPermissionMode == other.initialPermissionMode &&
        initialApprovalPolicy == other.initialApprovalPolicy &&
        initialApprovalsReviewer == other.initialApprovalsReviewer &&
        pendingSessionCreated == other.pendingSessionCreated &&
        onBackToSessions == other.onBackToSessions &&
        hideSessionBackButton == other.hideSessionBackButton;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      sessionId.hashCode ^
      projectPath.hashCode ^
      gitBranch.hashCode ^
      worktreePath.hashCode ^
      isPending.hashCode ^
      initialSandboxMode.hashCode ^
      initialPermissionMode.hashCode ^
      initialApprovalPolicy.hashCode ^
      initialApprovalsReviewer.hashCode ^
      pendingSessionCreated.hashCode ^
      onBackToSessions.hashCode ^
      hideSessionBackButton.hashCode;
}

/// generated route for
/// [DebugScreen]
class DebugRoute extends PageRouteInfo<void> {
  const DebugRoute({List<PageRouteInfo>? children})
    : super(DebugRoute.name, initialChildren: children);

  static const String name = 'DebugRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const DebugScreen();
    },
  );
}

/// generated route for
/// [ExploreScreen]
class ExploreRoute extends PageRouteInfo<ExploreRouteArgs> {
  ExploreRoute({
    Key? key,
    required String sessionId,
    required String projectPath,
    List<String> initialFiles = const [],
    String initialPath = '',
    List<String> recentPeekedFiles = const [],
    bool embedded = false,
    VoidCallback? onClose,
    ValueChanged<ExploreScreenResult>? onResultChanged,
    List<PageRouteInfo>? children,
  }) : super(
         ExploreRoute.name,
         args: ExploreRouteArgs(
           key: key,
           sessionId: sessionId,
           projectPath: projectPath,
           initialFiles: initialFiles,
           initialPath: initialPath,
           recentPeekedFiles: recentPeekedFiles,
           embedded: embedded,
           onClose: onClose,
           onResultChanged: onResultChanged,
         ),
         initialChildren: children,
       );

  static const String name = 'ExploreRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ExploreRouteArgs>();
      return ExploreScreen(
        key: args.key,
        sessionId: args.sessionId,
        projectPath: args.projectPath,
        initialFiles: args.initialFiles,
        initialPath: args.initialPath,
        recentPeekedFiles: args.recentPeekedFiles,
        embedded: args.embedded,
        onClose: args.onClose,
        onResultChanged: args.onResultChanged,
      );
    },
  );
}

class ExploreRouteArgs {
  const ExploreRouteArgs({
    this.key,
    required this.sessionId,
    required this.projectPath,
    this.initialFiles = const [],
    this.initialPath = '',
    this.recentPeekedFiles = const [],
    this.embedded = false,
    this.onClose,
    this.onResultChanged,
  });

  final Key? key;

  final String sessionId;

  final String projectPath;

  final List<String> initialFiles;

  final String initialPath;

  final List<String> recentPeekedFiles;

  final bool embedded;

  final VoidCallback? onClose;

  final ValueChanged<ExploreScreenResult>? onResultChanged;

  @override
  String toString() {
    return 'ExploreRouteArgs{key: $key, sessionId: $sessionId, projectPath: $projectPath, initialFiles: $initialFiles, initialPath: $initialPath, recentPeekedFiles: $recentPeekedFiles, embedded: $embedded, onClose: $onClose, onResultChanged: $onResultChanged}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ExploreRouteArgs) return false;
    return key == other.key &&
        sessionId == other.sessionId &&
        projectPath == other.projectPath &&
        const ListEquality<String>().equals(initialFiles, other.initialFiles) &&
        initialPath == other.initialPath &&
        const ListEquality<String>().equals(
          recentPeekedFiles,
          other.recentPeekedFiles,
        ) &&
        embedded == other.embedded &&
        onClose == other.onClose &&
        onResultChanged == other.onResultChanged;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      sessionId.hashCode ^
      projectPath.hashCode ^
      const ListEquality<String>().hash(initialFiles) ^
      initialPath.hashCode ^
      const ListEquality<String>().hash(recentPeekedFiles) ^
      embedded.hashCode ^
      onClose.hashCode ^
      onResultChanged.hashCode;
}

/// generated route for
/// [GalleryScreen]
class GalleryRoute extends PageRouteInfo<GalleryRouteArgs> {
  GalleryRoute({
    Key? key,
    String? sessionId,
    bool embedded = false,
    VoidCallback? onBack,
    VoidCallback? onClose,
    List<PageRouteInfo>? children,
  }) : super(
         GalleryRoute.name,
         args: GalleryRouteArgs(
           key: key,
           sessionId: sessionId,
           embedded: embedded,
           onBack: onBack,
           onClose: onClose,
         ),
         initialChildren: children,
       );

  static const String name = 'GalleryRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<GalleryRouteArgs>(
        orElse: () => const GalleryRouteArgs(),
      );
      return GalleryScreen(
        key: args.key,
        sessionId: args.sessionId,
        embedded: args.embedded,
        onBack: args.onBack,
        onClose: args.onClose,
      );
    },
  );
}

class GalleryRouteArgs {
  const GalleryRouteArgs({
    this.key,
    this.sessionId,
    this.embedded = false,
    this.onBack,
    this.onClose,
  });

  final Key? key;

  final String? sessionId;

  final bool embedded;

  final VoidCallback? onBack;

  final VoidCallback? onClose;

  @override
  String toString() {
    return 'GalleryRouteArgs{key: $key, sessionId: $sessionId, embedded: $embedded, onBack: $onBack, onClose: $onClose}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! GalleryRouteArgs) return false;
    return key == other.key &&
        sessionId == other.sessionId &&
        embedded == other.embedded &&
        onBack == other.onBack &&
        onClose == other.onClose;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      sessionId.hashCode ^
      embedded.hashCode ^
      onBack.hashCode ^
      onClose.hashCode;
}

/// generated route for
/// [GitScreen]
class GitRoute extends PageRouteInfo<GitRouteArgs> {
  GitRoute({
    Key? key,
    String? initialDiff,
    String? projectPath,
    String? title,
    String? worktreePath,
    String? sessionId,
    bool embedded = false,
    VoidCallback? onClose,
    ValueChanged<DiffSelection>? onRequestChange,
    List<PageRouteInfo>? children,
  }) : super(
         GitRoute.name,
         args: GitRouteArgs(
           key: key,
           initialDiff: initialDiff,
           projectPath: projectPath,
           title: title,
           worktreePath: worktreePath,
           sessionId: sessionId,
           embedded: embedded,
           onClose: onClose,
           onRequestChange: onRequestChange,
         ),
         initialChildren: children,
       );

  static const String name = 'GitRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<GitRouteArgs>(
        orElse: () => const GitRouteArgs(),
      );
      return GitScreen(
        key: args.key,
        initialDiff: args.initialDiff,
        projectPath: args.projectPath,
        title: args.title,
        worktreePath: args.worktreePath,
        sessionId: args.sessionId,
        embedded: args.embedded,
        onClose: args.onClose,
        onRequestChange: args.onRequestChange,
      );
    },
  );
}

class GitRouteArgs {
  const GitRouteArgs({
    this.key,
    this.initialDiff,
    this.projectPath,
    this.title,
    this.worktreePath,
    this.sessionId,
    this.embedded = false,
    this.onClose,
    this.onRequestChange,
  });

  final Key? key;

  final String? initialDiff;

  final String? projectPath;

  final String? title;

  final String? worktreePath;

  final String? sessionId;

  final bool embedded;

  final VoidCallback? onClose;

  final ValueChanged<DiffSelection>? onRequestChange;

  @override
  String toString() {
    return 'GitRouteArgs{key: $key, initialDiff: $initialDiff, projectPath: $projectPath, title: $title, worktreePath: $worktreePath, sessionId: $sessionId, embedded: $embedded, onClose: $onClose, onRequestChange: $onRequestChange}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! GitRouteArgs) return false;
    return key == other.key &&
        initialDiff == other.initialDiff &&
        projectPath == other.projectPath &&
        title == other.title &&
        worktreePath == other.worktreePath &&
        sessionId == other.sessionId &&
        embedded == other.embedded &&
        onClose == other.onClose &&
        onRequestChange == other.onRequestChange;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      initialDiff.hashCode ^
      projectPath.hashCode ^
      title.hashCode ^
      worktreePath.hashCode ^
      sessionId.hashCode ^
      embedded.hashCode ^
      onClose.hashCode ^
      onRequestChange.hashCode;
}

/// generated route for
/// [LicensesScreen]
class LicensesRoute extends PageRouteInfo<void> {
  const LicensesRoute({List<PageRouteInfo>? children})
    : super(LicensesRoute.name, initialChildren: children);

  static const String name = 'LicensesRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const LicensesScreen();
    },
  );
}

/// generated route for
/// [MockPreviewScreen]
class MockPreviewRoute extends PageRouteInfo<void> {
  const MockPreviewRoute({List<PageRouteInfo>? children})
    : super(MockPreviewRoute.name, initialChildren: children);

  static const String name = 'MockPreviewRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const MockPreviewScreen();
    },
  );
}

/// generated route for
/// [QrScanScreen]
class QrScanRoute extends PageRouteInfo<void> {
  const QrScanRoute({List<PageRouteInfo>? children})
    : super(QrScanRoute.name, initialChildren: children);

  static const String name = 'QrScanRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const QrScanScreen();
    },
  );
}

/// generated route for
/// [SettingsScreen]
class SettingsRoute extends PageRouteInfo<SettingsRouteArgs> {
  SettingsRoute({
    Key? key,
    bool focusSupport = false,
    bool embedded = false,
    VoidCallback? onBack,
    List<PageRouteInfo>? children,
  }) : super(
         SettingsRoute.name,
         args: SettingsRouteArgs(
           key: key,
           focusSupport: focusSupport,
           embedded: embedded,
           onBack: onBack,
         ),
         initialChildren: children,
       );

  static const String name = 'SettingsRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<SettingsRouteArgs>(
        orElse: () => const SettingsRouteArgs(),
      );
      return SettingsScreen(
        key: args.key,
        focusSupport: args.focusSupport,
        embedded: args.embedded,
        onBack: args.onBack,
      );
    },
  );
}

class SettingsRouteArgs {
  const SettingsRouteArgs({
    this.key,
    this.focusSupport = false,
    this.embedded = false,
    this.onBack,
  });

  final Key? key;

  final bool focusSupport;

  final bool embedded;

  final VoidCallback? onBack;

  @override
  String toString() {
    return 'SettingsRouteArgs{key: $key, focusSupport: $focusSupport, embedded: $embedded, onBack: $onBack}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SettingsRouteArgs) return false;
    return key == other.key &&
        focusSupport == other.focusSupport &&
        embedded == other.embedded &&
        onBack == other.onBack;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      focusSupport.hashCode ^
      embedded.hashCode ^
      onBack.hashCode;
}

/// generated route for
/// [SetupGuideScreen]
class SetupGuideRoute extends PageRouteInfo<SetupGuideRouteArgs> {
  SetupGuideRoute({
    Key? key,
    bool embedded = false,
    VoidCallback? onBack,
    VoidCallback? onClose,
    List<PageRouteInfo>? children,
  }) : super(
         SetupGuideRoute.name,
         args: SetupGuideRouteArgs(
           key: key,
           embedded: embedded,
           onBack: onBack,
           onClose: onClose,
         ),
         initialChildren: children,
       );

  static const String name = 'SetupGuideRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<SetupGuideRouteArgs>(
        orElse: () => const SetupGuideRouteArgs(),
      );
      return SetupGuideScreen(
        key: args.key,
        embedded: args.embedded,
        onBack: args.onBack,
        onClose: args.onClose,
      );
    },
  );
}

class SetupGuideRouteArgs {
  const SetupGuideRouteArgs({
    this.key,
    this.embedded = false,
    this.onBack,
    this.onClose,
  });

  final Key? key;

  final bool embedded;

  final VoidCallback? onBack;

  final VoidCallback? onClose;

  @override
  String toString() {
    return 'SetupGuideRouteArgs{key: $key, embedded: $embedded, onBack: $onBack, onClose: $onClose}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SetupGuideRouteArgs) return false;
    return key == other.key &&
        embedded == other.embedded &&
        onBack == other.onBack &&
        onClose == other.onClose;
  }

  @override
  int get hashCode =>
      key.hashCode ^ embedded.hashCode ^ onBack.hashCode ^ onClose.hashCode;
}

/// generated route for
/// [SupporterScreen]
class SupporterRoute extends PageRouteInfo<void> {
  const SupporterRoute({List<PageRouteInfo>? children})
    : super(SupporterRoute.name, initialChildren: children);

  static const String name = 'SupporterRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const SupporterScreen();
    },
  );
}

/// generated route for
/// [WorkspaceClaudeSessionScreen]
class WorkspaceClaudeSessionRoute
    extends PageRouteInfo<WorkspaceClaudeSessionRouteArgs> {
  WorkspaceClaudeSessionRoute({
    Key? key,
    required String sessionId,
    String? projectPath,
    String? gitBranch,
    String? worktreePath,
    bool isPending = false,
    String? initialPermissionMode,
    String? initialSandboxMode,
    ValueNotifier<SystemMessage?>? pendingSessionCreated,
    VoidCallback? onBackToSessions,
    bool hideSessionBackButton = false,
    List<PageRouteInfo>? children,
  }) : super(
         WorkspaceClaudeSessionRoute.name,
         args: WorkspaceClaudeSessionRouteArgs(
           key: key,
           sessionId: sessionId,
           projectPath: projectPath,
           gitBranch: gitBranch,
           worktreePath: worktreePath,
           isPending: isPending,
           initialPermissionMode: initialPermissionMode,
           initialSandboxMode: initialSandboxMode,
           pendingSessionCreated: pendingSessionCreated,
           onBackToSessions: onBackToSessions,
           hideSessionBackButton: hideSessionBackButton,
         ),
         initialChildren: children,
       );

  static const String name = 'WorkspaceClaudeSessionRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<WorkspaceClaudeSessionRouteArgs>();
      return WorkspaceClaudeSessionScreen(
        key: args.key,
        sessionId: args.sessionId,
        projectPath: args.projectPath,
        gitBranch: args.gitBranch,
        worktreePath: args.worktreePath,
        isPending: args.isPending,
        initialPermissionMode: args.initialPermissionMode,
        initialSandboxMode: args.initialSandboxMode,
        pendingSessionCreated: args.pendingSessionCreated,
        onBackToSessions: args.onBackToSessions,
        hideSessionBackButton: args.hideSessionBackButton,
      );
    },
  );
}

class WorkspaceClaudeSessionRouteArgs {
  const WorkspaceClaudeSessionRouteArgs({
    this.key,
    required this.sessionId,
    this.projectPath,
    this.gitBranch,
    this.worktreePath,
    this.isPending = false,
    this.initialPermissionMode,
    this.initialSandboxMode,
    this.pendingSessionCreated,
    this.onBackToSessions,
    this.hideSessionBackButton = false,
  });

  final Key? key;

  final String sessionId;

  final String? projectPath;

  final String? gitBranch;

  final String? worktreePath;

  final bool isPending;

  final String? initialPermissionMode;

  final String? initialSandboxMode;

  final ValueNotifier<SystemMessage?>? pendingSessionCreated;

  final VoidCallback? onBackToSessions;

  final bool hideSessionBackButton;

  @override
  String toString() {
    return 'WorkspaceClaudeSessionRouteArgs{key: $key, sessionId: $sessionId, projectPath: $projectPath, gitBranch: $gitBranch, worktreePath: $worktreePath, isPending: $isPending, initialPermissionMode: $initialPermissionMode, initialSandboxMode: $initialSandboxMode, pendingSessionCreated: $pendingSessionCreated, onBackToSessions: $onBackToSessions, hideSessionBackButton: $hideSessionBackButton}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! WorkspaceClaudeSessionRouteArgs) return false;
    return key == other.key &&
        sessionId == other.sessionId &&
        projectPath == other.projectPath &&
        gitBranch == other.gitBranch &&
        worktreePath == other.worktreePath &&
        isPending == other.isPending &&
        initialPermissionMode == other.initialPermissionMode &&
        initialSandboxMode == other.initialSandboxMode &&
        pendingSessionCreated == other.pendingSessionCreated &&
        onBackToSessions == other.onBackToSessions &&
        hideSessionBackButton == other.hideSessionBackButton;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      sessionId.hashCode ^
      projectPath.hashCode ^
      gitBranch.hashCode ^
      worktreePath.hashCode ^
      isPending.hashCode ^
      initialPermissionMode.hashCode ^
      initialSandboxMode.hashCode ^
      pendingSessionCreated.hashCode ^
      onBackToSessions.hashCode ^
      hideSessionBackButton.hashCode;
}

/// generated route for
/// [WorkspaceCodexSessionScreen]
class WorkspaceCodexSessionRoute
    extends PageRouteInfo<WorkspaceCodexSessionRouteArgs> {
  WorkspaceCodexSessionRoute({
    Key? key,
    required String sessionId,
    String? projectPath,
    String? gitBranch,
    String? worktreePath,
    bool isPending = false,
    String? initialSandboxMode,
    String? initialPermissionMode,
    String? initialApprovalPolicy,
    String? initialApprovalsReviewer,
    ValueNotifier<SystemMessage?>? pendingSessionCreated,
    VoidCallback? onBackToSessions,
    bool hideSessionBackButton = false,
    List<PageRouteInfo>? children,
  }) : super(
         WorkspaceCodexSessionRoute.name,
         args: WorkspaceCodexSessionRouteArgs(
           key: key,
           sessionId: sessionId,
           projectPath: projectPath,
           gitBranch: gitBranch,
           worktreePath: worktreePath,
           isPending: isPending,
           initialSandboxMode: initialSandboxMode,
           initialPermissionMode: initialPermissionMode,
           initialApprovalPolicy: initialApprovalPolicy,
           initialApprovalsReviewer: initialApprovalsReviewer,
           pendingSessionCreated: pendingSessionCreated,
           onBackToSessions: onBackToSessions,
           hideSessionBackButton: hideSessionBackButton,
         ),
         initialChildren: children,
       );

  static const String name = 'WorkspaceCodexSessionRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<WorkspaceCodexSessionRouteArgs>();
      return WorkspaceCodexSessionScreen(
        key: args.key,
        sessionId: args.sessionId,
        projectPath: args.projectPath,
        gitBranch: args.gitBranch,
        worktreePath: args.worktreePath,
        isPending: args.isPending,
        initialSandboxMode: args.initialSandboxMode,
        initialPermissionMode: args.initialPermissionMode,
        initialApprovalPolicy: args.initialApprovalPolicy,
        initialApprovalsReviewer: args.initialApprovalsReviewer,
        pendingSessionCreated: args.pendingSessionCreated,
        onBackToSessions: args.onBackToSessions,
        hideSessionBackButton: args.hideSessionBackButton,
      );
    },
  );
}

class WorkspaceCodexSessionRouteArgs {
  const WorkspaceCodexSessionRouteArgs({
    this.key,
    required this.sessionId,
    this.projectPath,
    this.gitBranch,
    this.worktreePath,
    this.isPending = false,
    this.initialSandboxMode,
    this.initialPermissionMode,
    this.initialApprovalPolicy,
    this.initialApprovalsReviewer,
    this.pendingSessionCreated,
    this.onBackToSessions,
    this.hideSessionBackButton = false,
  });

  final Key? key;

  final String sessionId;

  final String? projectPath;

  final String? gitBranch;

  final String? worktreePath;

  final bool isPending;

  final String? initialSandboxMode;

  final String? initialPermissionMode;

  final String? initialApprovalPolicy;

  final String? initialApprovalsReviewer;

  final ValueNotifier<SystemMessage?>? pendingSessionCreated;

  final VoidCallback? onBackToSessions;

  final bool hideSessionBackButton;

  @override
  String toString() {
    return 'WorkspaceCodexSessionRouteArgs{key: $key, sessionId: $sessionId, projectPath: $projectPath, gitBranch: $gitBranch, worktreePath: $worktreePath, isPending: $isPending, initialSandboxMode: $initialSandboxMode, initialPermissionMode: $initialPermissionMode, initialApprovalPolicy: $initialApprovalPolicy, initialApprovalsReviewer: $initialApprovalsReviewer, pendingSessionCreated: $pendingSessionCreated, onBackToSessions: $onBackToSessions, hideSessionBackButton: $hideSessionBackButton}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! WorkspaceCodexSessionRouteArgs) return false;
    return key == other.key &&
        sessionId == other.sessionId &&
        projectPath == other.projectPath &&
        gitBranch == other.gitBranch &&
        worktreePath == other.worktreePath &&
        isPending == other.isPending &&
        initialSandboxMode == other.initialSandboxMode &&
        initialPermissionMode == other.initialPermissionMode &&
        initialApprovalPolicy == other.initialApprovalPolicy &&
        initialApprovalsReviewer == other.initialApprovalsReviewer &&
        pendingSessionCreated == other.pendingSessionCreated &&
        onBackToSessions == other.onBackToSessions &&
        hideSessionBackButton == other.hideSessionBackButton;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      sessionId.hashCode ^
      projectPath.hashCode ^
      gitBranch.hashCode ^
      worktreePath.hashCode ^
      isPending.hashCode ^
      initialSandboxMode.hashCode ^
      initialPermissionMode.hashCode ^
      initialApprovalPolicy.hashCode ^
      initialApprovalsReviewer.hashCode ^
      pendingSessionCreated.hashCode ^
      onBackToSessions.hashCode ^
      hideSessionBackButton.hashCode;
}

/// generated route for
/// [WorkspacePlaceholderScreen]
class WorkspacePlaceholderRoute extends PageRouteInfo<void> {
  const WorkspacePlaceholderRoute({List<PageRouteInfo>? children})
    : super(WorkspacePlaceholderRoute.name, initialChildren: children);

  static const String name = 'WorkspacePlaceholderRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const WorkspacePlaceholderScreen();
    },
  );
}
