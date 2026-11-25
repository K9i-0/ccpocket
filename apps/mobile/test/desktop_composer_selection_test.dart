import 'dart:async';

import 'package:ccpocket/features/chat_session/widgets/queued_input_panel.dart';
import 'package:ccpocket/features/prompt_history/widgets/prompt_history_tile.dart';
import 'package:ccpocket/hooks/use_list_auto_complete.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/l10n/app_localizations_delegates.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/services/prompt_history_service.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/utils/composer_tokens.dart';
import 'package:ccpocket/widgets/chat_input_bar.dart';
import 'package:ccpocket/widgets/slash_command_overlay.dart';
import 'package:ccpocket/widgets/slash_command_sheet.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:patrol_finders/patrol_finders.dart';

import 'chat_screen/helpers/chat_test_helpers.dart';

void main() {
  const nativePasteBridgeChannel = MethodChannel(
    'ccpocket/native_paste_bridge',
  );

  group('ComposerTextEditingController selection & IME', () {
    testWidgets('preserves IME composing underline when there are no tokens', (
      tester,
    ) async {
      final controller = ComposerTextEditingController()
        ..value = const TextEditingValue(
          text: 'にほんご入力',
          selection: TextSelection.collapsed(offset: 4),
          composing: TextRange(start: 0, end: 4),
        );
      addTearDown(controller.dispose);

      TextSpan? span;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              controller.updateTokenState(
                config: const ComposerTokenConfig(provider: Provider.claude),
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

      final leaves = <TextSpan>[];
      span!.visitChildren((child) {
        if (child is TextSpan && (child.text?.isNotEmpty ?? false)) {
          leaves.add(child);
        }
        return true;
      });
      expect(
        leaves.any(
          (leaf) =>
              leaf.text == 'にほんご' &&
              leaf.style?.decoration == TextDecoration.underline,
        ),
        isTrue,
      );
      expect(
        leaves.any(
          (leaf) =>
              leaf.text == '入力' &&
              leaf.style?.decoration != TextDecoration.underline,
        ),
        isTrue,
      );
    });

    testWidgets(
      'uses translucent token backgrounds and omits background inside selection',
      (tester) async {
        final controller = ComposerTextEditingController()
          ..value = const TextEditingValue(
            text: '/review @lib/main.dart',
            selection: TextSelection(baseOffset: 2, extentOffset: 5),
          );
        addTearDown(controller.dispose);

        ComposerTokenPalette? palette;
        TextSpan? span;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Builder(
              builder: (context) {
                palette = ComposerTokenPalette.fromTheme(Theme.of(context));
                controller.updateTokenState(
                  config: const ComposerTokenConfig(
                    provider: Provider.claude,
                    slashCommands: {'/review'},
                    fileMentions: {'lib/main.dart'},
                  ),
                  palette: palette!,
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

        expect(palette!.slashBackground.a, lessThan(1.0));
        expect(palette!.skillBackground.a, lessThan(1.0));
        expect(palette!.fileBackground.a, lessThan(1.0));

        final children = span!.children!.whereType<TextSpan>().toList();
        expect(
          children.any(
            (s) => s.text == '/r' && s.style?.backgroundColor != null,
          ),
          isTrue,
        );
        expect(
          children.any(
            (s) =>
                s.text == 'evi' &&
                s.style?.backgroundColor == null &&
                s.style?.fontWeight == FontWeight.w600,
          ),
          isTrue,
        );
        expect(
          children.any(
            (s) => s.text == 'ew' && s.style?.backgroundColor != null,
          ),
          isTrue,
        );
      },
    );
  });

  group('useListAutoComplete markdown paste safety', () {
    late TextEditingController controller;

    Widget buildHarness(TextEditingController ctrl) {
      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: HookBuilder(
            builder: (context) {
              useListAutoComplete(ctrl);
              return TextField(controller: ctrl, maxLines: 6);
            },
          ),
        ),
      );
    }

    setUp(() {
      controller = TextEditingController();
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets(
      'pasting multiline bullet list ending in newline is unchanged',
      (tester) async {
        await tester.pumpWidget(buildHarness(controller));
        const pasted = '- first item\n- second item\n';
        controller.value = const TextEditingValue(
          text: pasted,
          selection: TextSelection.collapsed(offset: pasted.length),
        );
        await tester.pump();

        expect(controller.text, pasted);
      },
    );

    testWidgets('pasting numbered list ending in newline is unchanged', (
      tester,
    ) async {
      await tester.pumpWidget(buildHarness(controller));
      const pasted = '1. alpha\n2. beta\n';
      controller.value = const TextEditingValue(
        text: pasted,
        selection: TextSelection.collapsed(offset: pasted.length),
      );
      await tester.pump();

      expect(controller.text, pasted);
    });

    testWidgets(
      'replacing selection with list text ending in newline does not rewrite',
      (tester) async {
        await tester.pumpWidget(buildHarness(controller));
        controller.value = const TextEditingValue(
          text: 'abcd',
          selection: TextSelection(baseOffset: 0, extentOffset: 4),
        );
        await tester.pump();

        // Net length grows by exactly 1, but text before cursor changed.
        controller.value = const TextEditingValue(
          text: '- x\n\n',
          selection: TextSelection.collapsed(offset: 4),
        );
        await tester.pump();

        expect(controller.text, '- x\n\n');
      },
    );

    testWidgets('IME composing prevents list rewrite on newline', (
      tester,
    ) async {
      await tester.pumpWidget(buildHarness(controller));
      controller.value = const TextEditingValue(
        text: '- item',
        selection: TextSelection.collapsed(offset: 6),
      );
      await tester.pump();

      controller.value = const TextEditingValue(
        text: '- item\n',
        selection: TextSelection.collapsed(offset: 7),
        composing: TextRange(start: 2, end: 7),
      );
      await tester.pump();

      expect(controller.text, '- item\n');
    });
  });

  group('ChatInputWithOverlays desktop completion ergonomics', () {
    late MockBridgeService bridge;

    setUp(() {
      bridge = MockBridgeService();
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      bridge.dispose();
    });

    TextEditingController inputController(WidgetTester tester) => tester
        .widget<TextField>(find.byKey(const ValueKey('message_input')))
        .controller!;

    patrolWidgetTest(
      'moving cursor inside existing /skill does not open overlay and range selection hides it',
      ($) async {
        await $.pumpWidget(await buildTestChatScreen(bridge: bridge));
        await pumpN($.tester);
        await emitAndPump($.tester, bridge, [
          const StatusMessage(status: ProcessStatus.idle),
          const SystemMessage(
            subtype: 'supported_commands',
            slashCommands: ['review', 'compact'],
            skills: ['review'],
          ),
        ]);
        await pumpN($.tester);

        final ctrl = inputController($.tester);
        await $.tester.enterText(
          find.byKey(const ValueKey('message_input')),
          '/review please check this',
        );
        await pumpN($.tester);
        expect(find.byType(SlashCommandOverlay), findsNothing);

        // Repositioning cursor inside `/review` without editing must not pop
        // up the completion overlay.
        ctrl.selection = const TextSelection.collapsed(offset: 4);
        await pumpN($.tester);
        expect(find.byType(SlashCommandOverlay), findsNothing);

        // Typing `/rev` opens the overlay.
        await $.tester.enterText(
          find.byKey(const ValueKey('message_input')),
          '/rev',
        );
        await pumpN($.tester);
        expect(find.byType(SlashCommandOverlay), findsOneWidget);

        // Selecting a range across `/rev` immediately dismisses the overlay.
        ctrl.selection = const TextSelection(baseOffset: 1, extentOffset: 4);
        await pumpN($.tester);
        expect(find.byType(SlashCommandOverlay), findsNothing);
      },
    );

    patrolWidgetTest(
      'Shift+ArrowDown does not move completion selection while overlay is open',
      ($) async {
        await $.pumpWidget(await buildTestChatScreen(bridge: bridge));
        await pumpN($.tester);
        await emitAndPump($.tester, bridge, [
          const StatusMessage(status: ProcessStatus.idle),
        ]);
        bridge.emitFileList(['a.dart', 'bb.dart', 'ccc.dart']);
        await pumpN($.tester);

        await $.tester.enterText(
          find.byKey(const ValueKey('message_input')),
          '@',
        );
        await pumpN($.tester);
        expect(find.text('a.dart'), findsOneWidget);

        await $.tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await $.tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
        await $.tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
        await $.tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await pumpN($.tester);

        // Pressing Tab should still pick the first item (`a.dart`), proving
        // Shift+ArrowDown was NOT swallowed to advance completion selection.
        await $.tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
        await $.tester.sendKeyUpEvent(LogicalKeyboardKey.tab);
        await pumpN($.tester);

        expect(inputController($.tester).text, '@a.dart ');
      },
    );

    patrolWidgetTest(
      'completion overlay matches composer pane width in multi-pane desktop layout',
      ($) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        try {
          $.tester.view.physicalSize = const Size(1200, 800);
          $.tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            $.tester.view.resetPhysicalSize();
            $.tester.view.resetDevicePixelRatio();
          });

          final screen = await buildTestChatScreen(bridge: bridge);
          await $.pumpWidget(
            Align(
              alignment: Alignment.center,
              child: SizedBox(width: 420, height: 800, child: screen),
            ),
          );
          await pumpN($.tester);
          await emitAndPump($.tester, bridge, [
            const StatusMessage(status: ProcessStatus.idle),
            const SystemMessage(
              subtype: 'supported_commands',
              slashCommands: ['review', 'compact'],
              skills: ['review'],
            ),
          ]);
          await pumpN($.tester);

          await $.tester.enterText(
            find.byKey(const ValueKey('message_input')),
            '/rev',
          );
          await pumpN($.tester);

          final overlayFinder = find.byType(SlashCommandOverlay);
          expect(overlayFinder, findsOneWidget);
          final overlayWidth = $.tester.getSize(overlayFinder).width;
          expect(overlayWidth, closeTo(404, 1));
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  });

  group('ChatInputBar desktop paste, undo & right-click image probe', () {
    late TextEditingController inputController;

    setUp(() {
      inputController = TextEditingController();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            nativePasteBridgeChannel,
            (_) async => null,
          );
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(nativePasteBridgeChannel, null);
      inputController.dispose();
    });

    Future<void> sendNativePaste(String text) async {
      final data = const StandardMethodCodec().encodeMethodCall(
        MethodCall('nativePaste', text),
      );
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage('ccpocket/native_paste_bridge', data, (_) {});
    }

    Widget buildBar({
      Future<void> Function()? onPasteImageFromContextMenu,
      Future<bool> Function()? hasImageInClipboard,
    }) {
      return MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: ChatInputBar(
            inputController: inputController,
            status: ProcessStatus.idle,
            hasInputText: true,
            isInputEmpty: false,
            isVoiceAvailable: false,
            isRecording: false,
            onSend: () {},
            onStop: () {},
            onInterrupt: () {},
            onToggleVoice: () {},
            onIndent: () {},
            onDedent: () {},
            onSlashCommand: () {},
            onMention: () {},
            onPasteImageFromContextMenu: onPasteImageFromContextMenu,
            hasImageInClipboard: hasImageInClipboard,
          ),
        ),
      );
    }

    testWidgets(
      'secondary right-click keeps in-flight image clipboard probe alive on macOS',
      (tester) async {
        final clipboardResult = Completer<bool>();
        await tester.pumpWidget(
          buildBar(
            onPasteImageFromContextMenu: () async {},
            hasImageInClipboard: () => clipboardResult.future,
          ),
        );

        final listener = tester.widget<Listener>(
          find.byKey(const ValueKey('message_input_clipboard_listener')),
        );
        listener.onPointerDown?.call(
          const PointerDownEvent(
            kind: PointerDeviceKind.mouse,
            buttons: kSecondaryMouseButton,
          ),
        );
        listener.onPointerUp?.call(
          const PointerUpEvent(kind: PointerDeviceKind.mouse),
        );
        clipboardResult.complete(true);
        await tester.pump();

        final textField = tester.widget<TextField>(
          find.byKey(const ValueKey('message_input')),
        );
        final editableTextState = tester.state<EditableTextState>(
          find.byType(EditableText),
        );
        final menu = textField.contextMenuBuilder!(
          editableTextState.context,
          editableTextState,
        ) as AdaptiveTextSelectionToolbar;

        expect(
          menu.buttonItems?.where((item) => item.label == 'Paste Image'),
          hasLength(1),
        );
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets(
      'native paste normalizes CRLF line endings and supports Cmd+Z undo',
      (tester) async {
        await tester.pumpWidget(buildBar());
        await tester.tap(find.byKey(const ValueKey('message_input')));
        await tester.pump();

        // Seed initial state and let UndoHistory throttle commit the baseline.
        final editable = tester.state<EditableTextState>(
          find.byType(EditableText),
        );
        editable.userUpdateTextEditingValue(
          const TextEditingValue(
            text: 'before ',
            selection: TextSelection.collapsed(offset: 7),
          ),
          SelectionChangedCause.keyboard,
        );
        await tester.pump(const Duration(milliseconds: 600));

        await sendNativePaste('line1\r\nline2\rline3');
        await tester.pump(const Duration(milliseconds: 600));

        expect(inputController.text, 'before line1\nline2\nline3');

        final textField = tester.widget<TextField>(
          find.byKey(const ValueKey('message_input')),
        );
        expect(textField.undoController, isNotNull);
        expect(textField.undoController!.value.canUndo, isTrue);

        textField.undoController!.undo();
        await tester.pump();

        expect(inputController.text, 'before ');
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets('wraps message input in Scrollbar with explicit controller', (
      tester,
    ) async {
      await tester.pumpWidget(buildBar());

      final textField = tester.widget<TextField>(
        find.byKey(const ValueKey('message_input')),
      );
      final scrollbar = tester.widget<Scrollbar>(
        find.ancestor(
          of: find.byKey(const ValueKey('message_input')),
          matching: find.byType(Scrollbar),
        ),
      );
      expect(textField.scrollController, isNotNull);
      expect(scrollbar.controller, same(textField.scrollController));
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  });

  group('Overlay, Queue & PromptHistory copy polish', () {
    String? copiedText;

    setUp(() {
      copiedText = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copiedText = (call.arguments as Map)['text'] as String?;
            }
            return null;
          });
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets(
      'SlashCommandOverlay shows description tooltip and copies command on desktop',
      (tester) async {
        SlashCommand? selected;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: Scaffold(
              body: SlashCommandOverlay(
                filteredCommands: const [
                  SlashCommand(
                    command: '/release-app',
                    description: 'Bump version and trigger platform release',
                    icon: Icons.extension,
                    category: SlashCommandCategory.skill,
                  ),
                ],
                onSelect: (cmd) => selected = cmd,
                onDismiss: () {},
              ),
            ),
          ),
        );

        final tooltip = tester.widget<Tooltip>(
          find
              .ancestor(
                of: find.byKey(const ValueKey('slash_completion_item_0')),
                matching: find.byType(Tooltip),
              )
              .first,
        );
        expect(
          tooltip.message,
          '/release-app\nBump version and trigger platform release',
        );

        await tester.tap(find.byKey(const ValueKey('slash_completion_copy_0')));
        await tester.pump();
        expect(copiedText, '/release-app');
        expect(selected, isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets(
      'QueuedInputPanel exposes selectable text and copies queued prompt',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: Scaffold(
              body: QueuedInputPanel(
                item: const QueuedInputItem(
                  itemId: 'q-copy',
                  text: 'Queued multiline\nprompt text',
                  createdAt: '2026-11-03T00:00:00Z',
                ),
                onSteer: () {},
                onEdit: () {},
                onCancel: () {},
              ),
            ),
          ),
        );

        expect(
          find.ancestor(
            of: find.text('Queued multiline\nprompt text'),
            matching: find.byType(SelectionArea),
          ),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const ValueKey('codex_queue_copy_button')));
        await tester.pump();
        expect(copiedText, 'Queued multiline\nprompt text');
      },
    );

    testWidgets('PromptHistoryTile copies prompt without triggering onTap', (
      tester,
    ) async {
      var tapped = false;
      final entry = PromptHistoryEntry(
        id: 'ph-1',
        text: 'Long prompt with /skill and markdown\n- item 1',
        projectPath: '/repo',
        useCount: 1,
        isFavorite: false,
        createdAt: DateTime.utc(2026),
        lastUsedAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        commandKind: 'none',
        bridgeIds: const ['bridge-a'],
        bridgeNames: const ['Bridge A'],
        clientStats: const {},
        sessionStats: const {},
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: PromptHistoryTile(
              entry: entry,
              onTap: () => tapped = true,
              onToggleFavorite: () {},
              onDelete: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('prompt_history_copy_ph-1')));
      await tester.pump();
      expect(copiedText, entry.text);
      expect(tapped, isFalse);
    });
  });
}
