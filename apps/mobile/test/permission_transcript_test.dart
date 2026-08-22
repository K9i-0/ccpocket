import 'package:ccpocket/features/chat_session/permission_transcript.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const request = PermissionRequestMessage(
    toolUseId: 'command-1',
    toolName: 'Bash',
    input: {'command': 'pwd'},
  );

  test('keeps an unresolved request pending while the session is waiting', () {
    final statuses = derivePermissionTranscriptStatuses([
      ServerChatEntry(request),
    ], processStatus: ProcessStatus.waitingApproval);

    expect(statuses['command-1'], PermissionTranscriptStatus.pending);
  });

  test('uses the active request during the status transition race', () {
    final statuses = derivePermissionTranscriptStatuses(
      [ServerChatEntry(request)],
      processStatus: ProcessStatus.running,
      activeToolUseId: 'command-1',
    );

    expect(statuses['command-1'], PermissionTranscriptStatus.pending);
  });

  test(
    'does not show stale restored requests as pending in an idle session',
    () {
      final statuses = derivePermissionTranscriptStatuses([
        ServerChatEntry(request),
      ], processStatus: ProcessStatus.idle);

      expect(statuses['command-1'], PermissionTranscriptStatus.resolved);
    },
  );

  test('derives explicit Codex approval outcomes', () {
    final statuses = derivePermissionTranscriptStatuses([
      ServerChatEntry(request),
      ServerChatEntry(
        const ToolResultMessage(
          toolUseId: 'command-1',
          content: 'Approved (always)',
        ),
      ),
      ServerChatEntry(
        const ToolResultMessage(
          toolUseId: 'command-1',
          content: '/home/user',
          toolName: 'Bash',
        ),
      ),
    ], processStatus: ProcessStatus.running);

    expect(
      statuses['command-1'],
      PermissionTranscriptStatus.approvedForSession,
    );
  });

  test('treats a real tool result as resolved, not a synthetic outcome', () {
    const result = ToolResultMessage(
      toolUseId: 'command-1',
      content: '/home/user',
      toolName: 'Bash',
    );
    final statuses = derivePermissionTranscriptStatuses([
      ServerChatEntry(request),
      ServerChatEntry(result),
    ], processStatus: ProcessStatus.running);

    expect(statuses['command-1'], PermissionTranscriptStatus.resolved);
    expect(isSyntheticPermissionOutcome(result), isFalse);
  });

  test('does not hide real command output that matches an outcome label', () {
    const result = ToolResultMessage(
      toolUseId: 'command-1',
      content: 'Approved',
      toolName: 'Bash',
    );

    expect(isSyntheticPermissionOutcome(result), isFalse);
  });
}
