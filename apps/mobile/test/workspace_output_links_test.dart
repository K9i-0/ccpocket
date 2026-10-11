import 'package:ccpocket/features/response_artifacts/workspace_output_links.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('workspace output links', () {
    const projectPath = '/workspace';

    test('creates cards only for explicit links to known workspace files', () {
      final links = workspaceOutputLinks(
        '''
[Report](./reports/review.pdf)
![Chart](./reports/chart.png)
[Missing](./reports/missing.pdf)
[External](https://example.org/reports/report.pdf)
''',
        projectPath: projectPath,
        knownPathSuffixes: const {'reports/review.pdf', 'reports/chart.png'},
      );

      expect(links.map((link) => link.path), [
        'reports/review.pdf',
        'reports/chart.png',
      ]);
    });

    test('rejects absolute links outside the active workspace', () {
      final links = workspaceOutputLinks(
        '''
[Workspace file](/workspace/reports/review.pdf)
[Outside file](/other-workspace/reports/review.pdf)
''',
        projectPath: projectPath,
        knownPathSuffixes: const {'reports/review.pdf'},
      );

      expect(links.map((link) => link.path), ['reports/review.pdf']);
    });

    test('does not create cards for bare paths or inline path mentions', () {
      expect(
        workspaceOutputLinks(
          '''
Output: /workspace/reports/review.pdf
Read `reports/review.pdf` and README.md.
''',
          projectPath: projectPath,
          knownPathSuffixes: const {'reports/review.pdf', 'README.md'},
        ),
        isEmpty,
      );
    });

    test('does not create cards without an active workspace file list', () {
      expect(
        workspaceOutputLinks(
          '[Report](./reports/review.pdf)',
          projectPath: projectPath,
        ),
        isEmpty,
      );
    });

    test('caps cards for large file listings', () {
      final files = {
        for (var index = 0; index < 40; index++) 'reports/report-$index.pdf',
      };
      final links = workspaceOutputLinks(
        [
          for (var index = 0; index < 40; index++)
            '[Report $index](./reports/report-$index.pdf)',
        ].join('\n'),
        projectPath: projectPath,
        knownPathSuffixes: files,
      );

      expect(links, hasLength(32));
    });

    test(
      'ignores path listings while retaining an explicit workspace link',
      () {
        final links = workspaceOutputLinks(
          [
            for (var index = 0; index < 40; index++)
              '/workspace/build/output-$index.json',
            '[Final report](./reports/final-review.pdf)',
          ].join('\n'),
          projectPath: projectPath,
          knownPathSuffixes: const {'reports/final-review.pdf'},
        );

        expect(links, hasLength(1));
        expect(links.single.path, 'reports/final-review.pdf');
        expect(links.single.label, 'Final report');
      },
    );

    test('limits Markdown scanning for unusually large tool output', () {
      final text = [
        '[Report](./reports/report.pdf)',
        'x' * (256 * 1024),
        '[Later report](./reports/later-report.pdf)',
      ].join('\n');

      expect(
        workspaceOutputLinks(
          text,
          projectPath: projectPath,
          knownPathSuffixes: const {
            'reports/report.pdf',
            'reports/later-report.pdf',
          },
        ).map((link) => link.path),
        ['reports/report.pdf'],
      );
    });

    test('bounds retained path and Markdown label metadata', () {
      final path = './reports/${'x' * 300}.pdf';
      expect(
        workspaceOutputLinks(
          '[Long]($path)',
          projectPath: projectPath,
          knownPathSuffixes: {path.substring(2)},
        ),
        isEmpty,
      );
      final links = workspaceOutputLinks(
        '[${'x' * 300}](./reports/review.pdf)',
        projectPath: projectPath,
        knownPathSuffixes: const {'reports/review.pdf'},
      );
      expect(links.single.label, hasLength(256));
    });

    test(
      'requires the destination in the workspace list for projected tool links',
      () {
        final message = ServerMessage.fromJson({
          'type': 'tool_result',
          'toolUseId': 'report',
          'content': 'Output: /workspace/reports/summary.md',
          'outputLinkCandidates': [
            {
              'href': '/workspace/reports/summary.md',
              'label': 'Report',
              'syntax': 'markdown',
            },
            {
              'href': '/workspace/reports/missing.md',
              'label': 'Missing',
              'syntax': 'markdown',
            },
            {
              'href': '/other-workspace/reports/summary.md',
              'label': 'Outside',
              'syntax': 'markdown',
            },
            {'href': 'README.md', 'label': 'README.md', 'syntax': 'bare'},
            {
              'href': '`reports/summary.md`',
              'label': 'reports/summary.md',
              'syntax': 'inline',
            },
          ],
        });

        expect(
          workspaceOutputLinksForMessage(
            message,
            projectPath: projectPath,
            knownPathSuffixes: const {'reports/summary.md'},
          ).map((link) => link.path),
          ['reports/summary.md'],
        );
      },
    );

    test(
      'keeps spaces, line positions, images, and Windows workspace links',
      () {
        final links = workspaceOutputLinks(
          '''
[Report](<${projectPath}/reports/Release review.pdf>)
[Source](lib/main.dart#L42)
![Chart](./reports/chart.png)
''',
          projectPath: projectPath,
          knownPathSuffixes: const {
            'reports/Release review.pdf',
            'lib/main.dart',
            'reports/chart.png',
          },
        );
        expect(links.map((link) => link.path), [
          'reports/Release review.pdf',
          'lib/main.dart',
          'reports/chart.png',
        ]);
        expect(links.first.label, 'Report');

        expect(
          workspaceOutputLinks(
            r'[Windows](C:/workspace/report.docx)',
            projectPath: r'C:\workspace',
            knownPathSuffixes: const {'report.docx'},
          ).single.path,
          'report.docx',
        );
      },
    );

    test('ignores code examples, directories, and web images', () {
      final links = workspaceOutputLinks(
        '''
`[Example](./sample.pdf)`
```markdown
[Example](./sample.pdf)
```
[Folder](./reports/)
![Web image](https://example.org/chart.png)
''',
        projectPath: projectPath,
        knownPathSuffixes: const {'sample.pdf'},
      );
      expect(links, isEmpty);
    });

    test(
      'extracts only explicit workspace links from assistant and tool output',
      () {
        final assistant = AssistantServerMessage(
          message: AssistantMessage(
            id: 'report',
            role: 'assistant',
            model: 'claude-sonnet-4-20250514',
            content: const [
              TextContent(text: '[Report](./reports/summary.pdf)'),
              ToolUseContent(
                id: 'read',
                name: 'Read',
                input: {'file_path': 'private.txt'},
              ),
            ],
          ),
        );
        const knownFiles = {'reports/summary.pdf'};

        final assistantLinks = workspaceOutputLinksForMessage(
          assistant,
          projectPath: projectPath,
          knownPathSuffixes: knownFiles,
        );
        expect(assistantLinks.single.path, 'reports/summary.pdf');
        expect(
          workspaceOutputLinksForMessage(
            assistant,
            projectPath: projectPath,
            knownPathSuffixes: knownFiles,
          ),
          same(assistantLinks),
        );

        final toolLinks = workspaceOutputLinksForMessage(
          const ToolResultMessage(
            toolUseId: 'report',
            content: '''
Command mentioned README.md.
Output: /workspace/reports/summary.pdf
[Report](./reports/summary.pdf)
''',
          ),
          projectPath: projectPath,
          knownPathSuffixes: knownFiles,
        );
        expect(toolLinks.map((link) => link.path), ['reports/summary.pdf']);
      },
    );
  });
}
