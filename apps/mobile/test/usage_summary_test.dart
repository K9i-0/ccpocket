import 'package:ccpocket/features/session_list/widgets/usage_summary.dart';
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

const _claudeUsage = UsageInfo(
  provider: 'claude',
  fiveHour: UsageWindow(utilization: 20, resetsAt: ''),
  sevenDay: UsageWindow(utilization: 47, resetsAt: ''),
);

Widget _buildSummary(
  UsageDisplayMode mode, {
  VoidCallback? onTap,
  List<UsageInfo> providers = const [_usage],
  double width = 400,
  double textScale = 1,
}) {
  return MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('ja'),
    theme: AppTheme.darkTheme,
    home: Scaffold(
      body: SizedBox(
        width: width,
        child: Column(
          children: [
            SectionHeader(
              icon: Icons.play_circle_filled,
              label: '実行中',
              color: Colors.green,
              trailing: UsageSummary(
                providers: providers,
                displayMode: mode,
                onTap: onTap,
              ),
              shrinkTrailingToFit: true,
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildPlainHeader() {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    home: const Scaffold(
      body: SizedBox(
        width: 400,
        child: Column(
          children: [
            SectionHeader(
              icon: Icons.play_circle_filled,
              label: '実行中',
              color: Colors.green,
            ),
          ],
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
  group('UsageSummary', () {
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
        tester.getSemantics(find.byKey(const ValueKey('usage_summary'))),
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
        find.byKey(const ValueKey('usage_summary')),
      );
      expect(summaryRect.right, closeTo(400, 0.1));
    });

    testWidgets('does not increase the section header height', (tester) async {
      await tester.pumpWidget(_buildPlainHeader());
      final plainHeight = tester.getSize(find.byType(SectionHeader)).height;

      await tester.pumpWidget(_buildSummary(UsageDisplayMode.remaining));
      final usageHeight = tester.getSize(find.byType(SectionHeader)).height;

      expect(plainHeight, 40);
      expect(usageHeight, plainHeight);
    });

    testWidgets('opens usage settings when tapped', (tester) async {
      var tapCount = 0;
      await tester.pumpWidget(
        _buildSummary(UsageDisplayMode.remaining, onTap: () => tapCount++),
      );

      await tester.tap(find.byKey(const ValueKey('usage_summary_button')));

      expect(tapCount, 1);
      expect(
        tester.getSemantics(find.byKey(const ValueKey('usage_summary'))),
        matchesSemantics(
          label: 'Codex 残量, 5h 68%, 1w 42%',
          hint: '利用量の詳細を開く',
          isButton: true,
          textDirection: TextDirection.ltr,
        ),
      );
    });

    testWidgets('stacks Claude above Codex in smaller text', (tester) async {
      await tester.pumpWidget(
        _buildSummary(
          UsageDisplayMode.remaining,
          providers: const [_usage, _claudeUsage],
        ),
      );

      expect(find.text('残量'), findsOneWidget);
      expect(find.text('Claude'), findsOneWidget);
      expect(find.text('Codex'), findsOneWidget);
      expect(find.text('Codex 残量'), findsNothing);
      final claudeLine = find.byKey(const ValueKey('usage_summary_claude'));
      final codexLine = find.byKey(const ValueKey('usage_summary_codex'));
      expect(
        tester.getCenter(claudeLine).dy,
        lessThan(tester.getCenter(codexLine).dy),
      );
      // Right-aligned so the weekly bars line up.
      expect(
        tester.getRect(claudeLine).right,
        closeTo(tester.getRect(codexLine).right, 0.1),
      );
      expect(tester.widget<Text>(find.text('Claude')).style?.fontSize, 10);
      expect(_indicator(tester, 'claude_usage_5h_indicator').value, 0.8);
      expect(_indicator(tester, 'claude_usage_1w_indicator').value, 0.53);
      expect(_indicator(tester, 'codex_usage_1w_indicator').value, 0.42);
      expect(
        tester.getSemantics(find.byKey(const ValueKey('usage_summary'))),
        matchesSemantics(
          label: '残量, Claude 5h 80% 1w 53%, Codex 5h 68% 1w 42%',
          textDirection: TextDirection.ltr,
        ),
      );
    });

    testWidgets('applies the used setting to both providers', (tester) async {
      await tester.pumpWidget(
        _buildSummary(
          UsageDisplayMode.used,
          providers: const [_claudeUsage, _usage],
        ),
      );

      expect(find.text('使用量'), findsOneWidget);
      expect(_indicator(tester, 'claude_usage_5h_indicator').value, 0.2);
      expect(_indicator(tester, 'codex_usage_5h_indicator').value, 0.32);
    });

    testWidgets('shows Claude alone when only Claude has data', (tester) async {
      await tester.pumpWidget(
        _buildSummary(
          UsageDisplayMode.remaining,
          providers: const [
            _claudeUsage,
            UsageInfo(provider: 'codex', error: 'failed'),
          ],
        ),
      );

      expect(find.text('Claude 残量'), findsOneWidget);
      expect(find.text('Codex'), findsNothing);
    });

    for (final (width, scale) in [(320.0, 1.0), (320.0, 1.6), (200.0, 2.0)]) {
      testWidgets('fits both providers at width $width, scale $scale', (
        tester,
      ) async {
        await tester.pumpWidget(
          _buildSummary(
            UsageDisplayMode.remaining,
            providers: const [_usage, _claudeUsage],
            width: width,
            textScale: scale,
          ),
        );

        expect(tester.takeException(), isNull);
        final summary = tester.getRect(
          find.byKey(const ValueKey('usage_summary')),
        );
        expect(summary.right, lessThanOrEqualTo(width + 0.1));
        if (scale == 1) {
          expect(tester.getSize(find.byType(SectionHeader)).height, 40);
        }
      });
    }
  });
}
