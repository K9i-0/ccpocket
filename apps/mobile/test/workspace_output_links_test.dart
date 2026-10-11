import 'package:ccpocket/features/response_artifacts/workspace_output_links.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('workspace output links', () {
    const projectPath = '/workspace/project';

    test('creates cards for user-addressed MCP links to known files', () {
      final message = ServerMessage.fromJson({
        'type': 'tool_result',
        'toolUseId': 'export',
        'content': '',
        'mcpResourceLinks': [
          {
            'uri': 'file:///workspace/project/reports/review.pdf',
            'name': 'Release review',
            'mimeType': 'application/pdf',
          },
          {
            'uri': 'file:///workspace/project/reports/missing.pdf',
            'name': 'Missing report',
          },
          {
            'uri': 'file:///other-project/private.pdf',
            'name': 'Outside report',
          },
          {'uri': 'https://example.org/report.pdf', 'name': 'Web report'},
        ],
      });

      final links = workspaceOutputLinksForMessage(
        message,
        projectPath: projectPath,
        knownPathSuffixes: const {'reports/review.pdf'},
      );

      expect(links.map((link) => (link.path, link.label)), [
        ('reports/review.pdf', 'Release review'),
      ]);
    });

    test('does not infer cards from assistant prose or tool output text', () {
      final assistant = AssistantServerMessage(
        message: AssistantMessage(
          id: 'answer',
          role: 'assistant',
          model: 'claude-sonnet-4-20250514',
          content: const [TextContent(text: '[Report](./reports/review.pdf)')],
        ),
      );
      const toolResult = ToolResultMessage(
        toolUseId: 'command',
        content: '[Report](./reports/review.pdf) /workspace/project/report.pdf',
      );

      for (final message in [assistant, toolResult]) {
        expect(
          workspaceOutputLinksForMessage(
            message,
            projectPath: projectPath,
            knownPathSuffixes: const {'reports/review.pdf', 'report.pdf'},
          ),
          isEmpty,
        );
      }
    });

    test('requires an active project and file list', () {
      const message = ToolResultMessage(
        toolUseId: 'export',
        content: '',
        mcpResourceLinks: [
          McpResourceLink(
            uri: 'file:///workspace/project/reports/review.pdf',
            name: 'Release review',
          ),
        ],
      );

      expect(workspaceOutputLinksForMessage(message), isEmpty);
      expect(
        workspaceOutputLinksForMessage(message, projectPath: projectPath),
        isEmpty,
      );
    });

    test('supports encoded spaces and Windows workspace file URIs', () {
      const posixMessage = ToolResultMessage(
        toolUseId: 'export',
        content: '',
        mcpResourceLinks: [
          McpResourceLink(
            uri: 'file:///workspace/project/reports/Release%20review.pdf',
            name: 'Release review',
          ),
        ],
      );
      expect(
        workspaceOutputLinksForMessage(
          posixMessage,
          projectPath: projectPath,
          knownPathSuffixes: const {'reports/Release review.pdf'},
        ).single.path,
        'reports/Release review.pdf',
      );

      const windowsMessage = ToolResultMessage(
        toolUseId: 'export',
        content: '',
        mcpResourceLinks: [
          McpResourceLink(
            uri: 'file:///C:/workspace/report.docx',
            name: 'Report',
          ),
        ],
      );
      expect(
        workspaceOutputLinksForMessage(
          windowsMessage,
          projectPath: r'C:\workspace',
          knownPathSuffixes: const {'report.docx'},
        ).single.path,
        'report.docx',
      );
    });

    test('deduplicates links and caps cards', () {
      final links = [
        for (var index = 0; index < 40; index++)
          McpResourceLink(
            uri: 'file:///workspace/project/reports/report-$index.pdf',
            name: 'Report $index',
          ),
        const McpResourceLink(
          uri: 'file:///workspace/project/reports/report-0.pdf',
          name: 'Duplicate',
        ),
      ];
      final files = {
        for (var index = 0; index < 40; index++) 'reports/report-$index.pdf',
      };
      final message = ToolResultMessage(
        toolUseId: 'export',
        content: '',
        mcpResourceLinks: links,
      );

      final cards = workspaceOutputLinksForMessage(
        message,
        projectPath: projectPath,
        knownPathSuffixes: files,
      );
      expect(cards, hasLength(32));
      expect(cards.first.label, 'Report 0');
    });
  });
}
