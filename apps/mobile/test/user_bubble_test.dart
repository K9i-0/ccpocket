import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/bubbles/user_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? AppTheme.darkTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(body: child),
  );
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}

void main() {
  group('UserBubble selection highlight', () {
    for (final (name, theme) in [
      ('light', AppTheme.lightTheme),
      ('dark', AppTheme.darkTheme),
    ]) {
      testWidgets('is distinguishable from the bubble in $name theme', (
        tester,
      ) async {
        await tester.pumpWidget(
          _wrap(const UserBubble(text: 'Highlight me'), theme: theme),
        );

        final appColors = theme.extension<AppColors>()!;
        final richText = tester.widget<RichText>(
          find.descendant(
            of: find.byType(SelectionArea),
            matching: find.byType(RichText),
          ),
        );
        final selectionColor = richText.selectionColor;
        expect(selectionColor, isNotNull);

        final highlighted = Color.alphaBlend(
          selectionColor!,
          appColors.userBubble,
        );
        // The highlight used to match the bubble (contrast 1.0).
        expect(_contrast(highlighted, appColors.userBubble), greaterThan(1.4));
        // Selected text stays readable on top of the highlight.
        expect(
          _contrast(appColors.userBubbleText, highlighted),
          greaterThan(4.5),
        );
      });
    }
  });

  group('UserBubble text selection and actions', () {
    testWidgets('renders standard and command messages as selectable text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const UserBubble(text: 'Select part of this message')),
      );

      expect(find.byType(SelectionArea), findsOneWidget);
      expect(find.text('Select part of this message'), findsOneWidget);

      const commandText =
          '<command-message><command-name>/review</command-name>'
          '<command-args>current changes</command-args></command-message>';
      await tester.pumpWidget(_wrap(const UserBubble(text: commandText)));

      expect(find.byType(SelectionArea), findsOneWidget);
      expect(
        find.text('/review current changes', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('copy button copies the entire message and confirms', (
      tester,
    ) async {
      String? clipboardText;
      var retryCount = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText = (call.arguments as Map)['text'] as String?;
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

      await tester.pumpWidget(
        _wrap(
          UserBubble(
            text: 'Copy this entire message',
            status: MessageStatus.failed,
            onRetry: () => retryCount++,
          ),
        ),
      );

      // Without edit or rewind there is no overflow menu.
      expect(
        find.byKey(const ValueKey('user_message_edit_button')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('user_message_actions_button')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('user_message_copy_button')));
      await tester.pump();
      expect(clipboardText, 'Copy this entire message');
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(retryCount, 0);

      await tester.pump(const Duration(seconds: 2));
      expect(find.byIcon(Icons.copy_outlined), findsOneWidget);

      await tester.tap(find.text('Copy this entire message'));
      await tester.pump();
      expect(retryCount, 1);
    });

    testWidgets('edit opens an inline editor that resends or cancels', (
      tester,
    ) async {
      final edits = <String>[];
      await tester.pumpWidget(
        _wrap(UserBubble(text: 'fix the tpyo', onEdit: edits.add)),
      );

      await tester.tap(find.byKey(const ValueKey('user_message_edit_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('user_message_editor')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('user_message_edit_cancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('user_message_editor')), findsNothing);
      expect(find.text('fix the tpyo'), findsOneWidget);
      expect(edits, isEmpty);

      await tester.tap(find.byKey(const ValueKey('user_message_edit_button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('user_message_edit_field')),
        '  fix the typo  ',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('user_message_edit_send')));
      await tester.pumpAndSettle();

      expect(edits, ['fix the typo']);
      expect(find.byKey(const ValueKey('user_message_editor')), findsNothing);
    });

    testWidgets('send is disabled for an empty edit', (tester) async {
      await tester.pumpWidget(_wrap(UserBubble(text: 'x', onEdit: (_) {})));
      await tester.tap(find.byKey(const ValueKey('user_message_edit_button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('user_message_edit_field')),
        '   ',
      );
      await tester.pump();
      final send = tester.widget<FilledButton>(
        find.byKey(const ValueKey('user_message_edit_send')),
      );
      expect(send.onPressed, isNull);
    });

    testWidgets('editing closes when edit stops being allowed', (tester) async {
      await tester.pumpWidget(_wrap(UserBubble(text: 'x', onEdit: (_) {})));
      await tester.tap(find.byKey(const ValueKey('user_message_edit_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('user_message_editor')), findsOneWidget);

      await tester.pumpWidget(_wrap(const UserBubble(text: 'x')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('user_message_editor')), findsNothing);
    });

    testWidgets('overflow menu offers file restore', (tester) async {
      var restoreCount = 0;
      await tester.pumpWidget(
        _wrap(
          UserBubble(
            text: 'Restorable message',
            onRestoreFiles: () => restoreCount++,
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('user_message_actions_button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore files to this point'));
      await tester.pumpAndSettle();

      expect(restoreCount, 1);
    });

    testWidgets('action button offers rewind when available', (tester) async {
      var rewindCount = 0;
      await tester.pumpWidget(
        _wrap(
          UserBubble(text: 'Rewindable message', onRewind: () => rewindCount++),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('user_message_actions_button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rewind to here'));
      await tester.pumpAndSettle();

      expect(rewindCount, 1);
    });

    testWidgets('long press is reserved for native text selection', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(UserBubble(text: 'Long press this text', onRewind: () {})),
      );

      await tester.longPress(find.text('Long press this text'));
      await tester.pumpAndSettle();

      final selectionState = tester.state<SelectableRegionState>(
        find.byType(SelectableRegion),
      );
      expect(selectionState.selectionOverlay, isNotNull);
      expect(find.text('Rewind to here'), findsNothing);
    });
  });
}
