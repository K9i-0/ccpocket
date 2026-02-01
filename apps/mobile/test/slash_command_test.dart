import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/models/messages.dart';
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
        expect(cmd.category, SlashCommandCategory.builtin,
            reason: '$name should be builtin');
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
    test('contains expected default commands', () {
      expect(fallbackSlashCommands, hasLength(4));
      final names = fallbackSlashCommands.map((c) => c.command).toList();
      expect(names, contains('/compact'));
      expect(names, contains('/plan'));
      expect(names, contains('/clear'));
      expect(names, contains('/help'));
    });

    test('all fallback commands are builtin category', () {
      for (final cmd in fallbackSlashCommands) {
        expect(cmd.category, SlashCommandCategory.builtin);
      }
    });
  });
}
