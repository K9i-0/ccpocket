import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/features/chat_session/widgets/context_compaction_card.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/l10n/app_localizations_delegates.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/theme/app_theme.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.darkTheme,
  localizationsDelegates: appLocalizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('shows details, expands the summary and opens the transcript', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      _wrap(
        ContextCompactionCard(
          message: const ContextCompactionMessage(
            provider: 'claude',
            trigger: 'auto',
            preTokens: 182340,
            postTokens: 9120,
            summary: 'Earlier work summary',
          ),
          onOpenTranscript: () => opened++,
        ),
      ),
    );

    expect(find.text('Context compacted'), findsOneWidget);
    expect(find.text('Auto · 182k → 9.1k tokens'), findsOneWidget);
    expect(find.text('Earlier work summary'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('context_compaction_summary_button')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Earlier work summary'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('context_compaction_transcript_button')),
    );
    expect(opened, 1);
  });

  testWidgets('hides summary and transcript actions when unavailable', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const ContextCompactionCard(
          message: ContextCompactionMessage(provider: 'codex'),
        ),
      ),
    );

    expect(find.text('Context compacted'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('context_compaction_summary_button')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('context_compaction_transcript_button')),
      findsNothing,
    );
  });

  testWidgets('older-history card opens the transcript', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      _wrap(OlderHistoryCard(onOpenTranscript: () => opened++)),
    );
    expect(find.text('Older messages are hidden'), findsOneWidget);
    expect(find.text('View earlier messages'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('older_history_transcript_button')),
    );
    expect(opened, 1);
  });

  testWidgets('uses neutral surface while keeping statusCompacting icon', (
    tester,
  ) async {
    for (final theme in [AppTheme.darkTheme, AppTheme.lightTheme]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          themeAnimationDuration: Duration.zero,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(
            body: ContextCompactionCard(
              message: ContextCompactionMessage(provider: 'claude'),
            ),
          ),
        ),
      );

      final cs = theme.colorScheme;
      final appColors = theme.extension<AppColors>()!;
      final expectedBg = theme.brightness == Brightness.dark
          ? cs.surfaceContainerLow
          : cs.surfaceContainerLowest;
      final decoratedBox = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byKey(const ValueKey('context_compaction_card')),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final deco = decoratedBox.decoration as BoxDecoration;
      expect(deco.color, expectedBg);

      final icon = tester.widget<Icon>(find.byIcon(Icons.compress));
      expect(icon.color, appColors.statusCompacting);
    }
  });
}
