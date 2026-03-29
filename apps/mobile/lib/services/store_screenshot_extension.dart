/// Registers Marionette custom extensions for store screenshot automation.
///
/// These extensions allow the `call_custom_extension` MCP tool to navigate
/// directly to store screenshot mock scenarios without manually tapping
/// through the UI. Used by the `/update-store` skill.
///
/// Extensions registered:
/// - `ccpocket.navigateToStoreScenario` — navigate to a named store scenario
/// - `ccpocket.popToRoot` — pop all routes back to root
/// - `ccpocket.setTheme` — switch theme (light/dark/system)
/// - `ccpocket.setLocale` — switch app language (en/ja/zh)
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

import '../features/claude_session/claude_session_screen.dart';
import '../features/settings/state/settings_cubit.dart';
import '../features/codex_session/codex_session_screen.dart';
import '../features/git/git_screen.dart';
import '../features/session_list/state/session_list_cubit.dart';
import '../features/session_list/state/session_list_state.dart';
import '../features/session_list/widgets/home_content.dart';
import '../mock/mock_scenarios.dart';
import '../mock/store_screenshot_data.dart';
import '../models/messages.dart';
import '../providers/bridge_cubits.dart';
import '../services/bridge_service.dart';
import '../services/draft_service.dart';
import '../services/mock_bridge_service.dart';
import '../widgets/new_session_sheet.dart';

/// Static holder for app-level references needed by extension callbacks.
///
/// These are set during app initialization in [main.dart] and consumed
/// by the extension callbacks which run outside the widget tree.
class StoreScreenshotState {
  StoreScreenshotState._();

  /// Navigator key from auto_route's AppRouter.
  /// Set in [_CcpocketAppState._initRouter].
  static GlobalKey<NavigatorState>? navigatorKey;

  /// DraftService instance for scenarios that need pre-populated input.
  /// Set in [main] after DraftService creation.
  static DraftService? draftService;
}

/// Registers custom Marionette extensions for store screenshot navigation.
///
/// Call this in [main] after [MarionetteBinding.ensureInitialized()].
/// The extensions use [StoreScreenshotState] to access the navigator
/// and services — these are populated later during app startup, which
/// is fine because extensions are only called after the app is running.
void registerStoreScreenshotExtensions() {
  if (!kDebugMode) return;

  registerMarionetteExtension(
    name: 'ccpocket.navigateToStoreScenario',
    description:
        'Navigate to a store screenshot scenario by name. '
        'Available scenarios: Session List (Recent), Session List, '
        'Multi-Question Approval, Markdown Input, '
        'Image Attach, Git Diff, New Session',
    callback: (params) async {
      final scenario = params['scenario'];
      if (scenario == null || scenario.isEmpty) {
        return MarionetteExtensionResult.invalidParams(
          'Missing required parameter: scenario',
        );
      }

      final navState = StoreScreenshotState.navigatorKey?.currentState;
      if (navState == null) {
        return MarionetteExtensionResult.error(
          1,
          'Navigator not available yet. Is the app fully initialized?',
        );
      }

      try {
        _pushStoreScenario(navState, scenario);
        return MarionetteExtensionResult.success({
          'scenario': scenario,
          'status': 'navigated',
        });
      } catch (e) {
        return MarionetteExtensionResult.error(2, 'Navigation failed: $e');
      }
    },
  );

  registerMarionetteExtension(
    name: 'ccpocket.popToRoot',
    description: 'Pop all routes back to the root screen.',
    callback: (params) async {
      final navState = StoreScreenshotState.navigatorKey?.currentState;
      if (navState == null) {
        return MarionetteExtensionResult.error(1, 'Navigator not available.');
      }
      navState.popUntil((route) => route.isFirst);
      return MarionetteExtensionResult.success({'status': 'popped'});
    },
  );

  registerMarionetteExtension(
    name: 'ccpocket.setTheme',
    description:
        'Switch the app theme. '
        'Values: "light", "dark", "system".',
    callback: (params) async {
      final theme = params['theme'];
      if (theme == null || theme.isEmpty) {
        return MarionetteExtensionResult.invalidParams(
          'Missing required parameter: theme (light/dark/system)',
        );
      }

      final ctx = StoreScreenshotState.navigatorKey?.currentContext;
      if (ctx == null) {
        return MarionetteExtensionResult.error(1, 'Context not available.');
      }

      final mode = switch (theme.toLowerCase()) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => null,
      };
      if (mode == null) {
        return MarionetteExtensionResult.invalidParams(
          'Invalid theme: $theme. Use light, dark, or system.',
        );
      }

      ctx.read<SettingsCubit>().setThemeMode(mode);
      return MarionetteExtensionResult.success({'theme': theme});
    },
  );

  registerMarionetteExtension(
    name: 'ccpocket.setLocale',
    description:
        'Switch the app language. '
        'Values: "en", "ja", "zh", "" (system default).',
    callback: (params) async {
      final locale = params['locale'];
      if (locale == null) {
        return MarionetteExtensionResult.invalidParams(
          'Missing required parameter: locale (en/ja/zh/"")',
        );
      }

      final ctx = StoreScreenshotState.navigatorKey?.currentContext;
      if (ctx == null) {
        return MarionetteExtensionResult.error(1, 'Context not available.');
      }

      ctx.read<SettingsCubit>().setAppLocaleId(locale);
      return MarionetteExtensionResult.success({'locale': locale});
    },
  );

  registerMarionetteExtension(
    name: 'ccpocket.navigateToMockScenario',
    description:
        'Navigate directly to a mock scenario chat screen by name. '
        'Available scenarios: ${mockScenarios.map((s) => s.name).join(", ")}',
    callback: (params) async {
      final name = params['scenario'];
      if (name == null || name.isEmpty) {
        return MarionetteExtensionResult.invalidParams(
          'Missing required parameter: scenario',
        );
      }

      final navState = StoreScreenshotState.navigatorKey?.currentState;
      if (navState == null) {
        return MarionetteExtensionResult.error(
          1,
          'Navigator not available yet.',
        );
      }

      final scenario = mockScenarios.where((s) => s.name == name).firstOrNull;
      if (scenario == null) {
        return MarionetteExtensionResult.invalidParams(
          'Unknown scenario: $name. '
          'Available: ${mockScenarios.map((s) => s.name).join(", ")}',
        );
      }

      try {
        navState.push(
          MaterialPageRoute(
            builder: (_) => _MockScenarioChatRoute(scenario: scenario),
          ),
        );
        return MarionetteExtensionResult.success({
          'scenario': name,
          'status': 'navigated',
        });
      } catch (e) {
        return MarionetteExtensionResult.error(2, 'Navigation failed: $e');
      }
    },
  );
}

/// Push the appropriate store scenario route.
///
/// This mirrors the logic in `mock_preview_screen.dart`'s
/// `_launchStoreScenario`, but operates with a raw [NavigatorState]
/// instead of a [BuildContext].
void _pushStoreScenario(NavigatorState navigator, String scenarioName) {
  final draftService = StoreScreenshotState.draftService;

  switch (scenarioName) {
    case 'Session List':
    case 'Session List (Recent)':
      navigator.push(
        MaterialPageRoute(
          builder: (_) => _StoreSessionListRoute(
            draftService: draftService,
            minimalRunning: scenarioName == 'Session List (Recent)',
          ),
        ),
      );
    case 'New Session':
      navigator.push(
        MaterialPageRoute(
          builder: (_) => _StoreNewSessionRoute(draftService: draftService),
        ),
      );
    case 'Multi-Question Approval':
      navigator.push(
        MaterialPageRoute(
          builder: (_) => _StoreChatRoute(scenarioName: scenarioName),
        ),
      );
    case 'Markdown Input':
      navigator.push(
        MaterialPageRoute(
          builder: (_) => _StoreMarkdownInputRoute(draftService: draftService),
        ),
      );
    case 'Image Attach':
      navigator.push(
        MaterialPageRoute(
          builder: (_) => _StoreImageAttachRoute(draftService: draftService),
        ),
      );
    case 'Git Diff':
      navigator.push(
        MaterialPageRoute(builder: (_) => const _StoreGitRoute()),
      );
  }
}

// =============================================================================
// Route Widgets (duplicated from mock_preview_screen.dart's private wrappers)
//
// These are intentionally separate from the mock preview screen to avoid
// making its private widgets public. The logic is the same but adapted
// to work without a parent BuildContext (no context.read<DraftService>()).
// =============================================================================

/// Session List route for store screenshots.
class _StoreSessionListRoute extends StatefulWidget {
  final DraftService? draftService;
  final bool minimalRunning;

  const _StoreSessionListRoute({
    this.draftService,
    this.minimalRunning = false,
  });

  @override
  State<_StoreSessionListRoute> createState() => _StoreSessionListRouteState();
}

class _StoreSessionListRouteState extends State<_StoreSessionListRoute> {
  late final MockBridgeService _mockBridge;
  late final SessionListCubit _sessionListCubit;

  @override
  void initState() {
    super.initState();
    _mockBridge = MockBridgeService();
    _sessionListCubit = SessionListCubit(bridge: _mockBridge);
  }

  @override
  void dispose() {
    _sessionListCubit.close();
    _mockBridge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final running = widget.minimalRunning
        ? storeRunningSessionsMinimal()
        : storeRunningSessions();
    final recent = storeRecentSessions();
    final projectPaths = {
      ...running.map((s) => s.projectPath),
      ...recent.map((s) => s.projectPath),
    };

    Widget body = Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('CC Pocket'),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: () {}),
          IconButton(icon: const Icon(Icons.collections), onPressed: () {}),
          IconButton(icon: const Icon(Icons.link_off), onPressed: () {}),
        ],
      ),
      body: HomeContent(
        connectionState: BridgeConnectionState.connected,
        sessions: running,
        recentSessions: recent,
        accumulatedProjectPaths: projectPaths,
        searchQuery: '',
        isLoadingMore: false,
        isInitialLoading: false,
        hasMoreSessions: false,
        currentProjectFilter: null,
        onNewSession: () {},
        onTapRunning:
            (
              _, {
              projectPath,
              gitBranch,
              worktreePath,
              provider,
              permissionMode,
              sandboxMode,
            }) {},
        onStopSession: (_) {},
        onResumeSession: (_) {},
        onLongPressRecentSession: (_) {},
        onArchiveSession: (_) {},
        onLongPressRunningSession: (_) {},
        onSelectProject: (_) {},
        onLoadMore: () {},
        providerFilter: ProviderFilter.all,
        namedOnly: false,
        onToggleProvider: () {},
        onToggleNamed: () {},
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: FloatingActionButton.extended(
          onPressed: () {},
          icon: const Icon(Icons.add),
          label: const Text('New'),
        ),
      ),
    );

    if (widget.draftService != null) {
      body = RepositoryProvider<DraftService>.value(
        value: widget.draftService!,
        child: BlocProvider.value(value: _sessionListCubit, child: body),
      );
    } else {
      body = BlocProvider.value(value: _sessionListCubit, child: body);
    }

    return body;
  }
}

/// Chat route for store screenshots (Multi-Question Approval).
class _StoreChatRoute extends StatefulWidget {
  final String scenarioName;
  const _StoreChatRoute({required this.scenarioName});

  @override
  State<_StoreChatRoute> createState() => _StoreChatRouteState();
}

class _StoreChatRouteState extends State<_StoreChatRoute> {
  late final MockBridgeService _mockService;

  @override
  void initState() {
    super.initState();
    _mockService = MockBridgeService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final history = switch (widget.scenarioName) {
        'Multi-Question Approval' => storeChatMultiQuestion,
        _ => <ServerMessage>[],
      };
      _mockService.loadHistory(history);
    });
  }

  @override
  void dispose() {
    _mockService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionId =
        'store-${widget.scenarioName.toLowerCase().replaceAll(' ', '-')}';
    return RepositoryProvider<BridgeService>.value(
      value: _mockService,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => ConnectionCubit(
              BridgeConnectionState.connected,
              _mockService.connectionStatus,
            ),
          ),
          BlocProvider(
            create: (_) =>
                ActiveSessionsCubit(const [], _mockService.sessionList),
          ),
          BlocProvider(
            create: (_) => FileListCubit(const [], _mockService.fileList),
          ),
        ],
        child: ClaudeSessionScreen(
          sessionId: sessionId,
          projectPath: '/store/preview',
        ),
      ),
    );
  }
}

/// Markdown Input route for store screenshots.
class _StoreMarkdownInputRoute extends StatefulWidget {
  final DraftService? draftService;
  const _StoreMarkdownInputRoute({this.draftService});

  @override
  State<_StoreMarkdownInputRoute> createState() =>
      _StoreMarkdownInputRouteState();
}

class _StoreMarkdownInputRouteState extends State<_StoreMarkdownInputRoute> {
  static const _sessionId = 'store-markdown-input';
  late final MockBridgeService _mockService;

  @override
  void initState() {
    super.initState();
    _mockService = MockBridgeService();
    // Pre-save the markdown draft so the input field is pre-populated
    widget.draftService?.saveDraft(_sessionId, storeMarkdownInputText);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mockService.loadHistory(storeChatMarkdownInput);
    });
  }

  @override
  void dispose() {
    _mockService.dispose();
    widget.draftService?.deleteDraft(_sessionId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<BridgeService>.value(
      value: _mockService,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => ConnectionCubit(
              BridgeConnectionState.connected,
              _mockService.connectionStatus,
            ),
          ),
          BlocProvider(
            create: (_) =>
                ActiveSessionsCubit(const [], _mockService.sessionList),
          ),
          BlocProvider(
            create: (_) => FileListCubit(const [], _mockService.fileList),
          ),
        ],
        child: const ClaudeSessionScreen(
          sessionId: _sessionId,
          projectPath: '/store/preview',
        ),
      ),
    );
  }
}

/// Image Attachment route for store screenshots.
class _StoreImageAttachRoute extends StatefulWidget {
  final DraftService? draftService;
  const _StoreImageAttachRoute({this.draftService});

  @override
  State<_StoreImageAttachRoute> createState() => _StoreImageAttachRouteState();
}

class _StoreImageAttachRouteState extends State<_StoreImageAttachRoute> {
  static const _sessionId = 'store-image-attach';
  late final MockBridgeService _mockService;

  @override
  void initState() {
    super.initState();
    _mockService = MockBridgeService();
    // Pre-save mock images
    final mockImages = _generateMockImages();
    widget.draftService?.saveImageDraft(_sessionId, mockImages);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mockService.loadHistory(storeChatImageAttach);
    });
  }

  static List<({Uint8List bytes, String mimeType})> _generateMockImages() {
    return [
      (bytes: _createMiniPng(0xFF4A90D9), mimeType: 'image/png'),
      (bytes: _createMiniPng(0xFFE8913A), mimeType: 'image/png'),
    ];
  }

  static Uint8List _createMiniPng(int argb) {
    final r = (argb >> 16) & 0xFF;
    final g = (argb >> 8) & 0xFF;
    final b = argb & 0xFF;
    final header = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    final ihdr = _pngChunk('IHDR', [0, 0, 0, 1, 0, 0, 0, 1, 8, 2, 0, 0, 0]);
    final rawData = [0, r, g, b];
    final idat = _pngChunk('IDAT', _zlibCompress(rawData));
    final iend = _pngChunk('IEND', []);
    return Uint8List.fromList([...header, ...ihdr, ...idat, ...iend]);
  }

  static List<int> _pngChunk(String type, List<int> data) {
    final typeBytes = type.codeUnits;
    final length = data.length;
    final chunk = <int>[
      (length >> 24) & 0xFF,
      (length >> 16) & 0xFF,
      (length >> 8) & 0xFF,
      length & 0xFF,
      ...typeBytes,
      ...data,
    ];
    final crc = _crc32([...typeBytes, ...data]);
    chunk.addAll([
      (crc >> 24) & 0xFF,
      (crc >> 16) & 0xFF,
      (crc >> 8) & 0xFF,
      crc & 0xFF,
    ]);
    return chunk;
  }

  static List<int> _zlibCompress(List<int> data) {
    final stored = <int>[
      0x78,
      0x01,
      0x01,
      data.length & 0xFF,
      (data.length >> 8) & 0xFF,
      (~data.length) & 0xFF,
      ((~data.length) >> 8) & 0xFF,
      ...data,
    ];
    int a = 1, b2 = 0;
    for (final byte in data) {
      a = (a + byte) % 65521;
      b2 = (b2 + a) % 65521;
    }
    final adler = (b2 << 16) | a;
    stored.addAll([
      (adler >> 24) & 0xFF,
      (adler >> 16) & 0xFF,
      (adler >> 8) & 0xFF,
      adler & 0xFF,
    ]);
    return stored;
  }

  static int _crc32(List<int> data) {
    int crc = 0xFFFFFFFF;
    for (final byte in data) {
      crc ^= byte;
      for (int i = 0; i < 8; i++) {
        if ((crc & 1) != 0) {
          crc = (crc >> 1) ^ 0xEDB88320;
        } else {
          crc >>= 1;
        }
      }
    }
    return crc ^ 0xFFFFFFFF;
  }

  @override
  void dispose() {
    _mockService.dispose();
    widget.draftService?.deleteImageDraft(_sessionId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<BridgeService>.value(
      value: _mockService,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => ConnectionCubit(
              BridgeConnectionState.connected,
              _mockService.connectionStatus,
            ),
          ),
          BlocProvider(
            create: (_) =>
                ActiveSessionsCubit(const [], _mockService.sessionList),
          ),
          BlocProvider(
            create: (_) => FileListCubit(const [], _mockService.fileList),
          ),
        ],
        child: const ClaudeSessionScreen(
          sessionId: _sessionId,
          projectPath: '/store/preview',
        ),
      ),
    );
  }
}

/// Diff route for store screenshots.
class _StoreGitRoute extends StatefulWidget {
  const _StoreGitRoute();

  @override
  State<_StoreGitRoute> createState() => _StoreGitRouteState();
}

class _StoreGitRouteState extends State<_StoreGitRoute> {
  late final MockBridgeService _mockBridge;

  @override
  void initState() {
    super.initState();
    _mockBridge = MockBridgeService()..mockDiff = storeMockDiff;
  }

  @override
  void dispose() {
    _mockBridge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<BridgeService>.value(
      value: _mockBridge,
      child: const GitScreen(
        projectPath: '/mock/shopify-app',
        title: 'shopify-app',
      ),
    );
  }
}

/// New Session route for store screenshots (with bottom sheet auto-open).
class _StoreNewSessionRoute extends StatefulWidget {
  final DraftService? draftService;
  const _StoreNewSessionRoute({this.draftService});

  @override
  State<_StoreNewSessionRoute> createState() => _StoreNewSessionRouteState();
}

class _StoreNewSessionRouteState extends State<_StoreNewSessionRoute> {
  late final MockBridgeService _mockBridge;
  late final SessionListCubit _sessionListCubit;

  @override
  void initState() {
    super.initState();
    _mockBridge = MockBridgeService();
    _sessionListCubit = SessionListCubit(bridge: _mockBridge);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showNewSessionSheet();
    });
  }

  void _showNewSessionSheet() {
    if (!mounted) return;
    showNewSessionSheet(
      context: context,
      recentProjects: const [
        (path: '/Users/dev/projects/shopify-app', name: 'shopify-app'),
        (path: '/Users/dev/projects/rust-cli', name: 'rust-cli'),
        (path: '/Users/dev/projects/my-portfolio', name: 'my-portfolio'),
      ],
      projectHistory: const [],
      bridge: _mockBridge,
    );
  }

  @override
  void dispose() {
    _sessionListCubit.close();
    _mockBridge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final running = storeRunningSessionsMinimal();
    final recent = storeRecentSessions();
    final projectPaths = {
      ...running.map((s) => s.projectPath),
      ...recent.map((s) => s.projectPath),
    };

    Widget body = Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('CC Pocket'),
        actions: [
          IconButton(icon: const Icon(Icons.settings), onPressed: () {}),
          IconButton(icon: const Icon(Icons.collections), onPressed: () {}),
          IconButton(icon: const Icon(Icons.link_off), onPressed: () {}),
        ],
      ),
      body: HomeContent(
        connectionState: BridgeConnectionState.connected,
        sessions: running,
        recentSessions: recent,
        accumulatedProjectPaths: projectPaths,
        searchQuery: '',
        isLoadingMore: false,
        isInitialLoading: false,
        hasMoreSessions: false,
        currentProjectFilter: null,
        onNewSession: () {},
        onTapRunning:
            (
              _, {
              projectPath,
              gitBranch,
              worktreePath,
              provider,
              permissionMode,
              sandboxMode,
            }) {},
        onStopSession: (_) {},
        onResumeSession: (_) {},
        onLongPressRecentSession: (_) {},
        onArchiveSession: (_) {},
        onLongPressRunningSession: (_) {},
        onSelectProject: (_) {},
        onLoadMore: () {},
        providerFilter: ProviderFilter.all,
        namedOnly: false,
        onToggleProvider: () {},
        onToggleNamed: () {},
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: FloatingActionButton.extended(
          onPressed: _showNewSessionSheet,
          icon: const Icon(Icons.add),
          label: const Text('New'),
        ),
      ),
    );

    if (widget.draftService != null) {
      body = RepositoryProvider<DraftService>.value(
        value: widget.draftService!,
        child: BlocProvider.value(value: _sessionListCubit, child: body),
      );
    } else {
      body = BlocProvider.value(value: _sessionListCubit, child: body);
    }

    return body;
  }
}

// =============================================================================
// Mock Scenario Route (for call_custom_extension navigation)
// =============================================================================

/// Chat route for mock scenario navigation via custom extension.
///
/// Mirrors `_MockChatWrapper` in mock_preview_screen.dart but works
/// without a parent BuildContext (used by call_custom_extension).
class _MockScenarioChatRoute extends StatefulWidget {
  final MockScenario scenario;
  const _MockScenarioChatRoute({required this.scenario});

  @override
  State<_MockScenarioChatRoute> createState() => _MockScenarioChatRouteState();
}

class _MockScenarioChatRouteState extends State<_MockScenarioChatRoute> {
  late final MockBridgeService _mockService;

  @override
  void initState() {
    super.initState();
    _mockService = MockBridgeService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mockService.playScenario(widget.scenario);
    });
  }

  @override
  void dispose() {
    _mockService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionId =
        'mock-${widget.scenario.name.toLowerCase().replaceAll(' ', '-')}';
    return RepositoryProvider<BridgeService>.value(
      value: _mockService,
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => ConnectionCubit(
              BridgeConnectionState.connected,
              _mockService.connectionStatus,
            ),
          ),
          BlocProvider(
            create: (_) =>
                ActiveSessionsCubit(const [], _mockService.sessionList),
          ),
          BlocProvider(
            create: (_) => FileListCubit(const [], _mockService.fileList),
          ),
        ],
        child: switch (widget.scenario.provider) {
          MockScenarioProvider.codex => CodexSessionScreen(
            sessionId: sessionId,
            projectPath: '/mock/preview',
          ),
          MockScenarioProvider.claude => ClaudeSessionScreen(
            sessionId: sessionId,
            projectPath: '/mock/preview',
          ),
        },
      ),
    );
  }
}
