import 'package:ccpocket/features/session_list/widgets/session_list_loading_view.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/l10n/app_localizations_delegates.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:skeletonizer/src/widgets/skeletonizer.dart'
    show SkeletonizerScope;

Widget _wrap(ThemeData theme) {
  return MaterialApp(
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    theme: theme,
    home: const Scaffold(
      body: SingleChildScrollView(child: SessionListSkeleton()),
    ),
  );
}

PaintingEffect _resolvedEffect(WidgetTester tester) {
  final scope = tester.widget<SkeletonizerScope>(
    find.byType(SkeletonizerScope),
  );
  return scope.config.effect;
}

void main() {
  // skeletonizer 3 defaults to the platform brightness; the skeleton must
  // follow the app theme instead so a manual light/dark choice is respected.
  testWidgets(
    'uses the dark shimmer for a dark app theme on a light platform',
    (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(_wrap(AppTheme.darkTheme));

      expect(_resolvedEffect(tester), const ShimmerEffect.dark());
    },
  );

  testWidgets(
    'uses the light shimmer for a light app theme on a dark platform',
    (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(_wrap(AppTheme.lightTheme));

      expect(_resolvedEffect(tester), const ShimmerEffect());
    },
  );
}
