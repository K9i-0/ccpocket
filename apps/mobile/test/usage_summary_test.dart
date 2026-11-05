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
      // The weekly window is left to the settings card when 5h exists.
      expect(find.text('1w 42%'), findsNothing);
      expect(find.byIcon(Icons.code), findsNothing);
      expect(_indicator(tester, 'codex_usage_5h_indicator').value, 0.68);
      expect(
        find.byKey(const ValueKey('codex_usage_1w_indicator')),
        findsNothing,
      );
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
      expect(find.text('1w 58%'), findsNothing);
      expect(_indicator(tester, 'codex_usage_5h_indicator').value, 0.32);
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

    testWidgets('lists Claude then Codex on one line', (tester) async {
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
        closeTo(tester.getCenter(codexLine).dy, 0.1),
      );
      expect(
        tester.getRect(claudeLine).right,
        lessThan(tester.getRect(codexLine).left),
      );
      expect(tester.widget<Text>(find.text('Claude')).style?.fontSize, 11);
      expect(_indicator(tester, 'claude_usage_5h_indicator').value, 0.8);
      expect(_indicator(tester, 'codex_usage_5h_indicator').value, 0.68);
      expect(
        find.byKey(const ValueKey('claude_usage_1w_indicator')),
        findsNothing,
      );
      // Screen readers still get every window.
      expect(
        tester.getSemantics(find.byKey(const ValueKey('usage_summary'))),
        matchesSemantics(
          label: '残量, Claude 5h 80% 1w 53%, Codex 5h 68% 1w 42%',
          textDirection: TextDirection.ltr,
        ),
      );
    });

    testWidgets('falls back to the weekly window without 5h', (tester) async {
      await tester.pumpWidget(
        _buildSummary(
          UsageDisplayMode.remaining,
          providers: const [
            _claudeUsage,
            UsageInfo(
              provider: 'codex',
              sevenDay: UsageWindow(utilization: 58, resetsAt: ''),
            ),
          ],
        ),
      );

      expect(_indicator(tester, 'claude_usage_5h_indicator').value, 0.8);
      expect(_indicator(tester, 'codex_usage_1w_indicator').value, 0.42);
      expect(find.text('1w 42%'), findsOneWidget);
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

    testWidgets('switches to an exhausted weekly window', (tester) async {
      await tester.pumpWidget(
        _buildSummary(
          UsageDisplayMode.remaining,
          providers: const [
            UsageInfo(
              provider: 'codex',
              fiveHour: UsageWindow(utilization: 0, resetsAt: ''),
              sevenDay: UsageWindow(utilization: 100, resetsAt: ''),
            ),
          ],
        ),
      );

      expect(find.text('1w 0%'), findsOneWidget);
      expect(find.text('5h 100%'), findsNothing);
      expect(
        find.byKey(const ValueKey('codex_usage_5h_indicator')),
        findsNothing,
      );
      final indicator = _indicator(tester, 'codex_usage_1w_indicator');
      expect(indicator.value, 0);
      final context = tester.element(find.text('1w 0%'));
      expect(
        (indicator.valueColor! as AlwaysStoppedAnimation<Color?>).value,
        Theme.of(context).colorScheme.error,
      );
      // Screen readers still hear both windows.
      expect(
        tester.getSemantics(find.byKey(const ValueKey('usage_summary'))),
        matchesSemantics(
          label: 'Codex 残量, 5h 100%, 1w 0%',
          textDirection: TextDirection.ltr,
        ),
      );
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

  group('usageSummaryWindow', () {
    String pick(double fiveHourUsed, double weeklyUsed) => usageSummaryWindow(
      UsageInfo(
        provider: 'claude',
        fiveHour: UsageWindow(utilization: fiveHourUsed, resetsAt: ''),
        sevenDay: UsageWindow(utilization: weeklyUsed, resetsAt: ''),
      ),
    ).label;

    test('keeps 5h while the weekly quota is healthy', () {
      // Weekly usage is cumulative and usually ahead of 5h.
      expect(pick(10, 12), '5h');
      expect(pick(20, 69), '5h');
    });

    test('switches to 1w at the warning band when it is tighter', () {
      expect(pick(20, 70), '1w');
      expect(pick(0, 100), '1w');
    });

    test('keeps 5h when it is tighter than a low weekly quota', () {
      expect(pick(90, 80), '5h');
    });

    test('uses 1w when 5h is unavailable', () {
      expect(
        usageSummaryWindow(
          const UsageInfo(
            provider: 'codex',
            sevenDay: UsageWindow(utilization: 5, resetsAt: ''),
          ),
        ).label,
        '1w',
      );
    });
  });
}
