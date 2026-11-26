import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/l10n/app_localizations_delegates.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/providers/bridge_cubits.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/bubbles/assistant_bubble.dart';
import 'package:ccpocket/widgets/markdown/ccpocket_markdown.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_kit/markdown_kit.dart';

/// Assistant markdown is selected through [MarkdownSelectionScope] and
/// [MarkdownView] instead of a SelectableText (an EditableText) per paragraph.
void main() {
  final platforms = TargetPlatformVariant({
    TargetPlatform.android,
    TargetPlatform.iOS,
  });
  group('AssistantBubble markdown on mobile platforms', () {
    testWidgets('builds no EditableText for prose', (tester) async {
      final markdown = [
        '# Heading',
        for (var i = 0; i < 30; i++) 'Paragraph $i with some prose words.',
        '- list item one\n- list item two',
        '> quoted text',
        '| a | b |\n| - | - |\n| 1 | 2 |',
      ].join('\n\n');

      await tester.pumpWidget(_wrap(_bubble(markdown)));

      expect(
        find.text('Paragraph 29 with some prose words.', findRichText: true),
        findsOne,
      );
      expect(find.byType(EditableText), findsNothing);
      expect(find.byType(SelectableText), findsNothing);
      expect(find.byType(CcpocketMarkdown), findsOneWidget);
      expect(find.byType(MarkdownView), findsOneWidget);
      expect(find.byType(MarkdownSelectionScope), findsOneWidget);
    }, variant: platforms);

    testWidgets('prose stays selectable through MarkdownSelectionScope', (
      tester,
    ) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final markdown = [
        for (var i = 0; i < 5; i++) 'Paragraph $i with some prose words.',
      ].join('\n\n');
      await tester.pumpWidget(_wrap(_bubble(markdown)));

      final target = find.text(
        'Paragraph 2 with some prose words.',
        findRichText: true,
      );
      await tester.longPress(target);
      await tester.pumpAndSettle();

      final scopeState = tester.state<MarkdownSelectionScopeState>(
        find.byType(MarkdownSelectionScope),
      );
      expect(scopeState.controller.hasSelection, isTrue);
      expect(scopeState.selectedPlainText, isNotEmpty);
      expect(find.byKey(kMarkdownStartHandleKey), findsOneWidget);
      expect(find.byKey(kMarkdownEndHandleKey), findsOneWidget);
    }, variant: platforms);

    testWidgets('markdown links still respond to taps', (tester) async {
      const path = '/Users/example/project/docs/report.md';
      String? openedPath;
      await tester.pumpWidget(
        _wrap(
          _bubble(
            'Intro paragraph.\n\nSee [the report]($path) for details.',
            onFileTap: (path) => openedPath = path,
          ),
          files: const ['docs/report.md'],
        ),
      );

      final paraFinder = find.textContaining('the report', findRichText: true);
      final para = tester.renderObject<RenderSelectableParagraph>(paraFinder);
      final boxes = para.getBoxesForSelection(
        const TextSelection(baseOffset: 4, extentOffset: 14),
      );
      final linkCenter = para.localToGlobal(boxes.first.toRect().center);
      await tester.tapAt(linkCenter);
      await tester.pump();

      expect(openedPath, path);
    }, variant: platforms);

    testWidgets('inline file paths still respond to taps', (tester) async {
      String? openedPath;
      await tester.pumpWidget(
        _wrap(
          _bubble(
            'Updated lib/main.dart today.',
            onFileTap: (path) => openedPath = path,
          ),
          files: const ['lib/main.dart'],
        ),
      );

      final paraFinder = find.textContaining(
        'lib/main.dart',
        findRichText: true,
      );
      final para = tester.renderObject<RenderSelectableParagraph>(paraFinder);
      final boxes = para.getBoxesForSelection(
        const TextSelection(baseOffset: 8, extentOffset: 21),
      );
      final pathCenter = para.localToGlobal(boxes.first.toRect().center);
      await tester.tapAt(pathCenter);
      await tester.pump();

      expect(openedPath, 'lib/main.dart');
    }, variant: platforms);
  });
}

AssistantBubble _bubble(String text, {void Function(String)? onFileTap}) {
  return AssistantBubble(
    message: AssistantServerMessage(
      message: AssistantMessage(
        id: 'selection-test',
        role: 'assistant',
        content: [TextContent(text: text)],
        model: 'claude',
      ),
    ),
    onFileTap: onFileTap,
  );
}

Widget _wrap(Widget child, {List<String> files = const []}) {
  return MaterialApp(
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    theme: AppTheme.darkTheme,
    home: BlocProvider<FileListCubit>(
      create: (_) => FileListCubit(files, const Stream.empty()),
      child: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}
