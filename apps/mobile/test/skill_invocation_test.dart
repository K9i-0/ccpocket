import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/models/skill_trigger_style.dart';
import 'package:ccpocket/utils/skill_invocation.dart';
import 'package:ccpocket/widgets/slash_command_sheet.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

const _codex = SkillTriggerCatalog(
  provider: Provider.codex,
  skillNames: {'review-pr', 'plugin:deploy'},
);
const _claude = SkillTriggerCatalog(
  provider: Provider.claude,
  skillNames: {'review-pr', 'plugin:deploy'},
);

void main() {
  group('convertSkillTriggers to Codex', () {
    test('rewrites known slash skills at any position', () {
      expect(convertSkillTriggers('/review-pr 123', _codex), r'$review-pr 123');
      expect(
        convertSkillTriggers('please /review-pr then /plugin:deploy', _codex),
        r'please $review-pr then $plugin:deploy',
      );
    });

    test('handles punctuation and Japanese around the token', () {
      expect(
        convertSkillTriggers('run /review-pr.', _codex),
        r'run $review-pr.',
      );
      expect(
        convertSkillTriggers('(/review-pr), ok', _codex),
        r'($review-pr), ok',
      );
      expect(
        convertSkillTriggers('これを/review-prして', _codex),
        r'これを$review-prして',
      );
    });

    test('leaves unknown names, paths and native tokens alone', () {
      const inputs = [
        '/unknown do it',
        'see /usr/bin and /review-pr/sub',
        'open /review-pr.txt',
        r'$review-pr already native',
        'a/review-pr b',
        '/goal ship it',
      ];
      for (final input in inputs) {
        expect(convertSkillTriggers(input, _codex), input, reason: input);
      }
    });

    test('skips code spans and fences', () {
      const text = 'run `/review-pr` and\n```\n/review-pr\n```\n/review-pr';
      expect(
        convertSkillTriggers(text, _codex),
        'run `/review-pr` and\n```\n/review-pr\n```\n\$review-pr',
      );
    });
  });

  group('convertSkillTriggers to Claude', () {
    test('rewrites known dollar skills', () {
      expect(
        convertSkillTriggers(r'$review-pr 123', _claude),
        '/review-pr 123',
      );
      expect(
        convertSkillTriggers(r'use $plugin:deploy now', _claude),
        'use /plugin:deploy now',
      );
    });

    test('leaves prices, env vars and unknown names alone', () {
      const inputs = [r'costs $5', r'echo $HOME', r'$unknown', r'a$review-pr'];
      for (final input in inputs) {
        expect(convertSkillTriggers(input, _claude), input, reason: input);
      }
    });
  });

  group('SkillTriggerCatalog.fromCompletionItems', () {
    test('Codex uses dollar skills and excludes builtin slash names', () {
      const items = [
        SlashCommand(
          command: r'$review-pr',
          description: '',
          icon: Icons.extension,
          category: SlashCommandCategory.skill,
          skillInfo: CodexSkillInfo(name: 'review-pr', path: '/s/SKILL.md'),
        ),
        SlashCommand(
          command: r'$goal',
          description: '',
          icon: Icons.extension,
          category: SlashCommandCategory.skill,
          skillInfo: CodexSkillInfo(name: 'goal', path: '/g/SKILL.md'),
        ),
        SlashCommand(
          command: r'$demo-app',
          description: '',
          icon: Icons.apps,
          category: SlashCommandCategory.app,
        ),
      ];
      final catalog = SkillTriggerCatalog.fromCompletionItems(
        Provider.codex,
        items,
      );
      expect(catalog.skillNames, {'review-pr'});
    });

    test('Claude uses skill and project commands but not builtins', () {
      const items = [
        SlashCommand(
          command: '/review-pr',
          description: '',
          icon: Icons.extension,
          category: SlashCommandCategory.skill,
        ),
        SlashCommand(
          command: '/my-cmd',
          description: '',
          icon: Icons.terminal,
          category: SlashCommandCategory.project,
        ),
        // Claude reports builtins with descriptions as skills.
        SlashCommand(
          command: '/compact',
          description: '',
          icon: Icons.compress,
          category: SlashCommandCategory.skill,
        ),
      ];
      final catalog = SkillTriggerCatalog.fromCompletionItems(
        Provider.claude,
        items,
      );
      expect(catalog.skillNames, {'review-pr', 'my-cmd'});
    });
  });

  test('composerSkillTrigger follows style, defaulting to native', () {
    expect(composerSkillTrigger(Provider.codex, SkillTriggerStyle.both), r'$');
    expect(composerSkillTrigger(Provider.claude, SkillTriggerStyle.both), '/');
    expect(composerSkillTrigger(Provider.codex, SkillTriggerStyle.slash), '/');
    expect(
      composerSkillTrigger(Provider.claude, SkillTriggerStyle.dollar),
      r'$',
    );
  });
}
