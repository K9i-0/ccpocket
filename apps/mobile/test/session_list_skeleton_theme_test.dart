import 'package:ccpocket/features/session_list/widgets/session_list_loading_view.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/l10n/app_localizations_delegates.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Widget _wrap(ThemeData theme, {Widget? child, bool disableAnimations = false}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      theme: theme,
      home: Scaffold(
        body:
            child ?? const SingleChildScrollView(child: SessionListSkeleton()),
      ),
    ),
  );
}

Color _firstBoneColor(WidgetTester tester) {
  final bone = tester
      .widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(ShaderMask).first,
          matching: find.byType(DecoratedBox),
        ),
      )
      .first;
  return (bone.decoration as BoxDecoration).color!;
}

void main() {
  group('SessionListSkeleton theme and shimmer', () {
    // The skeleton must follow the app theme instead of platform brightness
    // so a manual light/dark choice is respected.
    testWidgets(
      'uses the dark shimmer for a dark app theme on a light platform',
      (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue =
            Brightness.light;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

        await tester.pumpWidget(_wrap(AppTheme.darkTheme));
        await tester.pump(const Duration(milliseconds: 350));

        final expected = SessionListSkeleton.shimmerColorsFor(
          AppTheme.darkTheme,
        );
        expect(_firstBoneColor(tester), expected.base);
        expect(expected.base.computeLuminance(), lessThan(0.15));
        expect(expected.highlight.computeLuminance(), lessThan(0.25));
        expect(find.byType(ShaderMask), findsNWidgets(5));
      },
    );

    testWidgets(
      'uses the light shimmer for a light app theme on a dark platform',
      (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

        await tester.pumpWidget(_wrap(AppTheme.lightTheme));
        await tester.pump(const Duration(milliseconds: 350));

        final expected = SessionListSkeleton.shimmerColorsFor(
          AppTheme.lightTheme,
        );
        expect(_firstBoneColor(tester), expected.base);
        expect(expected.base.computeLuminance(), greaterThan(0.6));
        expect(expected.highlight.computeLuminance(), greaterThan(0.8));
        expect(find.byType(ShaderMask), findsNWidgets(5));
      },
    );

    testWidgets('respects reduced motion and disposes cleanly', (tester) async {
      await tester.pumpWidget(
        _wrap(AppTheme.darkTheme, disableAnimations: true),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(SessionListSkeleton), findsOneWidget);
      expect(find.byType(Card), findsNWidgets(5));

      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    });
  });

  group('SessionListLoadingView', () {
    testWidgets('preserves keys and exposes live-region loading semantics', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          _wrap(AppTheme.darkTheme, child: const SessionListLoadingView()),
        );
        await tester.pump();

        expect(
          find.byKey(const ValueKey('session_list_loading')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('session_list_loading_status')),
          findsOneWidget,
        );
        expect(find.byType(SessionListSkeleton), findsOneWidget);
        expect(find.bySemanticsLabel('Loading sessions...'), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    });
  });
}
