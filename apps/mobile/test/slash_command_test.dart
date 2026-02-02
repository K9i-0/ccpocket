import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/chat_message_handler.dart';
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

    test('defaults to empty lists when fields missing', () {
      final msg = ServerMessage.fromJson({
        'type': 'system',
        'subtype': 'init',
        'sessionId': 'test-2',
      });
      final sys = msg as SystemMessage;
      expect(sys.slashCommands, isEmpty);
      expect(sys.skills, isEmpty);
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
      expect(cmd.description, 'Compact conversation');
      expect(cmd.icon, Icons.compress);
      expect(cmd.category, SlashCommandCategory.builtin);
    });

    test('unknown command gets default icon', () {
      final cmd = buildSlashCommand('my-custom-command');
      expect(cmd.command, '/my-custom-command');
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
      expect(cmd.category, SlashCommandCategory.project);
      expect(cmd.icon, Icons.terminal); // unknown → default
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
  });
}
