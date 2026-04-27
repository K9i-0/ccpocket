import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/chat_message_handler.dart';
import 'package:ccpocket/widgets/file_mention_overlay.dart';
import 'package:ccpocket/widgets/slash_command_sheet.dart';

void main() {
  group('SystemMessage slash command parsing', () {
    test('parses slashCommands and skills from JSON', () {
      final msg = ServerMessage.fromJson({
        'type': 'system',
        'subtype': 'init',
        'sessionId': 'test-1',
        'model': 'claude-sonnet-4-20250514',
        'slashCommands': ['compact', 'review', 'my-cmd'],
        'skills': ['review'],
      });
      expect(msg, isA<SystemMessage>());
      final sys = msg as SystemMessage;
      expect(sys.slashCommands, ['compact', 'review', 'my-cmd']);
      expect(sys.skills, ['review']);
    });

    test('parses plugin metadata from JSON', () {
      final msg = ServerMessage.fromJson({
        'type': 'system',
        'subtype': 'supported_commands',
        'plugins': ['sample'],
        'pluginMetadata': [
          {
            'id': 'sample@test',
            'name': 'sample',
            'path': 'plugin://sample@test',
            'marketplaceName': 'test',
            'displayName': 'Sample Plugin',
            'shortDescription': 'Example plugin',
            'defaultPrompt': ['Use sample'],
            'composerIcon': ['unexpected', 'path'],
          },
        ],
      });
      final sys = msg as SystemMessage;
      expect(sys.plugins, ['sample']);
      expect(sys.pluginMetadata.single.label, 'Sample Plugin');
      expect(sys.pluginMetadata.single.path, 'plugin://sample@test');
      expect(sys.pluginMetadata.single.defaultPrompt, 'Use sample');
      expect(sys.pluginMetadata.single.composerIcon, isNull);
    });

    test('defaults to empty lists when fields missing', () {
      final msg = ServerMessage.fromJson({
        'type': 'system',
        'subtype': 'init',
        'sessionId': 'test-2',
      });
      final sys = msg as SystemMessage;
      expect(sys.slashCommands, isEmpty);
      expect(sys.skills, isEmpty);
      expect(sys.plugins, isEmpty);
    });

    test('handles null slashCommands gracefully', () {
      final msg = ServerMessage.fromJson({
        'type': 'system',
        'subtype': 'init',
        'sessionId': 'test-3',
        'slashCommands': null,
        'skills': null,
      });
      final sys = msg as SystemMessage;
      expect(sys.slashCommands, isEmpty);
      expect(sys.skills, isEmpty);
    });
  });

  group('buildSlashCommand', () {
    test('known command gets correct icon and description', () {
      final cmd = buildSlashCommand('compact');
      expect(cmd.command, '/compact');
      expect(cmd.insertText, '/compact ');
      expect(cmd.description, 'Compact conversation');
      expect(cmd.icon, Icons.compress);
      expect(cmd.category, SlashCommandCategory.builtin);
    });

    test('unknown command gets default icon', () {
      final cmd = buildSlashCommand('my-custom-command');
      expect(cmd.command, '/my-custom-command');
      expect(cmd.insertText, '/my-custom-command ');
      expect(cmd.description, 'my-custom-command');
      expect(cmd.icon, Icons.terminal);
      expect(cmd.category, SlashCommandCategory.builtin);
    });

    test('skill category is preserved', () {
      final cmd = buildSlashCommand(
        'review',
        category: SlashCommandCategory.skill,
      );
      expect(cmd.command, '/review');
      expect(cmd.category, SlashCommandCategory.skill);
      // Still gets the known metadata
      expect(cmd.description, 'Code review');
      expect(cmd.icon, Icons.rate_review_outlined);
    });

    test('project category is preserved', () {
      final cmd = buildSlashCommand(
        'deploy',
        category: SlashCommandCategory.project,
      );
      expect(cmd.command, '/deploy');
      expect(cmd.insertText, '/deploy ');
      expect(cmd.category, SlashCommandCategory.project);
      expect(cmd.icon, Icons.terminal); // unknown → default
    });

    test('codex slash skill inserts dollar skill token', () {
      final cmd = buildSlashSkill(
        const CodexSkillMetadata(
          name: 'flutter-ui-design',
          path: '/tmp/flutter-ui-design/SKILL.md',
          description: 'Flutter UI implementation guide',
        ),
      );
      expect(cmd.command, '/flutter-ui-design');
      expect(cmd.insertText, r'$flutter-ui-design ');
      expect(cmd.category, SlashCommandCategory.skill);
      expect(cmd.skillInfo?.path, '/tmp/flutter-ui-design/SKILL.md');
    });
  });

  group('SlashCommand category classification', () {
    test('known names classify as builtin', () {
      for (final name in ['compact', 'plan', 'clear', 'help', 'review']) {
        final cmd = buildSlashCommand(name);
        expect(
          cmd.category,
          SlashCommandCategory.builtin,
          reason: '$name should be builtin',
        );
      }
    });

    test('unknown names with project category are project', () {
      final cmd = buildSlashCommand(
        'fix-issue',
        category: SlashCommandCategory.project,
      );
      expect(cmd.category, SlashCommandCategory.project);
    });
  });

  group('fallbackSlashCommands', () {
    test('contains SDK-compatible commands', () {
      expect(fallbackSlashCommands, hasLength(4));
      final names = fallbackSlashCommands.map((c) => c.command).toSet();
      expect(names, contains('/compact'));
      expect(names, contains('/review'));
      expect(names, contains('/context'));
      expect(names, contains('/cost'));
    });

    test('all fallback commands are builtin category', () {
      for (final cmd in fallbackSlashCommands) {
        expect(cmd.category, SlashCommandCategory.builtin);
      }
    });
  });

  group('ChatMessageHandler slash command restoration from history', () {
    test('restores slash commands from system.init in history', () {
      final handler = ChatMessageHandler();
      final historyMsg = HistoryMessage(
        messages: [
          const SystemMessage(
            subtype: 'init',
            sessionId: 'sess-1',
            model: 'claude-sonnet',
            slashCommands: ['compact', 'review', 'my-cmd'],
            skills: ['review'],
          ),
          AssistantServerMessage(
            message: AssistantMessage(
              id: 'msg-1',
              role: 'assistant',
              content: [TextContent(text: 'Hello')],
              model: 'claude-sonnet',
            ),
          ),
        ],
      );
      final update = handler.handle(historyMsg, isBackground: false);

      expect(update.slashCommands, isNotNull);
      // Only server-provided commands (no knownCommands merge)
      expect(update.slashCommands, hasLength(3));

      final names = update.slashCommands!.map((c) => c.command).toSet();
      expect(names, contains('/compact'));
      expect(names, contains('/review'));
      expect(names, contains('/my-cmd'));

      // Category classification
      final reviewCmd = update.slashCommands!.firstWhere(
        (c) => c.command == '/review',
      );
      expect(reviewCmd.category, SlashCommandCategory.skill);

      final compactCmd = update.slashCommands!.firstWhere(
        (c) => c.command == '/compact',
      );
      expect(compactCmd.category, SlashCommandCategory.builtin);

      final customCmd = update.slashCommands!.firstWhere(
        (c) => c.command == '/my-cmd',
      );
      expect(customCmd.category, SlashCommandCategory.project);
    });

    test('returns null slashCommands when history has no system.init', () {
      final handler = ChatMessageHandler();
      final historyMsg = HistoryMessage(
        messages: [
          AssistantServerMessage(
            message: AssistantMessage(
              id: 'msg-1',
              role: 'assistant',
              content: [TextContent(text: 'Hello')],
              model: 'claude-sonnet',
            ),
          ),
        ],
      );
      final update = handler.handle(historyMsg, isBackground: false);
      expect(update.slashCommands, isNull);
    });

    test(
      'returns null slashCommands when system.init has empty slashCommands',
      () {
        final handler = ChatMessageHandler();
        final historyMsg = HistoryMessage(
          messages: [
            const SystemMessage(
              subtype: 'init',
              sessionId: 'sess-1',
              model: 'claude-sonnet',
            ),
          ],
        );
        final update = handler.handle(historyMsg, isBackground: false);
        expect(update.slashCommands, isNull);
      },
    );
  });

  group('_buildCommandList server-only logic', () {
    test('only includes server-provided commands', () {
      final handler = ChatMessageHandler();
      final update = handler.handle(
        const SystemMessage(
          subtype: 'init',
          sessionId: 'sess-1',
          model: 'claude-sonnet',
          slashCommands: ['compact', 'my-custom'],
          skills: [],
        ),
        isBackground: false,
      );

      expect(update.slashCommands, isNotNull);
      expect(update.slashCommands, hasLength(2));
      final names = update.slashCommands!.map((c) => c.command).toSet();

      expect(names, contains('/compact'));
      expect(names, contains('/my-custom'));

      // CLI-interactive-only commands should NOT be included
      expect(names, isNot(contains('/help')));
      expect(names, isNot(contains('/plan')));
    });

    test('categorises known, skill, and project commands correctly', () {
      final handler = ChatMessageHandler();
      final update = handler.handle(
        const SystemMessage(
          subtype: 'init',
          sessionId: 'sess-1',
          model: 'claude-sonnet',
          slashCommands: ['deploy', 'compact', 'review'],
          skills: ['review'],
        ),
        isBackground: false,
      );

      expect(update.slashCommands, hasLength(3));

      final deploy = update.slashCommands!.firstWhere(
        (c) => c.command == '/deploy',
      );
      expect(deploy.category, SlashCommandCategory.project);

      final compact = update.slashCommands!.firstWhere(
        (c) => c.command == '/compact',
      );
      expect(compact.category, SlashCommandCategory.builtin);

      final review = update.slashCommands!.firstWhere(
        (c) => c.command == '/review',
      );
      expect(review.category, SlashCommandCategory.skill);
    });

    test(
      'codex supported commands expose both slash skill and dollar entities',
      () {
        final handler = ChatMessageHandler();
        final update = handler.handle(
          const SystemMessage(
            subtype: 'supported_commands',
            provider: 'codex',
            skills: ['flutter-ui-design'],
            skillMetadata: [
              CodexSkillMetadata(
                name: 'flutter-ui-design',
                path: '/tmp/flutter-ui-design/SKILL.md',
                description: 'Flutter UI implementation guide',
              ),
            ],
            apps: ['demo-app'],
            appMetadata: [
              CodexAppMetadata(
                id: 'demo-app',
                name: 'Demo App',
                description: 'Example connector',
              ),
            ],
            plugins: ['sample'],
            pluginMetadata: [
              CodexPluginMetadata(
                id: 'sample@test',
                name: 'sample',
                path: 'plugin://sample@test',
                marketplaceName: 'test',
                displayName: 'Sample Plugin',
                shortDescription: 'Example plugin',
              ),
            ],
          ),
          isBackground: false,
          isCodex: true,
        );

        expect(update.slashCommands, isNotNull);
        final names = update.slashCommands!.map((c) => c.command).toSet();
        expect(names, contains('/flutter-ui-design'));
        expect(names, contains(r'$flutter-ui-design'));
        expect(names, contains(r'$demo-app'));
        expect(names, contains('@sample'));

        final slashSkill = update.slashCommands!.firstWhere(
          (c) => c.command == '/flutter-ui-design',
        );
        expect(slashSkill.insertText, r'$flutter-ui-design ');

        final app = update.slashCommands!.firstWhere(
          (c) => c.command == r'$demo-app',
        );
        expect(app.category, SlashCommandCategory.app);

        final plugin = update.slashCommands!.firstWhere(
          (c) => c.command == '@sample',
        );
        expect(plugin.category, SlashCommandCategory.plugin);
        expect(plugin.pluginInfo?.path, 'plugin://sample@test');
      },
    );
  });

  group('FileMentionOverlay', () {
    testWidgets('shows plugin completions before file completions', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FileMentionOverlay(
              filteredPlugins: [
                buildAtPlugin(
                  const CodexPluginMetadata(
                    id: 'sample@test',
                    name: 'sample',
                    path: 'plugin://sample@test',
                    marketplaceName: 'test',
                    shortDescription: 'Example plugin',
                  ),
                ),
              ],
              filteredFiles: const ['lib/main.dart'],
              onSelectPlugin: (_) {},
              onSelect: (_) {},
              onDismiss: () {},
            ),
          ),
        ),
      );

      final pluginTop = tester.getTopLeft(find.text('@sample')).dy;
      final fileTop = tester.getTopLeft(find.text('main.dart')).dy;
      expect(pluginTop, lessThan(fileTop));
    });
  });
}
