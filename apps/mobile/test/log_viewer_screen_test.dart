import 'package:ccpocket/core/logger.dart';
import 'package:ccpocket/features/debug/log_viewer_screen.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('LogViewerScreen', () {
    late AppLogger testLogger;
    String? copiedClipboardText;

    setUp(() {
      testLogger = AppLogger(useConsoleLogs: false);
      copiedClipboardText = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              final args = call.arguments as Map<dynamic, dynamic>;
              copiedClipboardText = args['text'] as String?;
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    Widget buildApp({
      ThemeData? theme,
      Future<void> Function(String text)? onShare,
      TextDirection textDirection = TextDirection.ltr,
    }) {
      return MaterialApp(
        theme: theme ?? AppTheme.lightTheme,
        home: Directionality(
          textDirection: textDirection,
          child: LogViewerScreen(logger: testLogger, onShare: onShare),
        ),
      );
    }

    testWidgets('shows empty state and disables actions when empty', (
      tester,
    ) async {
      await tester.pumpWidget(buildApp());

      expect(
        find.byKey(const ValueKey('log_viewer_empty_state')),
        findsOneWidget,
      );
      expect(find.text('No logs yet'), findsOneWidget);
      expect(find.text('0 / 0'), findsOneWidget);

      final copyBtn = tester.widget<IconButton>(
        find.byKey(const ValueKey('log_viewer_copy_all_button')),
      );
      final shareBtn = tester.widget<IconButton>(
        find.byKey(const ValueKey('log_viewer_share_button')),
      );
      final clearBtn = tester.widget<IconButton>(
        find.byKey(const ValueKey('log_viewer_clear_button')),
      );
      expect(copyBtn.onPressed, isNull);
      expect(shareBtn.onPressed, isNull);
      expect(clearBtn.onPressed, isNull);
    });

    testWidgets('updates live and filters by level and search keyword', (
      tester,
    ) async {
      testLogger.debug('socket tick');
      testLogger.info('session connected');
      testLogger.warning('slow response');
      testLogger.error('bridge timeout', 'TimeoutException');
      testLogger.critical('fatal storage error');

      await tester.pumpWidget(buildApp());

      expect(find.text('5 / 5'), findsOneWidget);
      expect(find.text('fatal storage error'), findsOneWidget);
      expect(find.text('session connected'), findsOneWidget);

      // Live update while screen is open
      testLogger.info('live arrived');
      await tester.pump();
      expect(find.text('6 / 6'), findsOneWidget);
      expect(find.text('live arrived'), findsOneWidget);

      // Filter by Error (includes both error and critical)
      await tester.tap(find.byKey(const ValueKey('log_viewer_filter_error')));
      await tester.pump();
      expect(find.text('2 / 6'), findsOneWidget);
      expect(find.text('bridge timeout'), findsOneWidget);
      expect(find.text('fatal storage error'), findsOneWidget);
      expect(find.text('session connected'), findsNothing);

      // Combine with keyword search
      await tester.enterText(
        find.byKey(const ValueKey('log_viewer_search_field')),
        'timeoutexception',
      );
      await tester.pump();
      expect(find.text('1 / 6'), findsOneWidget);
      expect(find.text('bridge timeout'), findsOneWidget);
      expect(find.text('fatal storage error'), findsNothing);

      // Non-matching search shows filtered empty state
      await tester.enterText(
        find.byKey(const ValueKey('log_viewer_search_field')),
        'does-not-exist',
      );
      await tester.pump();
      expect(find.text('0 / 6'), findsOneWidget);
      expect(find.text('No matching logs'), findsOneWidget);

      // Clear search button restores filtered results
      await tester.tap(find.byKey(const ValueKey('log_viewer_search_clear')));
      await tester.pump();
      expect(find.text('2 / 6'), findsOneWidget);

      // Return to All
      await tester.tap(find.byKey(const ValueKey('log_viewer_filter_all')));
      await tester.pump();
      expect(find.text('6 / 6'), findsOneWidget);
    });

    testWidgets('expands entry to show stack trace and copies single entry', (
      tester,
    ) async {
      final st = StackTrace.fromString('#0 MyService.run (service.dart:99)');
      testLogger.error('Request failed', StateError('offline'), st);
      final entryId = testLogger.entries.single.id;

      await tester.pumpWidget(buildApp());

      expect(find.byKey(ValueKey('log_entry_stack_$entryId')), findsNothing);

      await tester.tap(find.byKey(ValueKey('log_entry_$entryId')));
      await tester.pump();

      expect(find.byKey(ValueKey('log_entry_error_$entryId')), findsOneWidget);
      expect(find.byKey(ValueKey('log_entry_stack_$entryId')), findsOneWidget);
      expect(find.textContaining('service.dart:99'), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('log_entry_copy_$entryId')));
      await tester.pump();

      expect(copiedClipboardText, contains('Request failed'));
      expect(copiedClipboardText, contains('Bad state: offline'));
      expect(copiedClipboardText, contains('service.dart:99'));

      // Tap card again to collapse
      await tester.tap(find.text('Request failed'));
      await tester.pump();
      expect(find.byKey(ValueKey('log_entry_stack_$entryId')), findsNothing);
    });

    testWidgets('copies all, shares, and clears logs', (tester) async {
      String? sharedText;
      testLogger.info('alpha');
      testLogger.warning('beta');

      await tester.pumpWidget(
        buildApp(
          onShare: (text) async {
            sharedText = text;
          },
        ),
      );

      // Copy all
      await tester.tap(
        find.byKey(const ValueKey('log_viewer_copy_all_button')),
      );
      await tester.pump();
      expect(copiedClipboardText, contains('[INFO] alpha'));
      expect(copiedClipboardText, contains('[WARN] beta'));

      // Share
      await tester.tap(find.byKey(const ValueKey('log_viewer_share_button')));
      await tester.pump();
      expect(sharedText, contains('[INFO] alpha'));
      expect(sharedText, contains('[WARN] beta'));

      // Clear
      await tester.tap(find.byKey(const ValueKey('log_viewer_clear_button')));
      await tester.pump();
      expect(testLogger.isEmpty, isTrue);
      expect(find.text('No logs yet'), findsOneWidget);
    });

    testWidgets('renders cleanly in dark theme and RTL and disposes listener', (
      tester,
    ) async {
      testLogger.debug('d');
      testLogger.info('i');
      testLogger.warning('w');
      testLogger.error('e');
      testLogger.critical('c');

      await tester.pumpWidget(
        buildApp(theme: AppTheme.darkTheme, textDirection: TextDirection.rtl),
      );
      expect(find.text('5 / 5'), findsOneWidget);

      // Unmount and emit more logs to verify listener was removed cleanly
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      testLogger.info('after dispose');
      await tester.pump();
      expect(testLogger.length, 6);
    });
  });
}
