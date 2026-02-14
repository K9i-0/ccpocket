import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/utils/debug_bundle_share.dart';
import 'package:flutter_test/flutter_test.dart';

DebugBundleMessage _buildBundle({
  String? savedBundlePath,
  String? traceFilePath,
  String diff = '',
}) {
  return DebugBundleMessage(
    sessionId: 's-123',
    generatedAt: '2026-02-13T07:00:00.000Z',
    session: const DebugBundleSession(
      id: 's-123',
      provider: 'claude',
      status: 'idle',
      projectPath: '/Users/k9i-mini/Workspace/ccpocket',
      worktreePath: '/Users/k9i-mini/Workspace/ccpocket-worktree',
      worktreeBranch: 'feature/x',
      claudeSessionId: 'claude-1',
      createdAt: '2026-02-13T06:30:00.000Z',
      lastActivityAt: '2026-02-13T06:59:00.000Z',
    ),
    pastMessageCount: 12,
    historySummary: const ['user asked x', 'assistant replied y'],
    debugTrace: const [],
    traceFilePath: traceFilePath,
    savedBundlePath: savedBundlePath,
    reproRecipe: const DebugReproRecipe(
      wsUrlHint: 'ws://localhost:8766',
      startBridgeCommand: 'BRIDGE_PORT=8766 npm run bridge',
      notes: ['note-1'],
    ),
    agentPrompt: 'Investigate this issue.',
    diff: diff,
  );
}

void main() {
  test(
    'buildAgentInvestigationPrompt prefers file paths and lists changed files',
    () {
      final bundle = _buildBundle(
        savedBundlePath: '/tmp/bundle.json',
        traceFilePath: '/tmp/trace.jsonl',
        diff: '''
diff --git a/apps/mobile/lib/a.dart b/apps/mobile/lib/a.dart
index 111..222 100644
--- a/apps/mobile/lib/a.dart
+++ b/apps/mobile/lib/a.dart
@@ -1 +1 @@
-a
+b
diff --git a/packages/bridge/src/b.ts b/packages/bridge/src/b.ts
index 111..222 100644
--- a/packages/bridge/src/b.ts
+++ b/packages/bridge/src/b.ts
''',
      );

      final text = buildAgentInvestigationPrompt(bundle);

      expect(text, contains('bundlePath: /tmp/bundle.json'));
      expect(text, contains('tracePath: /tmp/trace.jsonl'));
      expect(text, contains('- apps/mobile/lib/a.dart'));
      expect(text, contains('- packages/bridge/src/b.ts'));
      expect(text, isNot(contains('fallback_bundle_json:')));
    },
  );

  test(
    'buildAgentInvestigationPrompt falls back to json when file paths are missing',
    () {
      final bundle = _buildBundle(diff: '');

      final text = buildAgentInvestigationPrompt(bundle);

      expect(text, contains('sessionId: s-123'));
      expect(text, contains('fallback_bundle_json:'));
      expect(text, contains('"type": "ccpocket_debug_bundle"'));
    },
  );
}
