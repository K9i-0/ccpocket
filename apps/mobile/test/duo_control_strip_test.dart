import 'package:ccpocket/widgets/duo/duo_control_strip.dart';
import 'package:duo_kit/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _iphonePortrait = MediaQueryData(
  size: Size(402, 874),
  padding: EdgeInsets.only(top: 62, bottom: 34),
  viewPadding: EdgeInsets.only(top: 62, bottom: 34),
);

final _poseData = ValueNotifier<MediaQueryData>(FoldTestPose.duoCover.data);

Future<void> _pump(WidgetTester tester, MediaQueryData data, Widget home) {
  _poseData.value = data;
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(951, 951);
  addTearDown(tester.view.reset);
  return tester.pumpWidget(
    ValueListenableBuilder<MediaQueryData>(
      valueListenable: _poseData,
      builder: (context, data, child) => Align(
        alignment: Alignment.topLeft,
        child: SizedBox.fromSize(
          size: data.size,
          child: MediaQuery(data: data, child: child!),
        ),
      ),
      child: MaterialApp(
        builder: (context, child) =>
            DuoStripHost(detectStrip: true, child: child!),
        home: home,
      ),
    ),
  );
}

Future<void> _setPose(WidgetTester tester, MediaQueryData data) async {
  _poseData.value = data;
  await tester.pumpAndSettle();
}

Rect _rectOf(WidgetTester tester, Finder finder) => tester.getRect(finder);

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  var count = 0;

  @override
  Widget build(BuildContext context) => TextButton(
    key: const ValueKey('counter'),
    onPressed: () => setState(() => count++),
    child: Text('count $count'),
  );
}

AppBar _appBar() => AppBar(
  leading: const BackButton(key: ValueKey('leading')),
  title: const Text('Session title'),
  actions: [
    IconButton(
      key: const ValueKey('action_explore'),
      icon: const Icon(Icons.folder_outlined),
      onPressed: () {},
    ),
  ],
);

void main() {
  group('DuoStripHost', () {
    testWidgets('lays the app out beside the strip on the cover display', (
      tester,
    ) async {
      late MediaQueryData childData;
      await _pump(
        tester,
        FoldTestPose.duoCover.data,
        Builder(
          builder: (context) {
            childData = MediaQuery.of(context);
            return const Scaffold(body: SizedBox.expand(key: ValueKey('body')));
          },
        ),
      );

      expect(_rectOf(tester, find.byKey(const ValueKey('body'))).right, 382);
      expect(childData.size.width, 382);
      expect(childData.padding.right, 0);
      expect(childData.viewPadding.right, 0);
      expect(childData.padding.bottom, 34);
      expect(
        _rectOf(
          tester,
          find.byKey(const ValueKey('duo_control_strip_background')),
        ),
        const Rect.fromLTWH(382, 0, 84, 678),
      );
    });

    testWidgets('moves to the left strip on the cover in landscape-left', (
      tester,
    ) async {
      await _pump(
        tester,
        FoldTestPose.duoCoverLandscapeLeft.data,
        const Scaffold(body: SizedBox.expand(key: ValueKey('body'))),
      );

      expect(
        _rectOf(tester, find.byKey(const ValueKey('body'))),
        const Rect.fromLTWH(84, 0, 594, 466),
      );
    });

    for (final (name, data) in [
      ('inner portrait', FoldTestPose.duoInnerPortrait.data),
      ('a regular iPhone', _iphonePortrait),
    ]) {
      testWidgets('leaves $name untouched', (tester) async {
        await _pump(
          tester,
          data,
          const Scaffold(body: SizedBox.expand(key: ValueKey('body'))),
        );

        expect(
          _rectOf(tester, find.byKey(const ValueKey('body'))),
          Offset.zero & data.size,
        );
      });
    }
  });

  group('DuoStripActions', () {
    testWidgets('shows the controls of the screen in the strip', (
      tester,
    ) async {
      await _pump(
        tester,
        FoldTestPose.duoCover.data,
        const DuoStripActions(
          enabled: true,
          top: [Icon(Icons.settings, key: ValueKey('top_item'))],
          bottom: [Icon(Icons.add, key: ValueKey('bottom_item'))],
          child: Scaffold(),
        ),
      );
      await tester.pump();

      final top = _rectOf(tester, find.byKey(const ValueKey('top_item')));
      final bottom = _rectOf(tester, find.byKey(const ValueKey('bottom_item')));
      expect(top.left, greaterThanOrEqualTo(382));
      // Below the status cluster of the cover display.
      expect(top.top, greaterThanOrEqualTo(170));
      expect(bottom.left, greaterThanOrEqualTo(382));
      // Above the home indicator.
      expect(bottom.bottom, lessThanOrEqualTo(678 - 34));
      expect(bottom.top, greaterThan(top.bottom));
    });

    testWidgets('shows nothing without a strip or while disabled', (
      tester,
    ) async {
      await _pump(
        tester,
        _iphonePortrait,
        const DuoStripActions(
          enabled: true,
          top: [Icon(Icons.settings, key: ValueKey('top_item'))],
          child: Scaffold(),
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('top_item')), findsNothing);

      await _pump(
        tester,
        FoldTestPose.duoCover.data,
        const DuoStripActions(
          enabled: false,
          top: [Icon(Icons.settings, key: ValueKey('top_item'))],
          child: Scaffold(),
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('top_item')), findsNothing);
    });

    testWidgets('hands the strip to the route on top and back', (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      _poseData.value = FoldTestPose.duoCover.data;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(951, 951);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ValueListenableBuilder<MediaQueryData>(
          valueListenable: _poseData,
          builder: (context, data, child) => Align(
            alignment: Alignment.topLeft,
            child: SizedBox.fromSize(
              size: data.size,
              child: MediaQuery(data: data, child: child!),
            ),
          ),
          child: MaterialApp(
            navigatorKey: navigatorKey,
            builder: (context, child) =>
                DuoStripHost(detectStrip: true, child: child!),
            home: const DuoStripActions(
              enabled: true,
              top: [Icon(Icons.home, key: ValueKey('first_item'))],
              child: Scaffold(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('first_item')), findsOneWidget);

      navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const DuoStripActions(
            enabled: true,
            top: [Icon(Icons.star, key: ValueKey('second_item'))],
            child: Scaffold(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('first_item')), findsNothing);
      expect(find.byKey(const ValueKey('second_item')), findsOneWidget);

      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('second_item')), findsNothing);
      expect(find.byKey(const ValueKey('first_item')), findsOneWidget);
    });

    testWidgets('keeps the controls visible but inert under a dialog', (
      tester,
    ) async {
      var taps = 0;
      await _pump(
        tester,
        FoldTestPose.duoCover.data,
        Builder(
          builder: (context) => DuoStripActions(
            enabled: true,
            top: [
              IconButton(
                key: const ValueKey('strip_button'),
                icon: const Icon(Icons.settings),
                onPressed: () => taps++,
              ),
            ],
            child: Scaffold(
              body: TextButton(
                key: const ValueKey('open_dialog'),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const AlertDialog(content: Text('dialog')),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const ValueKey('strip_button')));
      expect(taps, 1);

      await tester.tap(find.byKey(const ValueKey('open_dialog')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('strip_button')), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('strip_button')),
        warnIfMissed: false,
      );
      expect(taps, 1);
    });
  });

  group('DuoAdaptiveScaffold', () {
    testWidgets('trades the app bar for a slim header and the strip', (
      tester,
    ) async {
      await _pump(
        tester,
        FoldTestPose.duoCover.data,
        DuoAdaptiveScaffold(appBar: _appBar(), body: const _Counter()),
      );
      await tester.pump();

      expect(find.byType(AppBar), findsNothing);
      expect(find.byKey(const ValueKey('duo_slim_header')), findsOneWidget);
      expect(find.text('Session title'), findsOneWidget);
      for (final key in ['leading', 'action_explore']) {
        expect(
          _rectOf(tester, find.byKey(ValueKey(key))).left,
          greaterThanOrEqualTo(382),
          reason: key,
        );
      }
    });

    testWidgets('keeps the app bar on inner portrait and when not compact', (
      tester,
    ) async {
      await _pump(
        tester,
        FoldTestPose.duoInnerPortrait.data,
        DuoAdaptiveScaffold(appBar: _appBar(), body: const _Counter()),
      );
      await tester.pump();
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byKey(const ValueKey('duo_slim_header')), findsNothing);

      await _pump(
        tester,
        FoldTestPose.duoInnerLandscape.data,
        DuoAdaptiveScaffold(
          appBar: _appBar(),
          useStrip: false,
          body: const _Counter(),
        ),
      );
      await tester.pump();
      expect(find.byType(AppBar), findsOneWidget);
      expect(
        _rectOf(tester, find.byKey(const ValueKey('action_explore'))).right,
        lessThanOrEqualTo(867),
      );
    });

    testWidgets('keeps the body state when the device folds and unfolds', (
      tester,
    ) async {
      await _pump(
        tester,
        FoldTestPose.duoInnerPortrait.data,
        DuoAdaptiveScaffold(appBar: _appBar(), body: const _Counter()),
      );
      await tester.tap(find.byKey(const ValueKey('counter')));
      await tester.pump();
      expect(find.text('count 1'), findsOneWidget);

      await _setPose(tester, FoldTestPose.duoCover.data);
      expect(find.byType(AppBar), findsNothing);
      expect(find.text('count 1'), findsOneWidget);

      await _setPose(tester, FoldTestPose.duoInnerPortrait.data);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('count 1'), findsOneWidget);
    });
  });
}
