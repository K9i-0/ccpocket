import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/utils/composer_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('composer tokens', () {
    test('parses valid Claude slash and file tokens', () {
      final tokens = parseComposerTokens(
        '/review @apps/mobile/lib/main.dart plain-text',
        const ComposerTokenConfig(
          provider: Provider.claude,
          slashCommands: {'/review'},
          fileMentions: {'apps/mobile/lib/main.dart'},
        ),
      );

      expect(tokens, hasLength(2));
      expect(tokens[0].rawText, '/review');
      expect(tokens[0].category, ComposerTokenCategory.slashCommand);
      expect(tokens[0].isValid, isTrue);
      expect(tokens[1].rawText, '@apps/mobile/lib/main.dart');
      expect(tokens[1].category, ComposerTokenCategory.fileMention);
      expect(tokens[1].isValid, isTrue);
    });

    test('parses valid Codex skill and app tokens', () {
      final tokens = parseComposerTokens(
        r'$flutter-ui-design ask $demo-app for context',
        const ComposerTokenConfig(
          provider: Provider.codex,
          skillTokens: {r'$flutter-ui-design'},
          appTokens: {r'$demo-app'},
        ),
      );

      expect(tokens, hasLength(2));
      expect(tokens[0].category, ComposerTokenCategory.skill);
      expect(tokens[1].category, ComposerTokenCategory.app);
      expect(tokens.every((token) => token.isValid), isTrue);
    });

    testWidgets('controller highlights valid tokens in buildTextSpan', (
      tester,
    ) async {
      final controller = ComposerTextEditingController()
        ..text = '/review @apps/mobile/lib/main.dart';
      addTearDown(controller.dispose);

      TextSpan? span;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              controller.updateTokenState(
                config: const ComposerTokenConfig(
                  provider: Provider.claude,
                  slashCommands: {'/review'},
                  fileMentions: {'apps/mobile/lib/main.dart'},
                ),
                palette: ComposerTokenPalette.fromTheme(Theme.of(context)),
              );
              span = controller.buildTextSpan(
                context: context,
                style: const TextStyle(fontSize: 14),
                withComposing: false,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(span?.children, isNotNull);
      final children = span!.children!;
      expect(
        children.whereType<TextSpan>().any(
          (child) =>
              child.text == '/review' && child.style?.backgroundColor != null,
        ),
        isTrue,
      );
      expect(
        children.whereType<TextSpan>().any(
          (child) =>
              child.text == '@apps/mobile/lib/main.dart' &&
              child.style?.backgroundColor != null,
        ),
        isTrue,
      );
    });

    testWidgets('controller keeps token highlight during IME composing', (
      tester,
    ) async {
      final controller = ComposerTextEditingController()
        ..value = const TextEditingValue(
          text: r'$flutter-upgrade @.mcp.json',
          selection: TextSelection.collapsed(offset: 15),
          composing: TextRange(start: 0, end: 16),
        );
      addTearDown(controller.dispose);

      TextSpan? span;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              controller.updateTokenState(
                config: const ComposerTokenConfig(
                  provider: Provider.codex,
                  skillTokens: {r'$flutter-upgrade'},
                  fileMentions: {'.mcp.json'},
                ),
                palette: ComposerTokenPalette.fromTheme(Theme.of(context)),
              );
              span = controller.buildTextSpan(
                context: context,
                style: const TextStyle(fontSize: 14),
                withComposing: true,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(span?.children, isNotNull);
      final children = span!.children!.whereType<TextSpan>().toList();
      expect(
        children.any(
          (child) =>
              child.text == r'$flutter-upgrade' &&
              child.style?.backgroundColor != null &&
              child.style?.decoration == TextDecoration.underline,
        ),
        isTrue,
      );
      expect(
        children.any(
          (child) =>
              child.text == '@.mcp.json' &&
              child.style?.backgroundColor != null &&
              child.style?.decoration != TextDecoration.underline,
        ),
        isTrue,
      );
    });
  });
}
