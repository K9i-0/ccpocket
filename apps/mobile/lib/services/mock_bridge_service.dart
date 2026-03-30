import 'dart:async';
import 'dart:convert';

import '../mock/mock_scenarios.dart';
import '../models/messages.dart';
import 'bridge_service.dart';

class MockBridgeService extends BridgeService {
  final _mockMessageController = StreamController<ServerMessage>.broadcast();
  final List<Timer> _timers = [];

  /// Original diff text split by file for stateful stage/unstage tracking.
  String? _mockDiff;
  final Set<String> _stagedFiles = {};

  /// Set mock diff data for projectPath-mode GitScreen previews.
  set mockDiff(String value) {
    _mockDiff = value;
    _stagedFiles.clear();
  }

  @override
  Stream<ServerMessage> get messages => _mockMessageController.stream;

  @override
  String? get httpBaseUrl => null;

  @override
  bool get isConnected => true;

  @override
  Stream<BridgeConnectionState> get connectionStatus =>
      Stream.value(BridgeConnectionState.connected);

  @override
  Stream<FileContentMessage> get fileContent => _mockMessageController.stream
      .where((m) => m is FileContentMessage)
      .cast<FileContentMessage>();

  @override
  Stream<DiffResultMessage> get diffResults => _mockMessageController.stream
      .where((m) => m is DiffResultMessage)
      .cast<DiffResultMessage>();

  // Git Operations streams
  @override
  Stream<GitStageResultMessage> get gitStageResults => _mockMessageController
      .stream
      .where((m) => m is GitStageResultMessage)
      .cast<GitStageResultMessage>();

  @override
  Stream<GitUnstageResultMessage> get gitUnstageResults =>
      _mockMessageController.stream
          .where((m) => m is GitUnstageResultMessage)
          .cast<GitUnstageResultMessage>();

  @override
  Stream<GitUnstageHunksResultMessage> get gitUnstageHunksResults =>
      _mockMessageController.stream
          .where((m) => m is GitUnstageHunksResultMessage)
          .cast<GitUnstageHunksResultMessage>();

  @override
  Stream<GitCommitResultMessage> get gitCommitResults => _mockMessageController
      .stream
      .where((m) => m is GitCommitResultMessage)
      .cast<GitCommitResultMessage>();

  @override
  Stream<GitPushResultMessage> get gitPushResults => _mockMessageController
      .stream
      .where((m) => m is GitPushResultMessage)
      .cast<GitPushResultMessage>();

  @override
  Stream<GitStatusResultMessage> get gitStatusResults => _mockMessageController
      .stream
      .where((m) => m is GitStatusResultMessage)
      .cast<GitStatusResultMessage>();

  @override
  Stream<GitBranchesResultMessage> get gitBranchesResults =>
      _mockMessageController.stream
          .where((m) => m is GitBranchesResultMessage)
          .cast<GitBranchesResultMessage>();

  @override
  Stream<GitCreateBranchResultMessage> get gitCreateBranchResults =>
      _mockMessageController.stream
          .where((m) => m is GitCreateBranchResultMessage)
          .cast<GitCreateBranchResultMessage>();

  @override
  Stream<GitCheckoutBranchResultMessage> get gitCheckoutBranchResults =>
      _mockMessageController.stream
          .where((m) => m is GitCheckoutBranchResultMessage)
          .cast<GitCheckoutBranchResultMessage>();

  @override
  Stream<GitRevertFileResultMessage> get gitRevertFileResults =>
      _mockMessageController.stream
          .where((m) => m is GitRevertFileResultMessage)
          .cast<GitRevertFileResultMessage>();

  @override
  Stream<GitRevertHunksResultMessage> get gitRevertHunksResults =>
      _mockMessageController.stream
          .where((m) => m is GitRevertHunksResultMessage)
          .cast<GitRevertHunksResultMessage>();

  @override
  Stream<GitFetchResultMessage> get gitFetchResults => _mockMessageController
      .stream
      .where((m) => m is GitFetchResultMessage)
      .cast<GitFetchResultMessage>();

  @override
  Stream<GitPullResultMessage> get gitPullResults => _mockMessageController
      .stream
      .where((m) => m is GitPullResultMessage)
      .cast<GitPullResultMessage>();

  @override
  Stream<GitRemoteStatusResultMessage> get gitRemoteStatusResults =>
      _mockMessageController.stream
          .where((m) => m is GitRemoteStatusResultMessage)
          .cast<GitRemoteStatusResultMessage>();

  @override
  void send(ClientMessage message) {
    final json = jsonDecode(message.toJson()) as Map<String, dynamic>;
    final type = json['type'] as String;

    switch (type) {
      case 'approve':
        // Simulate tool execution result after approval
        _scheduleMessage(
          const Duration(milliseconds: 300),
          const StatusMessage(status: ProcessStatus.running),
        );
        _scheduleMessage(
          const Duration(milliseconds: 800),
          ToolResultMessage(
            toolUseId: json['id'] as String? ?? '',
            content: 'Tool executed successfully (mock)',
          ),
        );
        _scheduleMessage(
          const Duration(milliseconds: 1200),
          AssistantServerMessage(
            message: AssistantMessage(
              id: 'mock-post-approve',
              role: 'assistant',
              content: [
                const TextContent(
                  text: 'The tool has been executed successfully.',
                ),
              ],
              model: 'mock',
            ),
          ),
        );
        _scheduleMessage(
          const Duration(milliseconds: 1500),
          const StatusMessage(status: ProcessStatus.idle),
        );
      case 'reject':
        _scheduleMessage(
          const Duration(milliseconds: 300),
          const StatusMessage(status: ProcessStatus.idle),
        );
        _scheduleMessage(
          const Duration(milliseconds: 500),
          AssistantServerMessage(
            message: AssistantMessage(
              id: 'mock-post-reject',
              role: 'assistant',
              content: [
                const TextContent(
                  text: 'Understood. I will not execute that tool.',
                ),
              ],
              model: 'mock',
            ),
          ),
        );
      case 'answer':
        final result = json['result'] as String? ?? '';
        _scheduleMessage(
          const Duration(milliseconds: 500),
          AssistantServerMessage(
            message: AssistantMessage(
              id: 'mock-post-answer',
              role: 'assistant',
              content: [
                TextContent(
                  text:
                      'Thank you for your answer: "$result". '
                      'I will proceed accordingly.',
                ),
              ],
              model: 'mock',
            ),
          ),
        );
      case 'input':
        final text = json['text'] as String? ?? '';
        _scheduleMessage(
          const Duration(milliseconds: 300),
          const StatusMessage(status: ProcessStatus.running),
        );
        _playStreamingScenario(
          'You said: "$text". This is a mock response echoing your input.',
          startDelay: const Duration(milliseconds: 500),
        );
      case 'read_file':
        final filePath = json['filePath'] as String? ?? '';
        _scheduleMessage(
          const Duration(milliseconds: 400),
          FileContentMessage(
            filePath: filePath,
            content: _mockFileContent(filePath),
            language: _mockFileLanguage(filePath),
            totalLines: _mockFileContent(filePath).split('\n').length,
          ),
        );
      // ---- Git Operations (mock, stateful) ----
      case 'get_diff':
        final stagedParam = json['staged'] as bool?;
        // null (all mode) → return full diff; true → staged only; false → unstaged only
        final filtered = stagedParam == null
            ? (_mockDiff ?? '')
            : _filterDiffByStageState(stagedParam);
        _scheduleMessage(
          const Duration(milliseconds: 300),
          DiffResultMessage(diff: filtered),
        );
      case 'git_stage':
        final files = (json['files'] as List?)?.cast<String>() ?? [];
        _stagedFiles.addAll(files);
        // Also extract file paths from hunks
        final hunks = json['hunks'] as List?;
        if (hunks != null) {
          for (final h in hunks) {
            final file = (h as Map<String, dynamic>)['file'] as String?;
            if (file != null) _stagedFiles.add(file);
          }
        }
        _scheduleMessage(
          const Duration(milliseconds: 200),
          const GitStageResultMessage(success: true),
        );
      case 'git_unstage':
        final files = (json['files'] as List?)?.cast<String>() ?? [];
        _stagedFiles.removeAll(files);
        _scheduleMessage(
          const Duration(milliseconds: 200),
          const GitUnstageResultMessage(success: true),
        );
      case 'git_unstage_hunks':
        _scheduleMessage(
          const Duration(milliseconds: 200),
          const GitUnstageHunksResultMessage(success: true),
        );
      case 'git_commit':
        _scheduleMessage(
          const Duration(milliseconds: 500),
          GitCommitResultMessage(
            success: true,
            commitHash: 'abc1234',
            message: json['message'] as String? ?? 'mock commit',
          ),
        );
      case 'git_push':
        _scheduleMessage(
          const Duration(milliseconds: 600),
          const GitPushResultMessage(
            success: true,
            remote: 'origin',
            branch: 'feat/mock',
          ),
        );
      case 'git_status':
        _scheduleMessage(
          const Duration(milliseconds: 200),
          const GitStatusResultMessage(
            staged: ['lib/main.dart', 'lib/app.dart'],
            unstaged: ['lib/screen.dart'],
            untracked: ['lib/new_file.dart'],
          ),
        );
      case 'git_branches':
        _scheduleMessage(
          const Duration(milliseconds: 200),
          const GitBranchesResultMessage(
            current: 'feat/mock',
            branches: ['main', 'feat/mock', 'feat/login', 'fix/bug-123'],
            remoteStatusByBranch: {
              'main': GitBranchRemoteStatus(
                ahead: 0,
                behind: 0,
                hasUpstream: true,
              ),
              'feat/mock': GitBranchRemoteStatus(
                ahead: 2,
                behind: 1,
                hasUpstream: true,
              ),
              'feat/login': GitBranchRemoteStatus(
                ahead: 0,
                behind: 3,
                hasUpstream: true,
              ),
              'fix/bug-123': GitBranchRemoteStatus(
                ahead: 0,
                behind: 0,
                hasUpstream: false,
              ),
            },
          ),
        );
      case 'git_create_branch':
        _scheduleMessage(
          const Duration(milliseconds: 300),
          const GitCreateBranchResultMessage(success: true),
        );
      case 'git_checkout_branch':
        _scheduleMessage(
          const Duration(milliseconds: 300),
          const GitCheckoutBranchResultMessage(success: true),
        );
      case 'git_revert_file':
        // In mock, "revert" removes the file from the diff
        // (simulated by clearing the mock diff for those files, but for simplicity
        //  we just return success and let the diff refresh handle it)
        _scheduleMessage(
          const Duration(milliseconds: 200),
          const GitRevertFileResultMessage(success: true),
        );
      case 'git_revert_hunks':
        _scheduleMessage(
          const Duration(milliseconds: 200),
          const GitRevertHunksResultMessage(success: true),
        );
      case 'git_fetch':
        _scheduleMessage(
          const Duration(milliseconds: 200),
          const GitFetchResultMessage(success: true),
        );
      case 'git_remote_status':
        _scheduleMessage(
          const Duration(milliseconds: 100),
          const GitRemoteStatusResultMessage(
            ahead: 0,
            behind: 0,
            branch: 'feat/mock',
            hasUpstream: false,
          ),
        );
      case 'git_pull':
        _scheduleMessage(
          const Duration(milliseconds: 500),
          const GitPullResultMessage(
            success: true,
            message: 'Already up to date.',
          ),
        );
      case 'refresh_branch':
        // No-op for mock (session branch refresh)
        break;
      default:
        break;
    }
  }

  @override
  Stream<List<String>> get fileList => const Stream.empty();

  @override
  Stream<List<SessionInfo>> get sessionList => const Stream.empty();

  @override
  void requestFileList(String projectPath) {
    // No-op for mock
  }

  @override
  void interrupt(String sessionId) {
    // Simulate interrupt: stop running and go idle
    _scheduleMessage(
      const Duration(milliseconds: 200),
      const StatusMessage(status: ProcessStatus.idle),
    );
  }

  @override
  void requestSessionList() {
    // No-op for mock
  }

  @override
  void requestSessionHistory(String sessionId) {
    // No-op for mock — history is empty
  }

  @override
  Stream<ServerMessage> messagesForSession(String sessionId) => messages;

  @override
  void stopSession(String sessionId) {
    _scheduleMessage(
      const Duration(milliseconds: 200),
      const ResultMessage(subtype: 'stopped'),
    );
    _scheduleMessage(
      const Duration(milliseconds: 300),
      const StatusMessage(status: ProcessStatus.idle),
    );
  }

  /// Load a list of messages as history (instant, no animation delay).
  void loadHistory(List<ServerMessage> messages) {
    _mockMessageController.add(HistoryMessage(messages: messages));
  }

  /// Play a scenario: emit each step's message after its delay.
  void playScenario(MockScenario scenario) {
    if (scenario.streamingText != null) {
      // Find the delay of the last step to start streaming after it
      final lastStepDelay = scenario.steps.isNotEmpty
          ? scenario.steps.last.delay
          : Duration.zero;
      for (final step in scenario.steps) {
        _scheduleMessage(step.delay, step.message);
      }
      _playStreamingScenario(
        scenario.streamingText!,
        startDelay: lastStepDelay + const Duration(milliseconds: 300),
      );
    } else {
      for (final step in scenario.steps) {
        _scheduleMessage(step.delay, step.message);
      }
    }
  }

  void _playStreamingScenario(
    String text, {
    Duration startDelay = Duration.zero,
  }) {
    const charDelay = Duration(milliseconds: 20);
    for (var i = 0; i < text.length; i++) {
      _scheduleMessage(
        startDelay + charDelay * i,
        StreamDeltaMessage(text: text[i]),
      );
    }
    // Final assistant message after streaming completes
    _scheduleMessage(
      startDelay + charDelay * text.length + const Duration(milliseconds: 100),
      AssistantServerMessage(
        message: AssistantMessage(
          id: 'mock-stream-final',
          role: 'assistant',
          content: [TextContent(text: text)],
          model: 'mock',
        ),
      ),
    );
    _scheduleMessage(
      startDelay + charDelay * text.length + const Duration(milliseconds: 200),
      const StatusMessage(status: ProcessStatus.idle),
    );
  }

  void _scheduleMessage(Duration delay, ServerMessage message) {
    final timer = Timer(delay, () {
      if (!_mockMessageController.isClosed) {
        _mockMessageController.add(message);
      }
    });
    _timers.add(timer);
  }

  static String _mockFileContent(String filePath) {
    // Path-specific content for File Peek mock scenario
    final knownFiles = _knownMockFiles;
    final match = knownFiles[filePath];
    if (match != null) return match;

    // Fallback: extension-based generic content
    final ext = filePath.split('.').lastOrNull?.toLowerCase();
    return switch (ext) {
      'dart' => _genericDart(filePath),
      'md' => _genericMarkdown(filePath),
      'yaml' || 'yml' => _genericYaml(filePath),
      'json' => _genericJson(filePath),
      'ts' || 'tsx' => _genericTypeScript(filePath),
      _ => 'File content for: $filePath\n\nThis is a mock file preview.',
    };
  }

  // --- Path-specific mock contents (matched by exact path) ---

  static final Map<String, String> _knownMockFiles = {
    'lib/main.dart': '''import 'package:flutter/material.dart';
import 'features/session_list/session_list_screen.dart';

void main() {
  runApp(const MyApp(title: "Hello"));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: title,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const SessionListScreen(),
    );
  }
}''',
    'pubspec.yaml': '''name: ccpocket
description: Claude Code / Codex mobile client
publish_to: 'none'
version: 2.4.0+82

environment:
  sdk: '>=3.5.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  web_socket_channel: ^3.0.1
  flutter_bloc: ^9.1.0
  shared_preferences: ^2.3.0
  flutter_markdown: ^0.7.7
  url_launcher: ^6.3.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0''',
    'packages/bridge/src/index.ts':
        '''import { startServer } from "./websocket.js";

const PORT = Number(process.env.BRIDGE_PORT ?? 8765);
const HOST = process.env.BRIDGE_HOST ?? "0.0.0.0";
const API_KEY = process.env.BRIDGE_API_KEY;

async function main() {
  console.log(`Starting Bridge Server on \${HOST}:\${PORT}`);
  if (API_KEY) {
    console.log("API key authentication enabled");
  }

  const server = await startServer({ port: PORT, host: HOST, apiKey: API_KEY });

  process.on("SIGINT", () => {
    console.log("Shutting down...");
    server.close();
    process.exit(0);
  });
}

main().catch((err) => {
  console.error("Failed to start:", err);
  process.exit(1);
});''',
    'README.md': '''# CC Pocket

Claude Code / Codex mobile client for iOS and Android.

## Features

- **Real-time streaming** of agent responses
- **Approval flow** for tool execution
- **Diff viewer** with syntax highlighting
- **File Peek** — tap file paths to preview contents
- **Multi-session** management
- **Tailscale** remote access support

## Quick Start

```bash
# 1. Start Bridge Server
npm run bridge

# 2. Run the app
cd apps/mobile && flutter run
```

## Architecture

```
Flutter App <─ WebSocket ─> Bridge Server <─ SDK ─> Claude Code CLI
```

> Bridge Server must be running on the same machine as Claude Code.

## License

MIT''',
    'package.json': '''{
  "name": "ccpocket",
  "version": "2.4.0",
  "private": true,
  "type": "module",
  "workspaces": ["packages/*"],
  "scripts": {
    "bridge": "tsx packages/bridge/src/index.ts",
    "bridge:build": "tsc -p packages/bridge/tsconfig.json",
    "dev": "bash scripts/dev-restart.sh"
  },
  "devDependencies": {
    "typescript": "^5.7.0",
    "tsx": "^4.19.0",
    "@anthropic-ai/sdk": "^0.39.0"
  }
}''',
    'docs/architecture.md': '''# Architecture

## Overview

CC Pocket uses a **Bridge Server** pattern to connect the mobile app
to Claude Code / Codex CLIs running on a desktop machine.

## Components

### Bridge Server (`packages/bridge/`)

TypeScript WebSocket server that:
- Manages multiple concurrent sessions
- Spawns Claude Code / Codex CLI processes via SDK
- Streams responses back to the mobile client
- Handles file operations (read, diff)

### Mobile App (`apps/mobile/`)

Flutter app that:
- Connects to Bridge Server via WebSocket
- Renders streaming assistant messages as Markdown
- Provides approval/rejection flow for tool execution
- Displays git diffs with syntax highlighting

## Data Flow

```
User Input ─> WebSocket ─> Bridge Server ─> Claude SDK ─> Claude Code CLI
                                                              │
User <── Rendered UI <── Stream Parser <── WebSocket <────────┘
```

## Security

- Optional API key authentication
- Path allowlist (`BRIDGE_ALLOWED_DIRS`)
- Read-only file access from mobile client''',
    'test/widget_test.dart': '''import 'package:flutter_test/flutter_test.dart';
import 'package:ccpocket/main.dart';

void main() {
  group('MyApp', () {
    testWidgets('renders with title', (tester) async {
      await tester.pumpWidget(const MyApp(title: 'Test'));
      expect(find.text('Test'), findsOneWidget);
    });

    testWidgets('navigates to session list', (tester) async {
      await tester.pumpWidget(const MyApp(title: 'CC Pocket'));
      expect(find.byType(SessionListScreen), findsOneWidget);
    });
  });
}''',
  };

  // --- Extension-based fallback content ---

  static String _genericDart(String filePath) {
    final name = filePath.split('/').last.replaceAll('.dart', '');
    return "// $filePath\n\nclass ${_toPascalCase(name)} {\n  // TODO: implementation\n}";
  }

  static String _genericMarkdown(String filePath) {
    final name = filePath.split('/').last;
    return '# $name\n\nDocumentation for `$filePath`.';
  }

  static String _genericYaml(String filePath) =>
      '# $filePath\n# Configuration file';

  static String _genericJson(String filePath) =>
      '{\n  "_comment": "$filePath"\n}';

  static String _genericTypeScript(String filePath) =>
      '// $filePath\n\nexport {};';

  static String _toPascalCase(String input) => input
      .split(RegExp(r'[_\-]'))
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join();

  static String? _mockFileLanguage(String filePath) {
    final ext = filePath.split('.').lastOrNull?.toLowerCase();
    return switch (ext) {
      'dart' => 'dart',
      'ts' || 'tsx' => 'typescript',
      'js' || 'jsx' => 'javascript',
      'py' => 'python',
      'yaml' || 'yml' => 'yaml',
      'json' => 'json',
      'md' => 'markdown',
      'html' => 'html',
      'css' => 'css',
      _ => null,
    };
  }

  /// Split _mockDiff into per-file sections and filter by stage state.
  /// When [staged] is true, return only staged files' diffs.
  /// When [staged] is false, return only unstaged files' diffs.
  String _filterDiffByStageState(bool staged) {
    final fullDiff = _mockDiff ?? '';
    if (fullDiff.isEmpty || _stagedFiles.isEmpty) {
      return staged ? '' : fullDiff;
    }

    // Split diff into per-file blocks (each starting with "diff --git")
    final blocks = <String>[];
    final filePaths = <String>[];
    final lines = fullDiff.split('\n');
    var currentBlock = StringBuffer();
    String? currentFile;

    for (final line in lines) {
      if (line.startsWith('diff --git ')) {
        // Save previous block
        if (currentFile != null) {
          blocks.add(currentBlock.toString());
          filePaths.add(currentFile);
        }
        currentBlock = StringBuffer();
        // Extract file path: "diff --git a/path b/path" → "path"
        final match = RegExp(r'diff --git a/(.+) b/').firstMatch(line);
        currentFile = match?.group(1) ?? '';
      }
      currentBlock.writeln(line);
    }
    // Save last block
    if (currentFile != null) {
      blocks.add(currentBlock.toString());
      filePaths.add(currentFile);
    }

    // Filter: staged view shows staged files, unstaged view shows the rest
    final filtered = StringBuffer();
    for (var i = 0; i < blocks.length; i++) {
      final isStaged = _stagedFiles.contains(filePaths[i]);
      if (staged == isStaged) {
        filtered.write(blocks[i]);
      }
    }
    return filtered.toString().trimRight();
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    _mockMessageController.close();
    super.dispose();
  }
}
