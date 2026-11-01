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

    testWidgets('action button copies the entire message', (tester) async {
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

      Widget failedBubble() => _wrap(
        UserBubble(
          text: 'Copy this entire message',
          status: MessageStatus.failed,
          onRetry: () => retryCount++,
        ),
      );

      await tester.pumpWidget(failedBubble());

      final actionIcon = find.byKey(
        const ValueKey('user_message_actions_button'),
      );
      final iconCenter = tester.getCenter(actionIcon);
      final boundaryGesture = await tester.startGesture(
        iconCenter - const Offset(0, 21),
      );
      await boundaryGesture.moveBy(const Offset(0, -2));
      await boundaryGesture.up();
      await tester.pump();

      expect(find.text('Copy entire message'), findsNothing);
      expect(retryCount, 0);

      // The icon stays visually small, but taps just outside its 24x14 layout
      // still land inside the 44px mobile tap target. The upper edge
      // overlaps the failed-message bubble, so it also verifies that retry
      // does not fire from the expanded menu target.
      final menuGesture = await tester.startGesture(
        iconCenter - const Offset(0, 18),
      );
      await tester.pumpWidget(failedBubble());
      await menuGesture.up();
      await tester.pumpAndSettle();

      expect(find.text('Copy entire message'), findsOneWidget);
      expect(find.text('Rewind to here'), findsNothing);
      expect(retryCount, 0);

      await tester.tap(find.text('Copy entire message'));
      await tester.pumpAndSettle();

      expect(clipboardText, 'Copy this entire message');
      expect(find.text('Copied'), findsOneWidget);

      await tester.tap(find.text('Copy this entire message'));
      await tester.pump();
      expect(retryCount, 1);
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
