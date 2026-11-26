// Edge autoscroll during selection drags: the pure tick function, the
// Scrollable-backed target (AxisDirection.down and .up) and the drags wired
// by MarkdownSelectionScope.
//
// Gap inventory against the reference suite (flutter_md, MIT), by test name:
//
// selection/selection_autoscroll_test.dart
//   (a) already covered: arming gate blocks scroll after a hard stop until
//       leave and re-enter (selection_handles_gesture_test "disarms per
//       direction ...").
//   (b) ported: zero in the middle of the clip [high]; top / bottom band
//       direction [high]; disabled config returns zero [high]; mid-viewport
//       host does not fire at the scrollable bottom [high]; suppresses when
//       the host top is already visible [high]; scrolls when the host
//       extends past the pad [high]; overshoot past the outer edge keeps
//       scrolling [medium].
//   (c) ported with a different expectation: "quadratic depth" - markdown_kit
//       ramps with ratio * (0.5 + 0.5 * ratio) (selection_autoscroll.dart),
//       so the tests assert monotonic growth, the cap and the endpoints
//       instead of the reference numbers. "useMediaQueryPadding uses
//       viewPadding" - markdown_kit documents MediaQuery.padding
//       (MarkdownSelectionAutoscrollConfig.useMediaQueryPadding).
//
// selection/selection_autoscroll_target_test.dart
//   (b) ported: padding deflates the padded bounds [medium]; padding taller
//       than the viewport is not usable [medium]; canScroll false suppresses
//       and disarms [high]; a flush target suppresses and disarms [high];
//       padding moves the activation band inward [high]; a null viewport
//       idles without touching the target [high]; host union gate applies to
//       a custom target / useHostUnionGate false lets the target decide
//       [high]; a disabled config never resolves a target [medium]; forward
//       and reverse lists keep the screen-space sign [high]; an unmounted
//       scrollable reports no viewport [high]; a custom scroll protocol is
//       driven by a selection drag [high]; the resolver is not re-run on
//       every frame [medium]; a zero max velocity never drives the host
//       [medium]; a resolver returning null leaves the host unscrolled
//       [medium]; without a resolver the enclosing ListView is driven [high].
//   Missing, not ported: "a non-finite viewport is not usable" (no stated
//       contract for non-finite rects in MarkdownAutoscrollViewport, so no
//       expected value to assert); "a scope rebuild during a drag does not
//       re-resolve the target" (only the per-frame case is covered here).
//
// selection/selection_autoscroll_regressions_test.dart
//   (b) ported: edge bands never overlap past half the viewport [high];
//       pointer cancel mid-drag stops autoscroll [high]; pointer event rate
//       does not multiply scroll speed [high]; a horizontal inner scrollable
//       is not driven [medium]; an infinite edge zone yields a finite
//       velocity [low]; config equality covers every field [low]; disposing
//       the scope mid-drag stops autoscroll [high].
//
// selection/selection_chrome_test.dart ("autoscroll through virtualization")
//   (b) ported: dragging to the edge builds and selects new messages [high];
//       the ticker stops when the drag ends [high].
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_kit/markdown_kit.dart';

/// Scripted scroll host: `pixels` grows as content below is revealed.
class _FakeHost {
  _FakeHost({
    this.pixels = 0,
    this.max = 1000,
    this.viewport = const MarkdownAutoscrollViewport(
      rect: Rect.fromLTWH(0, 0, 400, 600),
    ),
    this.stuck = false,
  });

  double pixels;
  double max;
  MarkdownAutoscrollViewport? viewport;

  /// Reports that it can scroll but never applies a delta.
  bool stuck;

  int viewportReads = 0;
  int canScrollQueries = 0;
  final List<double> requested = <double>[];

  late final MarkdownCallbackAutoscrollTarget target =
      MarkdownCallbackAutoscrollTarget(
        viewportProvider: () {
          viewportReads++;
          return viewport;
        },
        canScrollUpCallback: () {
          canScrollQueries++;
          return stuck || pixels > 0;
        },
        canScrollDownCallback: () {
          canScrollQueries++;
          return stuck || pixels < max;
        },
        onScrollVisualDelta: (dy) {
          requested.add(dy);
          if (stuck) return 0;
          final before = pixels;
          pixels = (pixels + dy).clamp(0.0, max);
          return pixels - before;
        },
      );
}

const _frame = Duration(milliseconds: 16);

double _tick(
  _FakeHost host,
  double pointerY, {
  MarkdownAutoscrollSession? session,
  Duration dt = _frame,
  MarkdownSelectionAutoscrollConfig config =
      const MarkdownSelectionAutoscrollConfig(),
  Rect? hostBounds,
}) {
  return applyMarkdownSelectionAutoscroll(
    target: host.target,
    session: session ?? MarkdownAutoscrollSession(),
    globalPointer: Offset(200, pointerY),
    dt: dt,
    config: config,
    hostBounds: hostBounds,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('applyMarkdownSelectionAutoscroll bands', () {
    // Viewport 0..600, default edgeZone 48: top band y < 48, bottom y > 552.
    test('a pointer in the middle of the viewport is idle', () {
      final host = _FakeHost(pixels: 300);
      expect(_tick(host, 300), 0.0);
      expect(_tick(host, 48), 0.0);
      expect(_tick(host, 552), 0.0);
      expect(host.requested, isEmpty);
    });

    test('the bottom band reveals content below (positive delta)', () {
      final host = _FakeHost(pixels: 300);
      final applied = _tick(host, 590);
      expect(applied, greaterThan(0));
      expect(host.pixels, 300 + applied);
    });

    test('the top band reveals content above (negative delta)', () {
      final host = _FakeHost(pixels: 300);
      final applied = _tick(host, 10);
      expect(applied, lessThan(0));
      expect(host.pixels, 300 + applied);
    });

    test('speed grows monotonically with depth into the bottom band', () {
      var previous = 0.0;
      for (final y in <double>[556, 564, 576, 588, 600]) {
        final applied = _tick(_FakeHost(pixels: 300), y);
        expect(applied, greaterThan(previous), reason: 'y=$y');
        previous = applied;
      }
    });

    test('speed grows monotonically with depth into the top band', () {
      var previous = 0.0;
      for (final y in <double>[44, 36, 24, 12, 0]) {
        final applied = -_tick(_FakeHost(pixels: 300), y);
        expect(applied, greaterThan(previous), reason: 'y=$y');
        previous = applied;
      }
    });

    test('the outer edge scrolls at exactly maxVelocity', () {
      const config = MarkdownSelectionAutoscrollConfig(maxVelocity: 500);
      final down = _tick(
        _FakeHost(pixels: 300),
        600,
        config: config,
        dt: const Duration(milliseconds: 20),
      );
      expect(down, moreOrLessEquals(10.0, epsilon: 1e-9));
      final up = _tick(
        _FakeHost(pixels: 300),
        0,
        config: config,
        dt: const Duration(milliseconds: 20),
      );
      expect(up, moreOrLessEquals(-10.0, epsilon: 1e-9));
    });

    test('a pointer far outside the viewport keeps scrolling at the cap', () {
      const config = MarkdownSelectionAutoscrollConfig(maxVelocity: 500);
      const dt = Duration(milliseconds: 20);
      expect(
        _tick(_FakeHost(pixels: 300), 5000, config: config, dt: dt),
        moreOrLessEquals(10.0, epsilon: 1e-9),
      );
      expect(
        _tick(_FakeHost(pixels: 300), -5000, config: config, dt: dt),
        moreOrLessEquals(-10.0, epsilon: 1e-9),
      );
    });

    test('a long frame is clamped to 100ms of travel', () {
      const config = MarkdownSelectionAutoscrollConfig(maxVelocity: 500);
      final oneSecond = _tick(
        _FakeHost(pixels: 300),
        600,
        config: config,
        dt: const Duration(seconds: 1),
      );
      expect(oneSecond, moreOrLessEquals(50.0, epsilon: 1e-9));
    });

    test('a zero or negative dt does nothing', () {
      final host = _FakeHost(pixels: 300);
      expect(_tick(host, 600, dt: Duration.zero), 0.0);
      expect(_tick(host, 600, dt: const Duration(milliseconds: -16)), 0.0);
      expect(host.requested, isEmpty);
    });

    test('edge bands never overlap past half the viewport', () {
      // 60px viewport with a 48px zone: each band is capped at 30px.
      final viewport = const MarkdownAutoscrollViewport(
        rect: Rect.fromLTWH(0, 100, 400, 60),
      );
      expect(_tick(_FakeHost(pixels: 300, viewport: viewport), 130), 0.0);
      expect(
        _tick(_FakeHost(pixels: 300, viewport: viewport), 129),
        lessThan(0),
      );
      expect(
        _tick(_FakeHost(pixels: 300, viewport: viewport), 131),
        greaterThan(0),
      );
    });

    test('an infinite edge zone yields a finite velocity', () {
      const config = MarkdownSelectionAutoscrollConfig(
        edgeZone: double.infinity,
      );
      final applied = _tick(_FakeHost(pixels: 300), 590, config: config);
      expect(applied.isFinite, isTrue);
      expect(applied, greaterThan(0));
      expect(applied, lessThanOrEqualTo(600 * 0.016 + 1e-9));
    });

    test('a zero edge zone never scrolls', () {
      const config = MarkdownSelectionAutoscrollConfig(edgeZone: 0);
      final host = _FakeHost(pixels: 300);
      expect(_tick(host, 600, config: config), 0.0);
      expect(_tick(host, 0, config: config), 0.0);
      expect(host.requested, isEmpty);
    });

    test('a zero max velocity never drives the target', () {
      const config = MarkdownSelectionAutoscrollConfig(maxVelocity: 0);
      final host = _FakeHost(pixels: 300);
      expect(_tick(host, 600, config: config), 0.0);
      expect(_tick(host, 0, config: config), 0.0);
      expect(host.pixels, 300);
    });

    test('a disabled config returns zero without touching the target', () {
      const config = MarkdownSelectionAutoscrollConfig(enabled: false);
      final host = _FakeHost(pixels: 300);
      expect(_tick(host, 600, config: config), 0.0);
      expect(_tick(host, 0, config: config), 0.0);
      expect(host.viewportReads, 0);
      expect(host.canScrollQueries, 0);
      expect(host.requested, isEmpty);
    });
  });

  group('applyMarkdownSelectionAutoscroll viewport and insets', () {
    test('a null viewport idles without touching the target', () {
      final host = _FakeHost(pixels: 300, viewport: null);
      final session = MarkdownAutoscrollSession();
      expect(_tick(host, 600, session: session), 0.0);
      expect(host.canScrollQueries, 0);
      expect(host.requested, isEmpty);
      expect(session.isDownDisarmed, isFalse);
    });

    test('an empty viewport idles without touching the target', () {
      final host = _FakeHost(
        pixels: 300,
        viewport: const MarkdownAutoscrollViewport(
          rect: Rect.fromLTWH(0, 0, 400, 0),
        ),
      );
      expect(_tick(host, 0), 0.0);
      expect(host.requested, isEmpty);
    });

    test('insets as tall as the viewport leave nothing usable', () {
      final host = _FakeHost(
        pixels: 300,
        viewport: const MarkdownAutoscrollViewport(
          rect: Rect.fromLTWH(0, 0, 400, 600),
          topInset: 300,
          bottomInset: 300,
        ),
      );
      expect(_tick(host, 0), 0.0);
      expect(_tick(host, 300), 0.0);
      expect(_tick(host, 600), 0.0);
      expect(host.requested, isEmpty);
    });

    test('insets deflate the effective bounds', () {
      const viewport = MarkdownAutoscrollViewport(
        rect: Rect.fromLTWH(0, 50, 400, 600),
        topInset: 80,
        bottomInset: 120,
      );
      expect(viewport.effectiveTop, 130);
      expect(viewport.effectiveBottom, 530);
    });

    test('a top inset moves the top band inward', () {
      const inset = MarkdownAutoscrollViewport(
        rect: Rect.fromLTWH(0, 0, 400, 600),
        topInset: 100,
      );
      // Band is 100..148 with the inset; y = 120 is idle without it.
      expect(_tick(_FakeHost(pixels: 300), 120), 0.0);
      expect(_tick(_FakeHost(pixels: 300, viewport: inset), 120), lessThan(0));
      expect(_tick(_FakeHost(pixels: 300, viewport: inset), 148), 0.0);
    });

    test('a bottom inset moves the bottom band inward', () {
      const inset = MarkdownAutoscrollViewport(
        rect: Rect.fromLTWH(0, 0, 400, 600),
        bottomInset: 100,
      );
      // Band is 452..500 with the inset; y = 480 is idle without it.
      expect(_tick(_FakeHost(pixels: 300), 480), 0.0);
      expect(
        _tick(_FakeHost(pixels: 300, viewport: inset), 480),
        greaterThan(0),
      );
      expect(_tick(_FakeHost(pixels: 300, viewport: inset), 452), 0.0);
    });

    test('a pointer over the inset itself scrolls at the cap', () {
      const config = MarkdownSelectionAutoscrollConfig(maxVelocity: 500);
      const inset = MarkdownAutoscrollViewport(
        rect: Rect.fromLTWH(0, 0, 400, 600),
        topInset: 100,
        bottomInset: 100,
      );
      const dt = Duration(milliseconds: 20);
      expect(
        _tick(
          _FakeHost(pixels: 300, viewport: inset),
          550,
          config: config,
          dt: dt,
        ),
        moreOrLessEquals(10.0, epsilon: 1e-9),
      );
      expect(
        _tick(
          _FakeHost(pixels: 300, viewport: inset),
          50,
          config: config,
          dt: dt,
        ),
        moreOrLessEquals(-10.0, epsilon: 1e-9),
      );
    });

    test('viewport equality covers every field', () {
      const base = MarkdownAutoscrollViewport(
        rect: Rect.fromLTWH(0, 0, 400, 600),
        topInset: 1,
        bottomInset: 2,
      );
      const same = MarkdownAutoscrollViewport(
        rect: Rect.fromLTWH(0, 0, 400, 600),
        topInset: 1,
        bottomInset: 2,
      );
      expect(base, same);
      expect(base.hashCode, same.hashCode);
      final variants = <MarkdownAutoscrollViewport>[
        const MarkdownAutoscrollViewport(
          rect: Rect.fromLTWH(0, 1, 400, 600),
          topInset: 1,
          bottomInset: 2,
        ),
        const MarkdownAutoscrollViewport(
          rect: Rect.fromLTWH(0, 0, 400, 600),
          topInset: 3,
          bottomInset: 2,
        ),
        const MarkdownAutoscrollViewport(
          rect: Rect.fromLTWH(0, 0, 400, 600),
          topInset: 1,
          bottomInset: 3,
        ),
        const MarkdownAutoscrollViewport(
          rect: Rect.fromLTWH(0, 0, 400, 600),
          topInset: 1,
          bottomInset: 2,
          axis: Axis.horizontal,
        ),
      ];
      for (final variant in variants) {
        expect(variant, isNot(base));
      }
    });
  });

  group('applyMarkdownSelectionAutoscroll stops and gates', () {
    test('a target that cannot scroll down suppresses and disarms down', () {
      final host = _FakeHost(pixels: 1000, max: 1000);
      final session = MarkdownAutoscrollSession();
      expect(_tick(host, 590, session: session), 0.0);
      expect(session.isDownDisarmed, isTrue);
      expect(session.isUpDisarmed, isFalse);
      expect(host.requested, isEmpty);
    });

    test('a target that cannot scroll up suppresses and disarms up', () {
      final host = _FakeHost(pixels: 0);
      final session = MarkdownAutoscrollSession();
      expect(_tick(host, 10, session: session), 0.0);
      expect(session.isUpDisarmed, isTrue);
      expect(session.isDownDisarmed, isFalse);
      expect(host.requested, isEmpty);
    });

    test('a flush target (zero applied delta) disarms that direction', () {
      final host = _FakeHost(pixels: 300, stuck: true);
      final session = MarkdownAutoscrollSession();
      expect(_tick(host, 590, session: session), 0.0);
      expect(host.requested, hasLength(1));
      expect(session.isDownDisarmed, isTrue);

      // Still in the band: not asked again.
      expect(_tick(host, 595, session: session), 0.0);
      expect(host.requested, hasLength(1));
    });

    test('reaching the end mid-tick applies the remainder then disarms', () {
      final host = _FakeHost(pixels: 998, max: 1000);
      final session = MarkdownAutoscrollSession();
      expect(_tick(host, 600, session: session), 2.0);
      expect(host.pixels, 1000);
      expect(session.isDownDisarmed, isTrue);
    });

    test('session.reset re-arms both directions', () {
      final host = _FakeHost(pixels: 0, max: 0);
      final session = MarkdownAutoscrollSession();
      _tick(host, 10, session: session);
      expect(session.isUpDisarmed, isTrue);
      session.reset();
      expect(session.isUpDisarmed, isFalse);
      expect(session.isDownDisarmed, isFalse);
    });

    test('a disarmed direction does not block the opposite one', () {
      final host = _FakeHost(pixels: 0);
      final session = MarkdownAutoscrollSession();
      expect(_tick(host, 10, session: session), 0.0);
      expect(session.isUpDisarmed, isTrue);
      expect(_tick(host, 590, session: session), greaterThan(0));
    });

    test('host content that ends above the bottom band does not scroll', () {
      final host = _FakeHost(pixels: 300);
      final session = MarkdownAutoscrollSession();
      expect(
        _tick(
          host,
          590,
          session: session,
          hostBounds: const Rect.fromLTRB(0, 100, 400, 400),
        ),
        0.0,
      );
      expect(host.requested, isEmpty);
      // The gate is not a hard stop: content may grow into the band later.
      expect(session.isDownDisarmed, isFalse);
    });

    test('host content that reaches into the bottom band scrolls', () {
      final host = _FakeHost(pixels: 300);
      expect(
        _tick(host, 590, hostBounds: const Rect.fromLTRB(0, 100, 400, 900)),
        greaterThan(0),
      );
    });

    test('host content whose top is already visible does not scroll up', () {
      final host = _FakeHost(pixels: 300);
      final session = MarkdownAutoscrollSession();
      expect(
        _tick(
          host,
          10,
          session: session,
          hostBounds: const Rect.fromLTRB(0, 200, 400, 900),
        ),
        0.0,
      );
      expect(host.requested, isEmpty);
      expect(session.isUpDisarmed, isFalse);
    });

    test('host content that extends above the top band scrolls up', () {
      final host = _FakeHost(pixels: 300);
      expect(
        _tick(host, 10, hostBounds: const Rect.fromLTRB(0, -300, 400, 400)),
        lessThan(0),
      );
    });

    test('the host gate is measured against the inset band', () {
      const inset = MarkdownAutoscrollViewport(
        rect: Rect.fromLTWH(0, 0, 400, 600),
        bottomInset: 100,
      );
      // Band starts at 452. Host ending at 470 reaches into it; 440 does not.
      expect(
        _tick(
          _FakeHost(pixels: 300, viewport: inset),
          480,
          hostBounds: const Rect.fromLTRB(0, 100, 400, 470),
        ),
        greaterThan(0),
      );
      expect(
        _tick(
          _FakeHost(pixels: 300, viewport: inset),
          480,
          hostBounds: const Rect.fromLTRB(0, 100, 400, 440),
        ),
        0.0,
      );
    });

    test('useHostUnionGate false lets the target decide', () {
      const config = MarkdownSelectionAutoscrollConfig(useHostUnionGate: false);
      const short = Rect.fromLTRB(0, 200, 400, 400);
      expect(
        _tick(_FakeHost(pixels: 300), 590, config: config, hostBounds: short),
        greaterThan(0),
      );
      expect(
        _tick(_FakeHost(pixels: 300), 10, config: config, hostBounds: short),
        lessThan(0),
      );
    });

    test('useHostUnionGate false still stops on a target at its end', () {
      const config = MarkdownSelectionAutoscrollConfig(useHostUnionGate: false);
      final host = _FakeHost(pixels: 1000, max: 1000);
      final session = MarkdownAutoscrollSession();
      expect(_tick(host, 590, session: session, config: config), 0.0);
      expect(session.isDownDisarmed, isTrue);
    });

    test('null host bounds leave the gate open', () {
      expect(_tick(_FakeHost(pixels: 300), 590), greaterThan(0));
      expect(_tick(_FakeHost(pixels: 300), 10), lessThan(0));
    });
  });

  group('MarkdownSelectionAutoscrollConfig', () {
    MarkdownAutoscrollTarget? resolverA(BuildContext c, Offset p) => null;
    MarkdownAutoscrollTarget? resolverB(BuildContext c, Offset p) => null;

    test('equality and hashCode cover every field', () {
      final base = MarkdownSelectionAutoscrollConfig(targetResolver: resolverA);
      final same = MarkdownSelectionAutoscrollConfig(targetResolver: resolverA);
      expect(base, same);
      expect(base.hashCode, same.hashCode);

      final variants = <MarkdownSelectionAutoscrollConfig>[
        base.copyWith(enabled: false),
        base.copyWith(edgeZone: 49),
        base.copyWith(maxVelocity: 601),
        base.copyWith(topPad: 1),
        base.copyWith(bottomPad: 1),
        base.copyWith(useMediaQueryPadding: false),
        base.copyWith(useHostUnionGate: false),
        base.copyWith(targetResolver: resolverB),
      ];
      for (var i = 0; i < variants.length; i++) {
        expect(variants[i], isNot(base), reason: 'variant $i');
      }
    });

    test('copyWith without arguments is an equal copy', () {
      final base = MarkdownSelectionAutoscrollConfig(
        enabled: false,
        edgeZone: 10,
        maxVelocity: 20,
        topPad: 30,
        bottomPad: 40,
        useMediaQueryPadding: false,
        useHostUnionGate: false,
        targetResolver: resolverA,
      );
      expect(base.copyWith(), base);
    });

    test('defaults', () {
      const config = MarkdownSelectionAutoscrollConfig();
      expect(config.enabled, isTrue);
      expect(config.topPad, 0);
      expect(config.bottomPad, 0);
      expect(config.useMediaQueryPadding, isTrue);
      expect(config.useHostUnionGate, isTrue);
      expect(config.targetResolver, isNull);
    });
  });

  _scrollableTargetTests();
  _scopeDragTests();
}

Widget _testApp({
  required Widget child,
  MediaQueryData mediaQuery = const MediaQueryData(size: Size(800, 600)),
}) {
  return Directionality(
    key: UniqueKey(),
    textDirection: ui.TextDirection.ltr,
    child: MediaQuery(
      data: mediaQuery,
      child: FocusScope(
        autofocus: true,
        child: Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (_) =>
                  ColoredBox(color: const Color(0xFFFFFFFF), child: child),
            ),
          ],
        ),
      ),
    ),
  );
}

void _scrollableTargetTests() {
  group('MarkdownScrollableAutoscrollTarget', () {
    Future<ScrollController> pumpList(
      WidgetTester tester, {
      bool reverse = false,
      MediaQueryData mediaQuery = const MediaQueryData(size: Size(800, 600)),
      EdgeInsets outer = EdgeInsets.zero,
    }) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        _testApp(
          mediaQuery: mediaQuery,
          child: Padding(
            padding: outer,
            child: ListView(
              controller: scroll,
              reverse: reverse,
              children: [
                for (var i = 0; i < 40; i++)
                  SizedBox(height: 50, child: Text('row $i')),
              ],
            ),
          ),
        ),
      );
      return scroll;
    }

    ScrollableState scrollableOf(WidgetTester tester) =>
        tester.state<ScrollableState>(find.byType(Scrollable));

    testWidgets('a forward list at its start can only scroll down', (
      tester,
    ) async {
      await pumpList(tester);
      final target = MarkdownScrollableAutoscrollTarget(
        scrollable: scrollableOf(tester),
      );
      expect(target.canScrollUp(), isFalse);
      expect(target.canScrollDown(), isTrue);
    });

    testWidgets('a forward list maps a positive visual delta to higher '
        'pixels', (tester) async {
      final scroll = await pumpList(tester);
      final target = MarkdownScrollableAutoscrollTarget(
        scrollable: scrollableOf(tester),
      );
      expect(target.scrollByVisualDelta(120), 120);
      expect(scroll.position.pixels, 120);
      expect(target.canScrollUp(), isTrue);
      expect(target.scrollByVisualDelta(-20), -20);
      expect(scroll.position.pixels, 100);
    });

    testWidgets('a forward list clamps at both ends and reports what was '
        'applied', (tester) async {
      final scroll = await pumpList(tester);
      final target = MarkdownScrollableAutoscrollTarget(
        scrollable: scrollableOf(tester),
      );
      expect(target.scrollByVisualDelta(-50), 0);
      final max = scroll.position.maxScrollExtent;
      scroll.jumpTo(max - 30);
      expect(target.scrollByVisualDelta(100), moreOrLessEquals(30));
      expect(scroll.position.pixels, max);
      expect(target.canScrollDown(), isFalse);
      expect(target.scrollByVisualDelta(100), 0);
    });

    testWidgets('a reverse list at rest can only scroll up', (tester) async {
      await pumpList(tester, reverse: true);
      final target = MarkdownScrollableAutoscrollTarget(
        scrollable: scrollableOf(tester),
      );
      expect(scrollableOf(tester).axisDirection, AxisDirection.up);
      expect(target.canScrollUp(), isTrue);
      expect(target.canScrollDown(), isFalse);
    });

    testWidgets('a reverse list keeps the screen-space sign: a negative '
        'visual delta raises pixels', (tester) async {
      final scroll = await pumpList(tester, reverse: true);
      final target = MarkdownScrollableAutoscrollTarget(
        scrollable: scrollableOf(tester),
      );
      final rowTopBefore = tester.getTopLeft(find.text('row 3')).dy;

      expect(target.scrollByVisualDelta(-120), -120);
      await tester.pump();
      expect(scroll.position.pixels, 120);
      // Revealing content above moves existing rows DOWN the screen.
      expect(tester.getTopLeft(find.text('row 3')).dy, rowTopBefore + 120);
      expect(target.canScrollDown(), isTrue);

      expect(target.scrollByVisualDelta(20), 20);
      expect(scroll.position.pixels, 100);
    });

    testWidgets('a reverse list clamps at both ends', (tester) async {
      final scroll = await pumpList(tester, reverse: true);
      final target = MarkdownScrollableAutoscrollTarget(
        scrollable: scrollableOf(tester),
      );
      expect(target.scrollByVisualDelta(50), 0);
      final max = scroll.position.maxScrollExtent;
      scroll.jumpTo(max - 30);
      expect(target.scrollByVisualDelta(-100), moreOrLessEquals(-30));
      expect(scroll.position.pixels, max);
      expect(target.canScrollUp(), isFalse);
    });

    testWidgets('the viewport is the scrollable rect in global coordinates', (
      tester,
    ) async {
      await pumpList(tester, outer: const EdgeInsets.fromLTRB(10, 60, 30, 90));
      final viewport = MarkdownScrollableAutoscrollTarget(
        scrollable: scrollableOf(tester),
      ).viewport()!;
      expect(viewport.rect, const Rect.fromLTRB(10, 60, 770, 510));
      expect(viewport.topInset, 0);
      expect(viewport.bottomInset, 0);
    });

    testWidgets('topPad and bottomPad become viewport insets', (tester) async {
      await pumpList(tester);
      final viewport = MarkdownScrollableAutoscrollTarget(
        scrollable: scrollableOf(tester),
        topPad: 56,
        bottomPad: 84,
      ).viewport()!;
      expect(viewport.topInset, 56);
      expect(viewport.bottomInset, 84);
      expect(viewport.effectiveTop, 56);
      expect(viewport.effectiveBottom, 600 - 84);
    });

    testWidgets('MediaQuery.padding that overlaps the viewport is added to '
        'the insets', (tester) async {
      await pumpList(
        tester,
        mediaQuery: const MediaQueryData(
          size: Size(800, 600),
          padding: EdgeInsets.only(top: 44, bottom: 34),
        ),
      );
      final viewport = MarkdownScrollableAutoscrollTarget(
        scrollable: scrollableOf(tester),
        topPad: 10,
        bottomPad: 20,
      ).viewport()!;
      expect(viewport.topInset, 54);
      expect(viewport.bottomInset, 54);
    });

    testWidgets('MediaQuery.padding already cleared by the layout is not '
        'added again', (tester) async {
      await pumpList(
        tester,
        mediaQuery: const MediaQueryData(
          size: Size(800, 600),
          padding: EdgeInsets.only(top: 44, bottom: 34),
        ),
        outer: const EdgeInsets.only(top: 44, bottom: 34),
      );
      final viewport = MarkdownScrollableAutoscrollTarget(
        scrollable: scrollableOf(tester),
      ).viewport()!;
      expect(viewport.topInset, 0);
      expect(viewport.bottomInset, 0);
    });

    testWidgets('useMediaQueryPadding false ignores the safe area', (
      tester,
    ) async {
      await pumpList(
        tester,
        mediaQuery: const MediaQueryData(
          size: Size(800, 600),
          padding: EdgeInsets.only(top: 44, bottom: 34),
        ),
      );
      final viewport = MarkdownScrollableAutoscrollTarget(
        scrollable: scrollableOf(tester),
        useMediaQueryPadding: false,
      ).viewport()!;
      expect(viewport.topInset, 0);
      expect(viewport.bottomInset, 0);
    });

    testWidgets('an unmounted scrollable reports no viewport and cannot '
        'scroll', (tester) async {
      await pumpList(tester);
      final target = MarkdownScrollableAutoscrollTarget(
        scrollable: scrollableOf(tester),
      );
      await tester.pumpWidget(const SizedBox());

      expect(target.viewport(), isNull);
      final session = MarkdownAutoscrollSession();
      expect(
        applyMarkdownSelectionAutoscroll(
          target: target,
          session: session,
          globalPointer: const Offset(100, 595),
          dt: _frame,
        ),
        0.0,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('resolve finds the enclosing vertical Scrollable from a '
        'descendant context', (tester) async {
      await pumpList(tester);
      final context = tester.element(find.text('row 2'));
      final target = MarkdownScrollableAutoscrollTarget.resolve(
        context,
        globalPointer: Offset.zero,
        config: const MarkdownSelectionAutoscrollConfig(
          topPad: 7,
          bottomPad: 9,
        ),
      );
      expect(target, isA<MarkdownScrollableAutoscrollTarget>());
      final resolved = target! as MarkdownScrollableAutoscrollTarget;
      expect(resolved.scrollable, same(scrollableOf(tester)));
      expect(resolved.topPad, 7);
      expect(resolved.bottomPad, 9);
    });

    testWidgets('resolve finds a Scrollable below the context when none '
        'encloses it', (tester) async {
      await pumpList(tester);
      final context = tester.element(find.byType(ListView));
      final target = MarkdownScrollableAutoscrollTarget.resolve(
        context,
        globalPointer: Offset.zero,
      );
      expect(
        (target! as MarkdownScrollableAutoscrollTarget).scrollable,
        same(scrollableOf(tester)),
      );
    });

    testWidgets('resolve returns null when there is no Scrollable', (
      tester,
    ) async {
      await tester.pumpWidget(_testApp(child: const Text('plain')));
      expect(
        MarkdownScrollableAutoscrollTarget.resolve(
          tester.element(find.text('plain')),
          globalPointer: Offset.zero,
        ),
        isNull,
      );
    });

    testWidgets('resolve skips a horizontal inner scrollable', (tester) async {
      final vertical = ScrollController();
      addTearDown(vertical.dispose);
      await tester.pumpWidget(
        _testApp(
          child: ListView(
            controller: vertical,
            children: [
              SizedBox(
                height: 80,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: const [SizedBox(width: 2000, child: Text('wide'))],
                ),
              ),
              const SizedBox(height: 3000),
            ],
          ),
        ),
      );
      final target = MarkdownScrollableAutoscrollTarget.resolve(
        tester.element(find.text('wide')),
        globalPointer: Offset.zero,
      );
      final resolved = target! as MarkdownScrollableAutoscrollTarget;
      expect(resolved.scrollable.position, same(vertical.position));
    });

    testWidgets('resolve uses the targetResolver when one is configured', (
      tester,
    ) async {
      await pumpList(tester);
      final custom = _FakeHost().target;
      Offset? seenPointer;
      final target = MarkdownScrollableAutoscrollTarget.resolve(
        tester.element(find.text('row 2')),
        globalPointer: const Offset(12, 34),
        config: MarkdownSelectionAutoscrollConfig(
          targetResolver: (context, pointer) {
            seenPointer = pointer;
            return custom;
          },
        ),
      );
      expect(target, same(custom));
      expect(seenPointer, const Offset(12, 34));
    });
  });
}

MarkdownDocument _doc(List<String> paragraphs) => MarkdownDocument(
  blocks: [
    for (final p in paragraphs) ParagraphBlock(inlines: [TextInline(p)]),
  ],
);

RenderSelectableParagraph _paragraph(WidgetTester tester, String substring) {
  for (final element in find.bySubtype<RichText>().evaluate()) {
    final ro = element.renderObject;
    if (ro is RenderSelectableParagraph &&
        ro.attached &&
        ro.baseText.toPlainText().contains(substring)) {
      return ro;
    }
  }
  throw StateError('no paragraph containing "$substring"');
}

Offset _glyphCenter(RenderSelectableParagraph p, int index) {
  final box = p.boxesForLocalRange(index, index + 1).first.toRect();
  return p.localToGlobal(box.center);
}

/// 40 one-paragraph messages (`m00`..`m39`, "message NN body text"), each
/// 48px tall, in a virtualized ListView that fills the 800x600 test surface.
class _Chat {
  _Chat(this.controller, this.scroll);
  final MarkdownSelectionController controller;
  final ScrollController scroll;

  double get pixels => scroll.position.pixels;
}

String _id(int i) => 'm${i.toString().padLeft(2, '0')}';
String _body(int i) => 'message ${i.toString().padLeft(2, '0')} body text';

Future<_Chat> _pumpChat(
  WidgetTester tester, {
  bool reverse = false,
  MarkdownSelectionAutoscrollConfig autoscroll =
      const MarkdownSelectionAutoscrollConfig(),
  bool allowCrossDocumentSelection = true,
  double initialPixels = 0,
  int count = 40,
  double trailingFiller = 0,
}) async {
  final controller = MarkdownSelectionController(
    allowCrossDocumentSelection: allowCrossDocumentSelection,
  );
  addTearDown(controller.dispose);
  final scroll = ScrollController(initialScrollOffset: initialPixels);
  addTearDown(scroll.dispose);
  await tester.pumpWidget(
    _testApp(
      child: MarkdownSelectionScope(
        controller: controller,
        autoscroll: autoscroll,
        child: ListView.builder(
          controller: scroll,
          reverse: reverse,
          itemCount: count + (trailingFiller > 0 ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= count) return SizedBox(height: trailingFiller);
            return SizedBox(
              height: 48,
              child: Align(
                alignment: Alignment.centerLeft,
                child: MarkdownView(
                  document: _doc([_body(index)]),
                  documentId: _id(index),
                  // Reading order runs top to bottom on screen in both list
                  // directions.
                  documentOrder: reverse ? count - index : index,
                  theme: MarkdownThemeData.fallback(),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
  await tester.pump();
  return _Chat(controller, scroll);
}

/// Presses the mouse on [from] and drags to [to] without releasing.
Future<TestGesture> _mouseDragTo(
  WidgetTester tester,
  Offset from,
  Offset to,
) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: from);
  await tester.pump();
  await mouse.down(from);
  await tester.pump();
  await mouse.moveTo(Offset.lerp(from, to, 0.5)!);
  await tester.pump();
  await mouse.moveTo(to);
  await tester.pump();
  return mouse;
}

Future<void> _holdFrames(WidgetTester tester, int frames) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(_frame);
  }
}

void _onDesktop(
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await body(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

void _scopeDragTests() {
  group('Selection drags drive the enclosing list', () {
    _onDesktop('a mouse drag held in the bottom band scrolls down, builds '
        'new messages and selects into them', (tester) async {
      final chat = await _pumpChat(tester);
      expect(find.text(_body(20), findRichText: true), findsNothing);
      final from = _glyphCenter(_paragraph(tester, _body(2)), 0);
      final mouse = await _mouseDragTo(tester, from, Offset(from.dx + 60, 590));
      expect(chat.pixels, 0, reason: 'no scroll before a frame elapses');

      await _holdFrames(tester, 60);
      expect(chat.pixels, greaterThan(100));
      final selection = chat.controller.normalizedSelection!;
      expect(selection.start.documentId, _id(2));
      // Messages 0..12 fit on the first screen; the extent must have moved
      // onto a message that did not exist before the scroll.
      expect(selection.end.documentId.compareTo(_id(12)), greaterThan(0));

      await mouse.up();
      await tester.pump();
    });

    _onDesktop('a mouse drag held in the top band scrolls back up', (
      tester,
    ) async {
      final chat = await _pumpChat(tester, initialPixels: 600);
      final from = _glyphCenter(_paragraph(tester, _body(20)), 3);
      final mouse = await _mouseDragTo(tester, from, Offset(from.dx, 6));

      await _holdFrames(tester, 60);
      expect(chat.pixels, lessThan(500));
      final selection = chat.controller.normalizedSelection!;
      expect(selection.end.documentId, _id(20));
      expect(selection.start.documentId.compareTo(_id(12)), lessThan(0));

      await mouse.up();
      await tester.pump();
    });

    _onDesktop('a pointer resting mid-viewport does not scroll', (
      tester,
    ) async {
      final chat = await _pumpChat(tester, initialPixels: 300);
      final from = _glyphCenter(_paragraph(tester, _body(8)), 0);
      final mouse = await _mouseDragTo(tester, from, Offset(from.dx + 40, 300));

      await _holdFrames(tester, 30);
      expect(chat.pixels, 300);
      expect(chat.controller.hasSelection, isTrue);

      await mouse.up();
      await tester.pump();
    });

    _onDesktop('scrolling stops when the drag ends and no ticker is left '
        'running', (tester) async {
      final chat = await _pumpChat(tester);
      final from = _glyphCenter(_paragraph(tester, _body(2)), 0);
      final mouse = await _mouseDragTo(tester, from, Offset(from.dx + 60, 590));
      await _holdFrames(tester, 20);
      expect(chat.pixels, greaterThan(0));

      await mouse.up();
      await tester.pump();
      final settled = chat.pixels;
      final text = chat.controller.getText();
      await _holdFrames(tester, 20);
      expect(chat.pixels, settled);
      expect(chat.controller.getText(), text);
      expect(tester.binding.transientCallbackCount, 0);
    });

    _onDesktop('a pointer cancel mid-drag stops scrolling and keeps the '
        'selection', (tester) async {
      final chat = await _pumpChat(tester);
      final from = _glyphCenter(_paragraph(tester, _body(2)), 0);
      final mouse = await _mouseDragTo(tester, from, Offset(from.dx + 60, 590));
      await _holdFrames(tester, 20);
      expect(chat.pixels, greaterThan(0));

      await mouse.cancel();
      await tester.pump();
      final settled = chat.pixels;
      await _holdFrames(tester, 20);
      expect(chat.pixels, settled);
      expect(chat.controller.hasSelection, isTrue);
      expect(tester.binding.transientCallbackCount, 0);
    });

    _onDesktop('the scroll distance does not depend on the pointer event '
        'rate', (tester) async {
      Future<double> run({required int movesPerFrame}) async {
        final chat = await _pumpChat(tester);
        final from = _glyphCenter(_paragraph(tester, _body(2)), 0);
        final hold = Offset(from.dx + 60, 580);
        final mouse = await _mouseDragTo(tester, from, hold);
        for (var frame = 0; frame < 30; frame++) {
          for (var i = 0; i < movesPerFrame; i++) {
            await mouse.moveTo(hold + Offset(i.isEven ? 1 : -1, 0));
          }
          await tester.pump(_frame);
        }
        final pixels = chat.pixels;
        await mouse.up();
        await mouse.removePointer();
        await tester.pump();
        return pixels;
      }

      final quiet = await run(movesPerFrame: 0);
      final busy = await run(movesPerFrame: 8);
      expect(quiet, greaterThan(0));
      expect(busy, moreOrLessEquals(quiet, epsilon: 0.01));
    });

    _onDesktop('a disabled config never scrolls but the drag still selects', (
      tester,
    ) async {
      final chat = await _pumpChat(
        tester,
        autoscroll: const MarkdownSelectionAutoscrollConfig(enabled: false),
      );
      final from = _glyphCenter(_paragraph(tester, _body(2)), 0);
      final mouse = await _mouseDragTo(tester, from, Offset(from.dx + 60, 590));
      await _holdFrames(tester, 30);
      expect(chat.pixels, 0);
      expect(chat.controller.hasSelection, isTrue);
      expect(tester.binding.transientCallbackCount, 0);

      await mouse.up();
      await tester.pump();
    });

    _onDesktop('a zero max velocity never scrolls', (tester) async {
      final chat = await _pumpChat(
        tester,
        autoscroll: const MarkdownSelectionAutoscrollConfig(maxVelocity: 0),
      );
      final from = _glyphCenter(_paragraph(tester, _body(2)), 0);
      final mouse = await _mouseDragTo(tester, from, Offset(from.dx + 60, 590));
      await _holdFrames(tester, 30);
      expect(chat.pixels, 0);

      await mouse.up();
      await tester.pump();
    });

    _onDesktop('disposing the scope mid-drag does not throw', (tester) async {
      final chat = await _pumpChat(tester);
      final from = _glyphCenter(_paragraph(tester, _body(2)), 0);
      final mouse = await _mouseDragTo(tester, from, Offset(from.dx + 60, 590));
      await _holdFrames(tester, 10);
      expect(chat.pixels, greaterThan(0));

      await tester.pumpWidget(const SizedBox());
      await _holdFrames(tester, 5);
      await mouse.up();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.binding.transientCallbackCount, 0);
    });
  });

  group('Selection drags in a reverse list (AxisDirection.up)', () {
    _onDesktop('a mouse drag held in the top band raises pixels and '
        'reveals earlier messages', (tester) async {
      final chat = await _pumpChat(tester, reverse: true);
      // In a reverse list index 0 is at the bottom; message 05 is on screen.
      final from = _glyphCenter(_paragraph(tester, _body(5)), 3);
      final mouse = await _mouseDragTo(tester, from, Offset(from.dx, 6));

      await _holdFrames(tester, 60);
      expect(chat.pixels, greaterThan(100));
      final selection = chat.controller.normalizedSelection!;
      // Reading order is top to bottom, so the dragged end is the START.
      expect(selection.end.documentId, _id(5));
      expect(selection.start.documentId.compareTo(_id(12)), greaterThan(0));

      await mouse.up();
      await tester.pump();
    });

    _onDesktop('a mouse drag held in the bottom band lowers pixels', (
      tester,
    ) async {
      final chat = await _pumpChat(tester, reverse: true, initialPixels: 600);
      final from = _glyphCenter(_paragraph(tester, _body(20)), 0);
      final mouse = await _mouseDragTo(tester, from, Offset(from.dx + 60, 594));

      await _holdFrames(tester, 60);
      expect(chat.pixels, lessThan(500));

      await mouse.up();
      await tester.pump();
    });

    _onDesktop('at rest the bottom band of a reverse list has nowhere to '
        'go', (tester) async {
      final chat = await _pumpChat(tester, reverse: true);
      final from = _glyphCenter(_paragraph(tester, _body(5)), 0);
      final mouse = await _mouseDragTo(tester, from, Offset(from.dx + 60, 594));

      await _holdFrames(tester, 30);
      expect(chat.pixels, 0);

      await mouse.up();
      await tester.pump();
    });
  });

  group('Pads and the host gate at the scope', () {
    _onDesktop('topPad moves the top band below a floating header', (
      tester,
    ) async {
      Future<double> run(double topPad) async {
        final chat = await _pumpChat(
          tester,
          initialPixels: 600,
          autoscroll: MarkdownSelectionAutoscrollConfig(topPad: topPad),
        );
        final from = _glyphCenter(_paragraph(tester, _body(20)), 3);
        // y = 110 is outside the natural band (0..48) but inside 100..148.
        final mouse = await _mouseDragTo(tester, from, Offset(from.dx, 110));
        await _holdFrames(tester, 40);
        final pixels = chat.pixels;
        await mouse.up();
        await mouse.removePointer();
        await tester.pump();
        return pixels;
      }

      expect(await run(0), 600);
      expect(await run(100), lessThan(600));
    });

    _onDesktop('bottomPad moves the bottom band above a composer bar', (
      tester,
    ) async {
      Future<double> run(double bottomPad) async {
        final chat = await _pumpChat(
          tester,
          autoscroll: MarkdownSelectionAutoscrollConfig(bottomPad: bottomPad),
        );
        final from = _glyphCenter(_paragraph(tester, _body(2)), 0);
        // y = 490 is outside the natural band (552..600) but inside 452..500.
        final mouse = await _mouseDragTo(
          tester,
          from,
          Offset(from.dx + 60, 490),
        );
        await _holdFrames(tester, 40);
        final pixels = chat.pixels;
        await mouse.up();
        await mouse.removePointer();
        await tester.pump();
        return pixels;
      }

      expect(await run(0), 0);
      expect(await run(100), greaterThan(0));
    });

    _onDesktop('with the host gate a short document does not drag the list '
        'past its own end', (tester) async {
      // Three messages (144px) followed by 3000px of non-selectable filler.
      final chat = await _pumpChat(tester, count: 3, trailingFiller: 3000);
      final from = _glyphCenter(_paragraph(tester, _body(0)), 0);
      final mouse = await _mouseDragTo(tester, from, Offset(from.dx + 60, 590));

      await _holdFrames(tester, 40);
      expect(chat.pixels, 0);
      expect(chat.controller.getText(), contains(_body(2)));

      await mouse.up();
      await tester.pump();
    });

    _onDesktop('useHostUnionGate false scrolls the same layout', (
      tester,
    ) async {
      final chat = await _pumpChat(
        tester,
        count: 3,
        trailingFiller: 3000,
        autoscroll: const MarkdownSelectionAutoscrollConfig(
          useHostUnionGate: false,
        ),
      );
      final from = _glyphCenter(_paragraph(tester, _body(0)), 0);
      final mouse = await _mouseDragTo(tester, from, Offset(from.dx + 60, 590));

      await _holdFrames(tester, 40);
      expect(chat.pixels, greaterThan(0));

      await mouse.up();
      await tester.pump();
    });
  });

  group('Custom autoscroll targets at the scope', () {
    _onDesktop('a targetResolver target is driven instead of the list', (
      tester,
    ) async {
      final host = _FakeHost(pixels: 300);
      final chat = await _pumpChat(
        tester,
        autoscroll: MarkdownSelectionAutoscrollConfig(
          useHostUnionGate: false,
          targetResolver: (context, pointer) => host.target,
        ),
      );
      final from = _glyphCenter(_paragraph(tester, _body(2)), 0);
      final mouse = await _mouseDragTo(tester, from, Offset(from.dx + 60, 590));

      await _holdFrames(tester, 20);
      expect(host.pixels, greaterThan(300));
      expect(host.requested.every((dy) => dy > 0), isTrue);
      expect(chat.pixels, 0);

      await mouse.up();
      await tester.pump();
    });

    _onDesktop('the resolver is not re-run on every frame of one drag', (
      tester,
    ) async {
      final host = _FakeHost(pixels: 300);
      var resolved = 0;
      await _pumpChat(
        tester,
        autoscroll: MarkdownSelectionAutoscrollConfig(
          useHostUnionGate: false,
          targetResolver: (context, pointer) {
            resolved++;
            return host.target;
          },
        ),
      );
      final from = _glyphCenter(_paragraph(tester, _body(2)), 0);
      final mouse = await _mouseDragTo(tester, from, Offset(from.dx + 60, 590));
      await _holdFrames(tester, 5);
      final early = resolved;
      expect(early, greaterThan(0));

      await _holdFrames(tester, 40);
      expect(resolved, early);

      await mouse.up();
      await tester.pump();
    });

    _onDesktop('a resolver returning null leaves the list unscrolled', (
      tester,
    ) async {
      final chat = await _pumpChat(
        tester,
        autoscroll: MarkdownSelectionAutoscrollConfig(
          targetResolver: (context, pointer) => null,
        ),
      );
      final from = _glyphCenter(_paragraph(tester, _body(2)), 0);
      final mouse = await _mouseDragTo(tester, from, Offset(from.dx + 60, 590));

      await _holdFrames(tester, 20);
      expect(chat.pixels, 0);
      expect(chat.controller.hasSelection, isTrue);
      expect(tester.takeException(), isNull);

      await mouse.up();
      await tester.pump();
    });

    _onDesktop('a target that reports it cannot scroll is never driven', (
      tester,
    ) async {
      final host = _FakeHost(pixels: 1000, max: 1000);
      await _pumpChat(
        tester,
        autoscroll: MarkdownSelectionAutoscrollConfig(
          useHostUnionGate: false,
          targetResolver: (context, pointer) => host.target,
        ),
      );
      final from = _glyphCenter(_paragraph(tester, _body(2)), 0);
      final mouse = await _mouseDragTo(tester, from, Offset(from.dx + 60, 590));

      await _holdFrames(tester, 20);
      expect(host.requested, isEmpty);

      await mouse.up();
      await tester.pump();
    });
  });

  group('Touch drags', () {
    testWidgets('a long-press drag held in the bottom band scrolls and '
        'extends by word', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final chat = await _pumpChat(tester);
        final from = _glyphCenter(_paragraph(tester, _body(2)), 1);
        final touch = await tester.startGesture(
          from,
          kind: PointerDeviceKind.touch,
        );
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        expect(chat.controller.getText(), 'message');

        await touch.moveTo(Offset(from.dx + 30, 300));
        await tester.pump();
        await touch.moveTo(Offset(from.dx + 30, 592));
        await tester.pump();
        await _holdFrames(tester, 60);

        expect(chat.pixels, greaterThan(100));
        final selection = chat.controller.normalizedSelection!;
        expect(
          selection.start,
          const MarkdownPosition(documentId: 'm02', blockIndex: 0, offset: 0),
        );
        expect(selection.end.documentId.compareTo(_id(12)), greaterThan(0));

        await touch.up();
        await tester.pump();
        final settled = chat.pixels;
        await _holdFrames(tester, 10);
        expect(chat.pixels, settled);
        expect(chat.controller.hasSelection, isTrue);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('a cancelled long-press drag stops scrolling and keeps the '
        'selection', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final chat = await _pumpChat(tester);
        final from = _glyphCenter(_paragraph(tester, _body(2)), 1);
        final touch = await tester.startGesture(
          from,
          kind: PointerDeviceKind.touch,
        );
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
        await touch.moveTo(Offset(from.dx + 30, 592));
        await tester.pump();
        await _holdFrames(tester, 20);
        expect(chat.pixels, greaterThan(0));

        await touch.cancel();
        await tester.pump();
        final settled = chat.pixels;
        await _holdFrames(tester, 10);
        expect(chat.pixels, settled);
        expect(chat.controller.hasSelection, isTrue);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
