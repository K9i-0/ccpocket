// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'app_router.dart';

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

  @override
  String toString() {
    return 'ClaudeSessionRouteArgs{key: $key, sessionId: $sessionId, projectPath: $projectPath, gitBranch: $gitBranch, worktreePath: $worktreePath, isPending: $isPending, initialPermissionMode: $initialPermissionMode, initialSandboxMode: $initialSandboxMode, pendingSessionCreated: $pendingSessionCreated}';
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
        pendingSessionCreated == other.pendingSessionCreated;
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
      pendingSessionCreated.hashCode;
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
    ValueNotifier<SystemMessage?>? pendingSessionCreated,
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
           pendingSessionCreated: pendingSessionCreated,
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
        pendingSessionCreated: args.pendingSessionCreated,
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
    this.pendingSessionCreated,
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

  final ValueNotifier<SystemMessage?>? pendingSessionCreated;

  @override
  String toString() {
    return 'CodexSessionRouteArgs{key: $key, sessionId: $sessionId, projectPath: $projectPath, gitBranch: $gitBranch, worktreePath: $worktreePath, isPending: $isPending, initialSandboxMode: $initialSandboxMode, initialPermissionMode: $initialPermissionMode, initialApprovalPolicy: $initialApprovalPolicy, pendingSessionCreated: $pendingSessionCreated}';
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
        pendingSessionCreated == other.pendingSessionCreated;
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
      pendingSessionCreated.hashCode;
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
    required String projectPath,
    List<String> initialFiles = const [],
    List<PageRouteInfo>? children,
  }) : super(
         ExploreRoute.name,
         args: ExploreRouteArgs(
           key: key,
           projectPath: projectPath,
           initialFiles: initialFiles,
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
        projectPath: args.projectPath,
        initialFiles: args.initialFiles,
      );
    },
  );
}

class ExploreRouteArgs {
  const ExploreRouteArgs({
    this.key,
    required this.projectPath,
    this.initialFiles = const [],
  });

  final Key? key;

  final String projectPath;

  final List<String> initialFiles;

  @override
  String toString() {
    return 'ExploreRouteArgs{key: $key, projectPath: $projectPath, initialFiles: $initialFiles}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ExploreRouteArgs) return false;
    return key == other.key &&
        projectPath == other.projectPath &&
        const ListEquality<String>().equals(initialFiles, other.initialFiles);
  }

  @override
  int get hashCode =>
      key.hashCode ^
      projectPath.hashCode ^
      const ListEquality<String>().hash(initialFiles);
}

/// generated route for
/// [GalleryScreen]
class GalleryRoute extends PageRouteInfo<GalleryRouteArgs> {
  GalleryRoute({Key? key, String? sessionId, List<PageRouteInfo>? children})
    : super(
        GalleryRoute.name,
        args: GalleryRouteArgs(key: key, sessionId: sessionId),
        initialChildren: children,
      );

  static const String name = 'GalleryRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<GalleryRouteArgs>(
        orElse: () => const GalleryRouteArgs(),
      );
      return GalleryScreen(key: args.key, sessionId: args.sessionId);
    },
  );
}

class GalleryRouteArgs {
  const GalleryRouteArgs({this.key, this.sessionId});

  final Key? key;

  final String? sessionId;

  @override
  String toString() {
    return 'GalleryRouteArgs{key: $key, sessionId: $sessionId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! GalleryRouteArgs) return false;
    return key == other.key && sessionId == other.sessionId;
  }

  @override
  int get hashCode => key.hashCode ^ sessionId.hashCode;
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
  });

  final Key? key;

  final String? initialDiff;

  final String? projectPath;

  final String? title;

  final String? worktreePath;

  final String? sessionId;

  @override
  String toString() {
    return 'GitRouteArgs{key: $key, initialDiff: $initialDiff, projectPath: $projectPath, title: $title, worktreePath: $worktreePath, sessionId: $sessionId}';
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
        sessionId == other.sessionId;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      initialDiff.hashCode ^
      projectPath.hashCode ^
      title.hashCode ^
      worktreePath.hashCode ^
      sessionId.hashCode;
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
/// [SessionListScreen]
class SessionListRoute extends PageRouteInfo<SessionListRouteArgs> {
  SessionListRoute({
    Key? key,
    ValueNotifier<ConnectionParams?>? deepLinkNotifier,
    List<RecentSession>? debugRecentSessions,
    List<PageRouteInfo>? children,
  }) : super(
         SessionListRoute.name,
         args: SessionListRouteArgs(
           key: key,
           deepLinkNotifier: deepLinkNotifier,
           debugRecentSessions: debugRecentSessions,
         ),
         initialChildren: children,
       );

  static const String name = 'SessionListRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<SessionListRouteArgs>(
        orElse: () => const SessionListRouteArgs(),
      );
      return SessionListScreen(
        key: args.key,
        deepLinkNotifier: args.deepLinkNotifier,
        debugRecentSessions: args.debugRecentSessions,
      );
    },
  );
}

class SessionListRouteArgs {
  const SessionListRouteArgs({
    this.key,
    this.deepLinkNotifier,
    this.debugRecentSessions,
  });

  final Key? key;

  final ValueNotifier<ConnectionParams?>? deepLinkNotifier;

  final List<RecentSession>? debugRecentSessions;

  @override
  String toString() {
    return 'SessionListRouteArgs{key: $key, deepLinkNotifier: $deepLinkNotifier, debugRecentSessions: $debugRecentSessions}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SessionListRouteArgs) return false;
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
/// [SettingsScreen]
class SettingsRoute extends PageRouteInfo<void> {
  const SettingsRoute({List<PageRouteInfo>? children})
    : super(SettingsRoute.name, initialChildren: children);

  static const String name = 'SettingsRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const SettingsScreen();
    },
  );
}

/// generated route for
/// [SetupGuideScreen]
class SetupGuideRoute extends PageRouteInfo<void> {
  const SetupGuideRoute({List<PageRouteInfo>? children})
    : super(SetupGuideRoute.name, initialChildren: children);

  static const String name = 'SetupGuideRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const SetupGuideScreen();
    },
  );
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
