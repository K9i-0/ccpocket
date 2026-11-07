import 'package:ccpocket/features/settings/state/settings_cubit.dart';
import 'package:ccpocket/features/settings/widgets/multi_pane_breakpoint_tile.dart';
import 'package:ccpocket/features/workspace/workspace_layout_metrics.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsCubit multi-pane breakpoint', () {
    test('defaults to the three-pane width and persists changes', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final cubit = SettingsCubit(prefs);

      expect(cubit.state.multiPaneBreakpoint, 862);
      expect(kWorkspaceDefaultMultiPaneBreakpoint, kWorkspaceThreePaneMinWidth);

      cubit.setMultiPaneBreakpoint(768);
      expect(cubit.state.multiPaneBreakpoint, 768);
      expect(prefs.getDouble('settings_multi_pane_breakpoint'), 768);
      await cubit.close();

      final restored = SettingsCubit(prefs);
      expect(restored.state.multiPaneBreakpoint, 768);

      // Resetting forgets the override so a future default applies.
      restored.setMultiPaneBreakpoint(kWorkspaceDefaultMultiPaneBreakpoint);
      expect(prefs.containsKey('settings_multi_pane_breakpoint'), isFalse);
      await restored.close();
    });

    test('clamps and snaps stored values', () async {
      SharedPreferences.setMockInitialValues({
        'settings_multi_pane_breakpoint': 100.0,
      });
      final prefs = await SharedPreferences.getInstance();
      final cubit = SettingsCubit(prefs);
      expect(cubit.state.multiPaneBreakpoint, kWorkspaceMinMultiPaneBreakpoint);

      cubit.setMultiPaneBreakpoint(5000);
      expect(cubit.state.multiPaneBreakpoint, kWorkspaceMaxMultiPaneBreakpoint);

      cubit.setMultiPaneBreakpoint(773.4);
      expect(cubit.state.multiPaneBreakpoint, 774);
      await cubit.close();
    });
  });

  group('MultiPaneBreakpointTile', () {
    Future<List<double>> pumpTile(
      WidgetTester tester, {
      required double value,
      Size surface = const Size(773, 900),
    }) async {
      tester.view
        ..physicalSize = surface
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final changes = <double>[];
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ja'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => MultiPaneBreakpointTile(
                value: value,
                onChanged: (next) {
                  changes.add(next);
                  setState(() => value = next);
                },
              ),
            ),
          ),
        ),
      );
      return changes;
    }

    testWidgets('shows the current window width against the threshold', (
      tester,
    ) async {
      await pumpTile(tester, value: 862);
      expect(find.text('862pt'), findsOneWidget);
      expect(find.text('現在の幅 773pt · 1画面表示'), findsOneWidget);
      final reset = tester.widget<TextButton>(
        find.byKey(const ValueKey('multi_pane_breakpoint_reset')),
      );
      expect(reset.onPressed, isNull);
    });

    testWidgets('commits the dragged value only when the drag ends', (
      tester,
    ) async {
      final changes = await pumpTile(tester, value: 862);
      final slider = find.byKey(const ValueKey('multi_pane_breakpoint_slider'));
      final gesture = await tester.startGesture(tester.getCenter(slider));
      await gesture.moveBy(const Offset(-200, 0));
      await tester.pump();
      expect(changes, isEmpty);
      await gesture.up();
      await tester.pump();
      expect(changes, hasLength(1));
      expect(changes.single, lessThan(862));
      expect(find.text('現在の幅 773pt · 分割表示'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('multi_pane_breakpoint_reset')),
      );
      await tester.pump();
      expect(changes.last, kWorkspaceDefaultMultiPaneBreakpoint);
      expect(find.text('862pt'), findsOneWidget);
    });
  });
}
