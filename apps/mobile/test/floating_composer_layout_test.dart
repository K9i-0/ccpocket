import 'package:ccpocket/features/chat_session/widgets/floating_composer_layout.dart';
import 'package:ccpocket/services/floating_keyboard_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _contentKey = ValueKey('content');
const _barsKey = ValueKey('bars');
const _composerKey = ValueKey('composer');
const _fieldKey = ValueKey('field');

/// 800x600 test surface.
const _viewSize = Size(800, 600);

KeyboardGuideFrame _floatingAt(double top) => KeyboardGuideFrame(
  rect: Rect.fromLTWH(200, top, 334, 200),
  viewSize: _viewSize,
);

void main() {
  group('floatingComposerTop', () {
    test('sits just above the keyboard', () {
      expect(
        floatingComposerTop(
          keyboardTop: 400,
          composerHeight: 100,
          availableHeight: 560,
        ),
        400 - floatingComposerKeyboardGap - 100,
      );
    });

    test('never goes above the top margin', () {
      expect(
        floatingComposerTop(
          keyboardTop: 50,
          composerHeight: 100,
          availableHeight: 560,
        ),
        floatingComposerTopMargin,
      );
    });

    test('drops to keep room for completion options', () {
      expect(
        floatingComposerTop(
          keyboardTop: 250,
          composerHeight: 100,
          availableHeight: 560,
          completionReserve: floatingComposerCompletionReserve,
        ),
        floatingComposerTopMargin + floatingComposerCompletionReserve,
      );
    });

    test('stays above the bottom bars', () {
      expect(
        floatingComposerTop(
          keyboardTop: 600,
          composerHeight: 100,
          availableHeight: 500,
        ),
        400,
      );
    });
  });

  group('KeyboardGuideFrame.isFloating', () {
    test('hidden keyboard (safe-area strip) is not floating', () {
      const frame = KeyboardGuideFrame(
        rect: Rect.fromLTWH(0, 580, 800, 20),
        viewSize: _viewSize,
      );
      expect(frame.isFloating, isFalse);
    });

    test('docked keyboard is not floating', () {
      const frame = KeyboardGuideFrame(
        rect: Rect.fromLTWH(0, 260, 800, 340),
        viewSize: _viewSize,
      );
      expect(frame.isFloating, isFalse);
    });

    test('floating keyboard away from the edges is floating', () {
      expect(_floatingAt(200).isFloating, isTrue);
    });
  });

  group('FloatingComposerLayout', () {
    late ValueNotifier<KeyboardGuideFrame?> keyboard;

    setUp(() => keyboard = ValueNotifier(null));
    tearDown(() => keyboard.dispose());

    Future<void> pumpLayout(
      WidgetTester tester, {
      bool withComposer = true,
      bool completionVisible = false,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FloatingComposerLayout(
              keyboardFrame: keyboard,
              content: const SizedBox.expand(key: _contentKey),
              bars: const SizedBox(key: _barsKey, height: 40),
              composer: withComposer
                  ? _Composer(completionVisible: completionVisible)
                  : null,
            ),
          ),
        ),
      );
    }

    Rect rectOf(WidgetTester tester, Key key) =>
        tester.getRect(find.byKey(key));

    testWidgets('stacks content, bars and composer without a floating '
        'keyboard', (tester) async {
      await pumpLayout(tester);

      expect(rectOf(tester, _composerKey).bottom, 600);
      expect(rectOf(tester, _barsKey).bottom, rectOf(tester, _composerKey).top);
      expect(rectOf(tester, _contentKey).bottom, rectOf(tester, _barsKey).top);
    });

    testWidgets('ignores a floating keyboard while the composer is not '
        'focused', (tester) async {
      await pumpLayout(tester);
      keyboard.value = _floatingAt(300);
      await tester.pump();

      expect(rectOf(tester, _composerKey).bottom, 600);
    });

    testWidgets('floats the composer above a floating keyboard and extends '
        'content behind it', (tester) async {
      await pumpLayout(tester);
      await tester.showKeyboard(find.byKey(_fieldKey));
      keyboard.value = _floatingAt(300);
      await tester.pump();
      await tester.pump();

      final composer = rectOf(tester, _composerKey);
      expect(composer.bottom, 300 - floatingComposerKeyboardGap);
      expect(rectOf(tester, _barsKey).bottom, 600);
      expect(rectOf(tester, _contentKey).bottom, 560);
      // Same full width as the docked composer.
      expect(composer.left, 0);
      expect(composer.width, _viewSize.width);

      // Follows the keyboard vertically.
      keyboard.value = _floatingAt(450);
      await tester.pump();
      expect(
        rectOf(tester, _composerKey).bottom,
        450 - floatingComposerKeyboardGap,
      );

      // Back to the column when the keyboard docks.
      keyboard.value = null;
      await tester.pump();
      expect(rectOf(tester, _composerKey).bottom, 600);
    });

    testWidgets('keeps room for completion options above the composer', (
      tester,
    ) async {
      await pumpLayout(tester, completionVisible: true);
      await tester.showKeyboard(find.byKey(_fieldKey));
      keyboard.value = _floatingAt(150);
      await tester.pump();
      await tester.pump();

      expect(
        rectOf(tester, _composerKey).top,
        floatingComposerTopMargin + floatingComposerCompletionReserve,
      );
    });

    testWidgets('keeps composer state across keyboard modes', (tester) async {
      await pumpLayout(tester);
      await tester.showKeyboard(find.byKey(_fieldKey));
      await tester.enterText(find.byKey(_fieldKey), 'draft');
      final state = tester.state<_ComposerState>(find.byType(_Composer));

      keyboard.value = _floatingAt(300);
      await tester.pump();
      await tester.pump();
      expect(tester.state<_ComposerState>(find.byType(_Composer)), same(state));
      expect(find.text('draft'), findsOneWidget);

      keyboard.value = null;
      await tester.pump();
      expect(tester.state<_ComposerState>(find.byType(_Composer)), same(state));
      expect(find.text('draft'), findsOneWidget);
    });

    testWidgets('exposes the floating state to the chat content', (
      tester,
    ) async {
      await pumpLayout(tester);
      final contentContext = tester.element(find.byKey(_contentKey));
      expect(FloatingComposerStatus.isFloatingOf(contentContext), isFalse);

      await tester.showKeyboard(find.byKey(_fieldKey));
      keyboard.value = _floatingAt(300);
      await tester.pump();
      await tester.pump();
      expect(
        FloatingComposerStatus.isFloatingOf(
          tester.element(find.byKey(_contentKey)),
        ),
        isTrue,
      );
    });

    testWidgets('tapping the chat area closes a floating keyboard', (
      tester,
    ) async {
      await pumpLayout(tester);
      await tester.showKeyboard(find.byKey(_fieldKey));
      keyboard.value = _floatingAt(400);
      await tester.pump();
      await tester.pump();

      await tester.tapAt(const Offset(400, 100));
      await tester.pump();

      expect(
        FocusManager.instance.primaryFocus?.context?.widget,
        isNot(isA<EditableText>()),
      );
      expect(rectOf(tester, _composerKey).bottom, 600);
    });

    testWidgets('tapping the chat area keeps a docked keyboard', (
      tester,
    ) async {
      await pumpLayout(tester);
      await tester.showKeyboard(find.byKey(_fieldKey));

      await tester.tapAt(const Offset(400, 100));
      await tester.pump();

      expect(fieldFocused(tester), isTrue);
    });

    testWidgets('swiping the floating composer down closes the keyboard', (
      tester,
    ) async {
      await pumpLayout(tester);
      await tester.showKeyboard(find.byKey(_fieldKey));
      keyboard.value = _floatingAt(400);
      await tester.pump();
      await tester.pump();

      await tester.drag(find.byKey(_composerKey), const Offset(0, 80));
      await tester.pump();
      expect(fieldFocused(tester), isFalse);

      expect(rectOf(tester, _composerKey).bottom, 600);
    });

    testWidgets('lays out without a composer', (tester) async {
      await pumpLayout(tester, withComposer: false);
      keyboard.value = _floatingAt(300);
      await tester.pump();

      expect(rectOf(tester, _barsKey).bottom, 600);
      expect(rectOf(tester, _contentKey).bottom, 560);
    });
  });

  group('FloatingKeyboardService', () {
    const channel = EventChannel('test/floating_keyboard');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(channel, null);
    });

    test('publishes only floating frames', () async {
      late MockStreamHandlerEventSink sink;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
            channel,
            MockStreamHandler.inline(onListen: (_, events) => sink = events),
          );
      final service = FloatingKeyboardService(channel: channel, enabled: true)
        ..start();
      addTearDown(service.dispose);
      await Future<void>.delayed(Duration.zero);

      Map<String, double> event(double y, double w, double h) => {
        'x': 0,
        'y': y,
        'w': w,
        'h': h,
        'viewW': 800,
        'viewH': 600,
      };

      sink.success(event(200, 334, 300));
      await Future<void>.delayed(Duration.zero);
      expect(service.floatingFrame.value?.rect.top, 200);

      sink.success(event(260, 800, 340));
      await Future<void>.delayed(Duration.zero);
      expect(service.floatingFrame.value, isNull);
    });

    test('stays null when disabled', () {
      final service = FloatingKeyboardService(channel: channel, enabled: false)
        ..start();
      addTearDown(service.dispose);
      expect(service.floatingFrame.value, isNull);
    });
  });
}

class _Composer extends StatefulWidget {
  const _Composer({required this.completionVisible});

  final bool completionVisible;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    FloatingComposerScope.maybeOf(context)
        ?.onCompletionVisibilityChanged(widget.completionVisible);
    return SizedBox(
      key: _composerKey,
      height: 100,
      child: TextField(key: _fieldKey, controller: _controller),
    );
  }
}

bool fieldFocused(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus;
