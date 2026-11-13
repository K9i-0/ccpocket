import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/l10n/app_localizations_delegates.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/providers/bridge_cubits.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/bubbles/assistant_bubble.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Assistant markdown is selected through one [SelectionArea] per text block
/// instead of a SelectableText (an EditableText) per paragraph, which made
/// long replies slow to build on iOS and Android.
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

      expect(find.text('Paragraph 29 with some prose words.'), findsOne);
      expect(find.byType(EditableText), findsNothing);
      expect(find.byType(SelectableText), findsNothing);
      expect(find.byType(SelectionArea), findsOneWidget);
    }, variant: platforms);

    testWidgets('prose stays selectable through the selection area', (
      tester,
    ) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final markdown = [
        for (var i = 0; i < 5; i++) 'Paragraph $i with some prose words.',
      ].join('\n\n');
      await tester.pumpWidget(_wrap(_bubble(markdown)));

      final target = find.text('Paragraph 2 with some prose words.');
      await tester.longPress(target);
      await tester.pumpAndSettle();

      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: target, matching: find.byType(RichText)),
      );
      expect(paragraph.selections, isNotEmpty);
      expect(
        find.descendant(
          of: find.byType(SelectionArea),
          matching: find.byType(SelectableRegion),
        ),
        findsOneWidget,
      );
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

      await tester.tap(find.textContaining('the report', findRichText: true));
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

      await tester.tap(find.text('lib/main.dart'));
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
