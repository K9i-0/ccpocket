import 'package:ccpocket/features/chat_session/widgets/context_compaction_card.dart';
import 'package:ccpocket/features/file_peek/file_peek_sheet.dart';
import 'package:ccpocket/features/git/widgets/diff_hunk_widget.dart';
import 'package:ccpocket/features/github/widgets/github_item_detail_sheet.dart';
import 'package:ccpocket/features/local_bridge/data/local_bridge_models.dart';
import 'package:ccpocket/features/local_bridge/widgets/local_bridge_logs_screen.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/l10n/app_localizations_delegates.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/providers/bridge_cubits.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/theme/markdown_style.dart';
import 'package:ccpocket/utils/diff_parser.dart';
import 'package:ccpocket/widgets/approval_bar.dart';
import 'package:ccpocket/widgets/bubbles/ask_user_question_widget.dart';
import 'package:ccpocket/widgets/bubbles/assistant_bubble.dart';
import 'package:ccpocket/widgets/bubbles/error_bubble.dart';
import 'package:ccpocket/widgets/bubbles/guardian_approval_notice.dart';
import 'package:ccpocket/widgets/bubbles/inline_edit_diff.dart';
import 'package:ccpocket/widgets/bubbles/message_action_bar.dart';
import 'package:ccpocket/widgets/bubbles/permission_request_bubble.dart';
import 'package:ccpocket/widgets/bubbles/plan_card.dart';
import 'package:ccpocket/widgets/bubbles/result_chip.dart';
import 'package:ccpocket/widgets/bubbles/streaming_bubble.dart';
import 'package:ccpocket/widgets/bubbles/swarm_post_card.dart';
import 'package:ccpocket/widgets/bubbles/thinking_bubble.dart';
import 'package:ccpocket/widgets/bubbles/todo_write_widget.dart';
import 'package:ccpocket/widgets/bubbles/tool_result_bubble.dart';
import 'package:ccpocket/widgets/bubbles/tool_use_summary_bubble.dart';
import 'package:ccpocket/widgets/bubbles/user_bubble.dart';
import 'package:ccpocket/widgets/google_search_text_selection.dart';
import 'package:ccpocket/widgets/plan_detail_sheet.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Widget _wrap(Widget child, {List<String> files = const []}) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: BlocProvider<FileListCubit>(
      create: (_) => FileListCubit(files, const Stream.empty()),
      child: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void _mockClipboard(WidgetTester tester, List<String?> captured) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      if (call.method == 'Clipboard.setData') {
        captured.add((call.arguments as Map)['text'] as String?);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
}

void main() {
  group('Cross-block Markdown + Code Block Selection', () {
    testWidgets(
      'AssistantBubble keeps code block inside outer SelectionArea and disables toolbar selection',
      (tester) async {
        const markdown =
            'Intro paragraph.\n\n```dart\nfinal answer = 42;\n```\n\nClosing paragraph.';
        await tester.pumpWidget(
          _wrap(
            const AssistantBubble(
              message: AssistantServerMessage(
                message: AssistantMessage(
                  id: 'm1',
                  role: 'assistant',
                  content: [TextContent(text: markdown)],
                  model: 'claude',
                ),
              ),
            ),
          ),
        );

        expect(find.byType(GoogleSearchSelectionArea), findsOneWidget);
        expect(find.byType(SelectableText), findsNothing);
        expect(
          find.ancestor(
            of: find.byKey(const ValueKey('code_block_language_dart')),
            matching: find.byType(SelectionContainer),
          ),
          findsWidgets,
        );

        // Verify the language label sits inside SelectionContainer.disabled
        // (delegate == null) so it is never copied into the clipboard.
        final containers = tester
            .widgetList<SelectionContainer>(
              find.ancestor(
                of: find.byKey(const ValueKey('code_block_language_dart')),
                matching: find.byType(SelectionContainer),
              ),
            )
            .toList();
        expect(containers.first.delegate, isNull);

        // Verify code block copy button gives inline checkmark feedback.
        final copied = <String?>[];
        _mockClipboard(tester, copied);
        await tester.tap(
          find.byKey(const ValueKey('code_block_copy_button_dart')),
        );
        await tester.pump();
        expect(copied, ['final answer = 42;']);
        expect(find.byIcon(Icons.check), findsOneWidget);
        await tester.pump(const Duration(seconds: 2));
        expect(find.byIcon(Icons.content_copy_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'standalone MarkdownBody without ancestor SelectionArea keeps SelectableText fallback in code blocks',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            Builder(
              builder: (context) => MarkdownBody(
                data: '```dart\nfinal standalone = true;\n```',
                styleSheet: buildMarkdownStyle(context),
                builders: markdownBuilders,
              ),
            ),
          ),
        );

        expect(find.byType(SelectionArea), findsNothing);
        expect(find.byType(SelectableText), findsOneWidget);
      },
    );
  });

  group('Unified Markdown Selection Surfaces', () {
    testWidgets(
      'PlanCard uses GoogleSearchSelectionArea and only opens sheet from header/footer',
      (tester) async {
        var opened = 0;
        final longPlan = List.generate(
          20,
          (i) => '## Section $i\n\nDetailed step $i description.',
        ).join('\n\n');
        await tester.pumpWidget(
          _wrap(PlanCard(planText: longPlan, onViewFullPlan: () => opened++)),
        );
        await tester.pumpAndSettle();

        final md = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
        expect(md.selectable, isFalse);
        expect(find.byType(GoogleSearchSelectionArea), findsOneWidget);

        // Tapping markdown body should NOT open the full plan sheet.
        await tester.tap(find.textContaining('Detailed step 0 description.'));
        await tester.pump();
        expect(opened, 0);

        // Tapping header opens full plan sheet.
        await tester.tap(find.text('Implementation Plan'));
        await tester.pump();
        expect(opened, 1);

        // Tapping footer opens full plan sheet.
        await tester.tap(find.byKey(const ValueKey('view_full_plan_button')));
        await tester.pump();
        expect(opened, 2);
      },
    );

    testWidgets(
      'PlanDetailSheet uses GoogleSearchSelectionArea and header copy button works',
      (tester) async {
        final copied = <String?>[];
        _mockClipboard(tester, copied);
        await tester.pumpWidget(
          _wrap(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () =>
                    showPlanDetailSheet(context, '# Plan\n\nLine 1\n\nLine 2'),
                child: const Text('Open'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        final md = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
        expect(md.selectable, isFalse);
        expect(find.byType(GoogleSearchSelectionArea), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('plan_detail_copy_button')));
        await tester.pump();
        expect(copied, ['# Plan\n\nLine 1\n\nLine 2']);
        expect(find.byIcon(Icons.check), findsOneWidget);
      },
    );

    testWidgets(
      'ResultChip, SwarmPostCard, StreamingBubble, GitHubMarkdown, FilePeekMarkdown, ContextCompactionCard use GoogleSearchSelectionArea',
      (tester) async {
        final scrollController = ScrollController();
        addTearDown(scrollController.dispose);

        await tester.pumpWidget(
          _wrap(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ResultChip(
                  message: ResultMessage(
                    subtype: 'success',
                    result: 'Result paragraph 1\n\nResult paragraph 2',
                  ),
                  showSuccessResultText: true,
                ),
                const SwarmPostCard(
                  input: {
                    'seq': 1,
                    'agent': 'worker',
                    'text': 'Swarm body paragraph 1\n\nParagraph 2',
                  },
                ),
                const StreamingBubble(text: 'Streaming block 1\n\nBlock 2'),
                const GitHubMarkdown(data: 'GitHub body 1\n\nBody 2'),
                SizedBox(
                  height: 120,
                  child: FilePeekMarkdown(
                    content: 'File peek md 1\n\nFile peek md 2',
                    controller: scrollController,
                  ),
                ),
                const ContextCompactionCard(
                  message: ContextCompactionMessage(
                    provider: 'claude',
                    summary: 'Compaction summary text',
                  ),
                ),
              ],
            ),
          ),
        );

        // Expand SwarmPostCard and ContextCompactionCard.
        await tester.tap(find.byKey(const ValueKey('swarm_post_toggle_1')));
        await tester.tap(
          find.byKey(const ValueKey('context_compaction_summary_button')),
        );
        // StreamingBubble runs a repeating cursor animation, so use pump().
        await tester.pump(const Duration(milliseconds: 250));

        final markdownBodies = tester
            .widgetList<MarkdownBody>(find.byType(MarkdownBody))
            .toList();
        expect(markdownBodies, isNotEmpty);
        for (final body in markdownBodies) {
          expect(body.selectable, isFalse);
        }
        expect(find.byType(GoogleSearchSelectionArea), findsNWidgets(6));
      },
    );
  });

  group('Bubble Gesture Isolation & Copy Affordances', () {
    testWidgets(
      'ThinkingBubble expanded body does not collapse on tap and copies via header button',
      (tester) async {
        final copied = <String?>[];
        _mockClipboard(tester, copied);
        await tester.pumpWidget(
          _wrap(
            const ThinkingBubble(
              thinking: 'Deep thought line 1\nDeep thought line 2',
              initiallyExpanded: true,
            ),
          ),
        );

        expect(find.textContaining('Deep thought line 1'), findsOneWidget);
        expect(find.byType(GoogleSearchSelectionArea), findsOneWidget);

        // Tapping expanded body must NOT collapse the bubble.
        await tester.tap(find.textContaining('Deep thought line 1'));
        await tester.pump();
        expect(find.textContaining('Deep thought line 2'), findsOneWidget);

        // Copy button in header copies full thinking text.
        await tester.tap(
          find.byKey(const ValueKey('thinking_bubble_copy_button')),
        );
        await tester.pump();
        expect(copied, ['Deep thought line 1\nDeep thought line 2']);
        expect(find.byIcon(Icons.check), findsOneWidget);

        // Tapping header toggles collapse.
        await tester.tap(find.byKey(const ValueKey('thinking_bubble_toggle')));
        await tester.pump();
        expect(find.byIcon(Icons.expand_more), findsOneWidget);
      },
    );

    testWidgets(
      'ToolUseTile and ToolResultBubble keep expanded body outside toggle InkWell',
      (tester) async {
        final copied = <String?>[];
        _mockClipboard(tester, copied);
        await tester.pumpWidget(
          _wrap(
            const Column(
              children: [
                ToolUseTile(
                  toolUseId: 'tu-1',
                  name: 'Bash',
                  input: {'command': 'echo hello world'},
                ),
                ToolResultBubble(
                  message: ToolResultMessage(
                    toolUseId: 'tu-1',
                    toolName: 'Bash',
                    content: 'hello world output',
                  ),
                ),
              ],
            ),
          ),
        );

        // Expand ToolUseTile twice (collapsed -> preview -> expanded).
        await tester.tap(find.text('Bash').first);
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('tool_use_card_header')));
        await tester.pump();

        // Tapping expanded input body must NOT collapse ToolUseTile.
        await tester.tap(
          find.descendant(
            of: find.byType(GoogleSearchSelectionArea),
            matching: find.text('echo hello world'),
          ),
        );
        await tester.pump();
        expect(find.byKey(const ValueKey('tool_use_copy_button')), findsOne);

        await tester.tap(find.byKey(const ValueKey('tool_use_copy_button')));
        await tester.pump();
        expect(copied.last, contains('echo hello world'));

        // Expand ToolResultBubble twice (collapsed -> preview -> expanded).
        await tester.tap(find.text('hello world output'));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('tool_result_header')));
        await tester.pump();

        // Tapping expanded output text must NOT collapse ToolResultBubble.
        await tester.tap(
          find.descendant(
            of: find.byType(GoogleSearchSelectionArea),
            matching: find.text('hello world output'),
          ),
        );
        await tester.pump();
        expect(find.byKey(const ValueKey('tool_result_copy_button')), findsOne);

        await tester.tap(find.byKey(const ValueKey('tool_result_copy_button')));
        await tester.pump();
        expect(copied.last, 'hello world output');
      },
    );

    testWidgets(
      'UserBubble uses GoogleSearchSelectionArea and desktop editing supports Enter/Shift+Enter/Escape',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);

        final edits = <String>[];
        await tester.pumpWidget(
          _wrap(UserBubble(text: 'Original prompt', onEdit: edits.add)),
        );

        expect(find.byType(GoogleSearchSelectionArea), findsOneWidget);

        // Right-click on the bubble outside text opens bubble action menu.
        final copyButtonPos = tester.getCenter(
          find.byKey(const ValueKey('user_message_copy_button')),
        );
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
        await gesture.down(copyButtonPos);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(find.text('Copy entire message'), findsOneWidget);

        // Dismiss menu.
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();

        // Right-click directly on text lets GoogleSearchSelectionArea handle
        // selection context menu (Copy / Search with Google / Select All)
        // instead of hijacking it with the bubble menu.
        final textCenter = tester.getCenter(find.text('Original prompt'));
        final textRightClick = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
        await textRightClick.down(textCenter);
        await textRightClick.up();
        await tester.pumpAndSettle();
        expect(find.text('Copy entire message'), findsNothing);
        expect(find.text('Search with Google'), findsOneWidget);

        // Dismiss selection context menu.
        final selectionState = tester.state<SelectableRegionState>(
          find.byType(SelectableRegion),
        );
        selectionState.hideToolbar();
        await tester.pumpAndSettle();

        // Open inline editor and test Escape cancels.
        await tester.tap(
          find.byKey(const ValueKey('user_message_edit_button')),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('user_message_editor')), findsOne);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('user_message_editor')), findsNothing);

        // Re-open editor, update text, and press Enter to submit.
        await tester.tap(
          find.byKey(const ValueKey('user_message_edit_button')),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('user_message_edit_field')),
          'Updated prompt',
        );
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(edits, ['Updated prompt']);
        expect(find.byKey(const ValueKey('user_message_editor')), findsNothing);
      },
    );

    testWidgets(
      'MessageActionBar has tooltips on Copy/PlainText/Share and checkmark feedback',
      (tester) async {
        final copied = <String?>[];
        _mockClipboard(tester, copied);
        await tester.pumpWidget(
          _wrap(
            MessageActionBar(textToCopy: 'copy me', onTogglePlainText: () {}),
          ),
        );

        expect(
          find.ancestor(
            of: find.byKey(const ValueKey('copy_button')),
            matching: find.byType(Tooltip),
          ),
          findsOneWidget,
        );
        expect(
          find.ancestor(
            of: find.byKey(const ValueKey('plain_text_toggle')),
            matching: find.byType(Tooltip),
          ),
          findsOneWidget,
        );
        expect(
          find.ancestor(
            of: find.byKey(const ValueKey('share_button')),
            matching: find.byType(Tooltip),
          ),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const ValueKey('copy_button')));
        await tester.pump();
        expect(copied, ['copy me']);
        expect(find.byIcon(Icons.check), findsOneWidget);
      },
    );
  });

  group('Technical Bubbles Selection', () {
    testWidgets(
      'ErrorBubble, PermissionRequestBubble, ApprovalBar, InlineEditDiff, AskUserQuestionWidget, TodoWriteWidget, ToolUseSummaryBubble, GuardianApprovalNotice are selectable',
      (tester) async {
        final feedbackController = TextEditingController();
        addTearDown(feedbackController.dispose);

        await tester.pumpWidget(
          _wrap(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ErrorBubble(
                  message: ErrorMessage(message: 'Something failed'),
                ),
                const PermissionRequestBubble(
                  message: PermissionRequestMessage(
                    toolUseId: 'p1',
                    toolName: 'Bash',
                    input: {'command': 'ls -la'},
                  ),
                ),
                ApprovalBar(
                  appColors: AppTheme.darkTheme.extension<AppColors>()!,
                  pendingPermission: const PermissionRequestMessage(
                    toolUseId: 'p2',
                    toolName: 'Bash',
                    input: {'command': 'git status'},
                  ),
                  isPlanApproval: false,
                  planFeedbackController: feedbackController,
                  onApprove: () {},
                  onReject: () {},
                  onApproveAlways: () {},
                ),
                const InlineEditDiff(
                  diffFile: DiffFile(
                    filePath: 'a.dart',
                    hunks: [
                      DiffHunk(
                        header: '@@ -1 +1 @@',
                        oldStart: 1,
                        newStart: 1,
                        lines: [
                          DiffLine(
                            type: DiffLineType.addition,
                            content: 'final x = 1;',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                AskUserQuestionWidget(
                  toolUseId: 'q1',
                  input: const {
                    'questions': [
                      {
                        'question': 'Which option?',
                        'options': [
                          {'label': 'Option A', 'description': 'First'},
                        ],
                      },
                    ],
                  },
                  onAnswer: (_, _) {},
                ),
                const TodoWriteWidget(
                  input: {
                    'todos': [
                      {
                        'content': 'Write tests',
                        'status': 'in_progress',
                        'activeForm': 'Writing tests',
                      },
                    ],
                  },
                ),
                const ToolUseSummaryBubble(
                  message: ToolUseSummaryMessage(
                    summary: 'Read 3 files',
                    precedingToolUseIds: ['1'],
                  ),
                ),
                const GuardianApprovalNotice(
                  message: GuardianApprovalMessage(
                    risk: GuardianApprovalRisk.medium,
                    reason: 'Safe read-only command',
                  ),
                ),
              ],
            ),
          ),
        );

        // Expand PermissionRequestBubble and GuardianApprovalNotice.
        final permissionInkWell = find.descendant(
          of: find.byType(PermissionRequestBubble),
          matching: find.byType(InkWell),
        );
        await tester.ensureVisible(permissionInkWell);
        await tester.tap(permissionInkWell);
        final guardianButton = find.byKey(
          const ValueKey('guardian_approval_details_button'),
        );
        await tester.ensureVisible(guardianButton);
        await tester.tap(guardianButton);
        await tester.pumpAndSettle();

        expect(find.byType(GoogleSearchSelectionArea), findsNWidgets(8));
      },
    );
  });

  group('FilePeek, Diff, Logs & FilePath Partial Copy', () {
    testWidgets(
      'FilePeekCode separates non-selectable gutter from selectable code without line numbers',
      (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _wrap(
            SizedBox(
              height: 200,
              child: FilePeekCode(
                content: 'final a = 1;\nfinal b = 2;',
                language: 'dart',
                controller: controller,
              ),
            ),
          ),
        );

        final gutterFinder = find.byKey(
          const ValueKey('file_peek_code_gutter'),
        );
        final codeFinder = find.byKey(const ValueKey('file_peek_code_content'));
        expect(gutterFinder, findsOneWidget);
        expect(codeFinder, findsOneWidget);

        // Gutter is wrapped in SelectionContainer.disabled.
        final gutterContainers = tester
            .widgetList<SelectionContainer>(
              find.ancestor(
                of: gutterFinder,
                matching: find.byType(SelectionContainer),
              ),
            )
            .toList();
        expect(gutterContainers.first.delegate, isNull);

        // Code sits inside GoogleSearchSelectionArea and has NO line numbers.
        expect(
          find.ancestor(
            of: codeFinder,
            matching: find.byType(GoogleSearchSelectionArea),
          ),
          findsOneWidget,
        );
        final codeText = tester.widget<Text>(codeFinder);
        final plain = codeText.textSpan!.toPlainText();
        expect(plain, 'final a = 1;\nfinal b = 2;');
      },
    );

    testWidgets(
      'LocalBridgeLogsScreen renders all log lines in a single GoogleSearchSelectionArea for multi-line selection',
      (tester) async {
        final entries = [
          LocalBridgeLogEntry(
            time: DateTime(2026, 1, 1, 10, 0, 1),
            level: 'info',
            message: 'Bridge started',
          ),
          LocalBridgeLogEntry(
            time: DateTime(2026, 1, 1, 10, 0, 2),
            level: 'error',
            message: 'Connection reset',
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: LocalBridgeLogsScreen(loadLogs: () async => entries),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(GoogleSearchSelectionArea), findsOneWidget);
        expect(find.byType(SelectableText), findsNothing);
        expect(
          find.textContaining(
            '10:00:01 Bridge started\n10:00:02 Connection reset',
            findRichText: true,
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'DiffHunkWidget puts gutter in SelectionContainer.disabled and code inside GoogleSearchSelectionArea',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const DiffHunkWidget(
              dismissKey: 'h1',
              lineNumberWidth: 24,
              hunk: DiffHunk(
                header: '@@ -1,2 +1,2 @@',
                oldStart: 1,
                newStart: 1,
                lines: [
                  DiffLine(
                    type: DiffLineType.deletion,
                    oldLineNumber: 1,
                    content: 'oldCode();',
                  ),
                  DiffLine(
                    type: DiffLineType.addition,
                    newLineNumber: 1,
                    content: 'newCode();',
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.byType(GoogleSearchSelectionArea), findsOneWidget);
        expect(
          find.ancestor(
            of: find.text('newCode();'),
            matching: find.byType(GoogleSearchSelectionArea),
          ),
          findsOneWidget,
        );
        // Hunk header sits outside SelectionArea so long-press hunk actions
        // still work and the header is never copied into the clipboard.
        expect(
          find.ancestor(
            of: find.text('@@ -1,2 +1,2 @@'),
            matching: find.byType(GoogleSearchSelectionArea),
          ),
          findsNothing,
        );
        // Gutter line numbers & +/- prefixes sit inside SelectionContainer.disabled.
        final gutterContainers = tester
            .widgetList<SelectionContainer>(
              find.ancestor(
                of: find.text('+'),
                matching: find.byType(SelectionContainer),
              ),
            )
            .toList();
        expect(gutterContainers.first.delegate, isNull);
      },
    );

    testWidgets(
      'FilePathBuilder uses click cursor without breaking SelectionArea',
      (tester) async {
        String? tapped;
        await tester.pumpWidget(
          _wrap(
            AssistantBubble(
              message: const AssistantServerMessage(
                message: AssistantMessage(
                  id: 'fp',
                  role: 'assistant',
                  content: [
                    TextContent(text: 'See `lib/main.dart` for setup.'),
                  ],
                  model: 'claude',
                ),
              ),
              onFileTap: (path) => tapped = path,
            ),
            files: const ['lib/main.dart'],
          ),
        );

        final mouseRegions = tester
            .widgetList<MouseRegion>(
              find.ancestor(
                of: find.text('lib/main.dart'),
                matching: find.byType(MouseRegion),
              ),
            )
            .where((r) => r.cursor == SystemMouseCursors.click);
        expect(mouseRegions, isNotEmpty);

        await tester.tap(find.text('lib/main.dart'));
        await tester.pump();
        expect(tapped, 'lib/main.dart');
      },
    );
  });
}
