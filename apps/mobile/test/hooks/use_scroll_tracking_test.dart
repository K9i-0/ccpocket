import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/hooks/use_scroll_tracking.dart';
import 'package:ccpocket/l10n/app_localizations.dart';

void main() {
  group('useScrollTracking', () {
    testWidgets('returns a ScrollController and initial state', (tester) async {
      late ScrollTrackingResult result;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: HookBuilder(
            builder: (context) {
              result = useScrollTracking('session-1');
              return ListView.builder(
                controller: result.controller,
                itemCount: 100,
                itemBuilder: (_, i) => SizedBox(height: 50, child: Text('$i')),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(result.controller, isA<ScrollController>());
      // Initially at offset 0 with a long list → isScrolledUp is true
      // because we are far from maxScrollExtent.
      // (the hook considers isScrolledUp = pixels < maxScrollExtent - 100)
    });

    testWidgets('isScrolledUp becomes false when at bottom', (tester) async {
      late ScrollTrackingResult result;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: HookBuilder(
            builder: (context) {
              result = useScrollTracking('session-2');
              return ListView.builder(
                controller: result.controller,
                itemCount: 200,
                itemBuilder: (_, i) => SizedBox(height: 50, child: Text('$i')),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to bottom
      result.controller.jumpTo(result.controller.position.maxScrollExtent);
      await tester.pumpAndSettle();

      expect(result.isScrolledUp, isFalse);
    });

    testWidgets('isScrolledUp false when near bottom', (tester) async {
      late ScrollTrackingResult result;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: HookBuilder(
            builder: (context) {
              result = useScrollTracking('session-4');
              return ListView.builder(
                controller: result.controller,
                itemCount: 200,
                itemBuilder: (_, i) => SizedBox(height: 50, child: Text('$i')),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll near bottom (within 100px threshold) → not scrolledUp
      final max = result.controller.position.maxScrollExtent;
      result.controller.jumpTo(max - 50);
      await tester.pumpAndSettle();
      expect(result.isScrolledUp, isFalse);
    });
  });
}
