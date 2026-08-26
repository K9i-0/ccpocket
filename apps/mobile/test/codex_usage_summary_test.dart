import 'package:ccpocket/features/session_list/widgets/codex_usage_summary.dart';
import 'package:ccpocket/features/session_list/widgets/section_header.dart';
import 'package:ccpocket/features/settings/state/settings_state.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _usage = UsageInfo(
  provider: 'codex',
  fiveHour: UsageWindow(utilization: 32, resetsAt: ''),
  sevenDay: UsageWindow(utilization: 58, resetsAt: ''),
);

Widget _buildSummary(UsageDisplayMode mode, {VoidCallback? onTap}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('ja'),
    theme: AppTheme.darkTheme,
    home: Scaffold(
      body: SizedBox(
        width: 400,
        child: SectionHeader(
          icon: Icons.play_circle_filled,
          label: '実行中',
          color: Colors.green,
          trailing: CodexUsageSummary(
            usage: _usage,
            displayMode: mode,
            onTap: onTap,
          ),
          shrinkTrailingToFit: true,
        ),
      ),
    ),
  );
}

LinearProgressIndicator _indicator(WidgetTester tester, String key) {
  return tester.widget<LinearProgressIndicator>(
    find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byType(LinearProgressIndicator),
    ),
  );
}

void main() {
  group('CodexUsageSummary', () {
    testWidgets('shows compact remaining quota without a Codex icon', (
      tester,
    ) async {
      await tester.pumpWidget(_buildSummary(UsageDisplayMode.remaining));

      expect(find.text('Codex 残量'), findsOneWidget);
      expect(find.text('5h 68%'), findsOneWidget);
      expect(find.text('1w 42%'), findsOneWidget);
      expect(find.byIcon(Icons.code), findsNothing);
      expect(_indicator(tester, 'codex_usage_5h_indicator').value, 0.68);
      expect(_indicator(tester, 'codex_usage_1w_indicator').value, 0.42);
      expect(
        tester.getSemantics(find.byKey(const ValueKey('codex_usage_summary'))),
        matchesSemantics(
          label: 'Codex 残量, 5h 68%, 1w 42%',
          textDirection: TextDirection.ltr,
        ),
      );
    });

    testWidgets('follows the used quota setting', (tester) async {
      await tester.pumpWidget(_buildSummary(UsageDisplayMode.used));

      expect(find.text('Codex 使用量'), findsOneWidget);
      expect(find.text('5h 32%'), findsOneWidget);
      expect(find.text('1w 58%'), findsOneWidget);
      expect(_indicator(tester, 'codex_usage_5h_indicator').value, 0.32);
      expect(_indicator(tester, 'codex_usage_1w_indicator').value, 0.58);
    });

    testWidgets('aligns the summary to the right edge', (tester) async {
      await tester.pumpWidget(_buildSummary(UsageDisplayMode.remaining));

      final summaryRect = tester.getRect(
        find.byKey(const ValueKey('codex_usage_summary')),
      );
      expect(summaryRect.right, closeTo(400, 0.1));
    });

    testWidgets('opens usage settings when tapped', (tester) async {
      var tapCount = 0;
      await tester.pumpWidget(
        _buildSummary(UsageDisplayMode.remaining, onTap: () => tapCount++),
      );

      await tester.tap(
        find.byKey(const ValueKey('codex_usage_summary_button')),
      );

      expect(tapCount, 1);
      expect(
        tester
            .getRect(find.byKey(const ValueKey('codex_usage_summary_button')))
            .height,
        greaterThanOrEqualTo(44),
      );
      expect(
        tester.getSemantics(find.byKey(const ValueKey('codex_usage_summary'))),
        matchesSemantics(
          label: 'Codex 残量, 5h 68%, 1w 42%',
          hint: '利用量の詳細を開く',
          isButton: true,
          textDirection: TextDirection.ltr,
        ),
      );
    });
  });
}
