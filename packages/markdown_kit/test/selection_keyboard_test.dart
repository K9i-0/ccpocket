// Keyboard selection: shortcuts wired by MarkdownSelectionScope and the
// controller extension methods behind them.
//
// Gap inventory against the reference suite (flutter_md, MIT), by test name:
//
// selection/selection_keyboard_test.dart
//   (a) already covered: Ctrl/Cmd+A, Esc, Cmd+C on macOS, Shift+Arrow by
//       character, Shift+End / Ctrl+Shift+End (selection_handles_gesture_test
//       "Desktop mouse & keyboard selection"), right-click toolbar.
//   (b) ported: Shift+ArrowRight extends across a block boundary [high];
//       extendSelectionByCharacter(forward: false) shrinks [high];
//       extendSelectionByWord forward / backward [high]; stepping off a block
//       end / start into the neighbouring block and document [high];
//       extendSelectionToDocumentBoundary [high]; extendSelectionToLineBreak
//       [medium]; Ctrl+C copies on a non-Apple platform [medium].
//   (c) ported with a different expectation: word stepping uses
//       markdown_kit's own word classes (CJK punctuation ends a word, see
//       selection_regression_test), so the tests assert the stops every
//       implementation must make instead of the reference offsets.
//   Missing, not ported: "showToolbar/hideToolbar via the scope state"
//       (toolbar visibility, outside the keyboard scope of this file).
//
// selection/selection_scope_regressions_test.dart
//   (b) ported: Esc with no selection reaches the enclosing handler [high].
//
// New here (no reference counterpart): every Apple / non-Apple modifier
// combination in MarkdownSelectionScope._buildShortcuts, the disabled scope,
// allowCrossDocumentSelection: false at the keyboard, and the unmounted
// fallbacks of extendToLineBreak / extendToAdjacentLine.
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_kit/markdown_kit.dart';

Widget _testApp({required Widget child, Size size = const Size(420, 680)}) {
  return Directionality(
    key: UniqueKey(),
    textDirection: ui.TextDirection.ltr,
    child: MediaQuery(
      data: MediaQueryData(size: size),
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

MarkdownDocument _doc(List<String> paragraphs) => MarkdownDocument(
  blocks: [
    for (final p in paragraphs) ParagraphBlock(inlines: [TextInline(p)]),
  ],
);

MarkdownPosition _pos(String doc, int block, int offset) =>
    MarkdownPosition(documentId: doc, blockIndex: block, offset: offset);

MarkdownSelection _sel(MarkdownPosition base, MarkdownPosition extent) =>
    MarkdownSelection(base: base, extent: extent);

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

const _first = 'Alpha beta gamma'; // 16 chars; words 0..5, 6..10, 11..16
const _second = 'Second line here'; // 16 chars
const _other = 'Third doc text'; // 14 chars

/// Two documents: `d1` = [_first, _second], `d2` = [_other].
Future<MarkdownSelectionController> _pumpDocs(
  WidgetTester tester, {
  bool allowCrossDocumentSelection = true,
  bool enabled = true,
  double width = 320,
  List<String> firstDocument = const [_first, _second],
  Widget Function(Widget scope)? wrap,
}) async {
  final controller = MarkdownSelectionController(
    allowCrossDocumentSelection: allowCrossDocumentSelection,
  );
  addTearDown(controller.dispose);
  final Widget scope = MarkdownSelectionScope(
    controller: controller,
    enabled: enabled,
    child: Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MarkdownView(
                document: _doc(firstDocument),
                documentId: 'd1',
                documentOrder: 0,
                theme: MarkdownThemeData.fallback(),
              ),
              const SizedBox(height: 24),
              MarkdownView(
                document: _doc(const [_other]),
                documentId: 'd2',
                documentOrder: 1,
                theme: MarkdownThemeData.fallback(),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpWidget(_testApp(child: wrap == null ? scope : wrap(scope)));
  await tester.pump();
  return controller;
}

Future<void> _focusScope(WidgetTester tester) async {
  final state = tester.state<MarkdownSelectionScopeState>(
    find.byType(MarkdownSelectionScope),
  );
  state.focusNode.requestFocus();
  await tester.pump();
  expect(state.focusNode.hasFocus, isTrue, reason: 'scope must hold focus');
}

/// Presses [key] while holding [modifiers].
Future<void> _chord(
  WidgetTester tester,
  List<LogicalKeyboardKey> modifiers,
  LogicalKeyboardKey key,
) async {
  for (final m in modifiers) {
    await tester.sendKeyDownEvent(m);
  }
  await tester.sendKeyDownEvent(key);
  await tester.sendKeyUpEvent(key);
  for (final m in modifiers.reversed) {
    await tester.sendKeyUpEvent(m);
  }
  await tester.pump();
}

const _shift = LogicalKeyboardKey.shiftLeft;
const _meta = LogicalKeyboardKey.metaLeft;
const _ctrl = LogicalKeyboardKey.controlLeft;
const _alt = LogicalKeyboardKey.altLeft;

/// Routes clipboard writes into the returned list for the current test.
List<String> _captureClipboard() {
  final writes = <String>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<Object?, Object?>;
          writes.add(args['text']! as String);
        }
        return null;
      });
  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });
  return writes;
}

void _onPlatform(
  TargetPlatform platform,
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets('${platform.name}: $description', (tester) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      await body(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  _controllerExtensionTests();

  group('Shift+Arrow by character (all platforms)', () {
    for (final platform in [TargetPlatform.macOS, TargetPlatform.windows]) {
      _onPlatform(platform, 'Shift+ArrowRight grows the extent by one', (
        tester,
      ) async {
        final controller = await _pumpDocs(tester);
        controller.setSelection(_sel(_pos('d1', 0, 0), _pos('d1', 0, 5)));
        await _focusScope(tester);

        await _chord(tester, [_shift], LogicalKeyboardKey.arrowRight);
        expect(controller.selection, _sel(_pos('d1', 0, 0), _pos('d1', 0, 6)));
        expect(controller.getText(), 'Alpha ');
      });

      _onPlatform(platform, 'Shift+ArrowLeft shrinks the extent by one', (
        tester,
      ) async {
        final controller = await _pumpDocs(tester);
        controller.setSelection(_sel(_pos('d1', 0, 0), _pos('d1', 0, 5)));
        await _focusScope(tester);

        await _chord(tester, [_shift], LogicalKeyboardKey.arrowLeft);
        expect(controller.selection, _sel(_pos('d1', 0, 0), _pos('d1', 0, 4)));
        expect(controller.getText(), 'Alph');
      });

      _onPlatform(
        platform,
        'Shift+ArrowLeft past the base reverses the '
        'selection',
        (tester) async {
          final controller = await _pumpDocs(tester);
          controller.setSelection(_sel(_pos('d1', 0, 6), _pos('d1', 0, 7)));
          await _focusScope(tester);

          await _chord(tester, [_shift], LogicalKeyboardKey.arrowLeft);
          await _chord(tester, [_shift], LogicalKeyboardKey.arrowLeft);
          expect(
            controller.selection,
            _sel(_pos('d1', 0, 6), _pos('d1', 0, 5)),
          );
          expect(controller.isSelectionReversed, isTrue);
          expect(controller.getText(), ' ');
        },
      );

      _onPlatform(
        platform,
        'Shift+ArrowRight at a block end steps into the '
        'next block',
        (tester) async {
          final controller = await _pumpDocs(tester);
          controller.setSelection(
            _sel(_pos('d1', 0, 11), _pos('d1', 0, _first.length)),
          );
          await _focusScope(tester);

          await _chord(tester, [_shift], LogicalKeyboardKey.arrowRight);
          expect(controller.selection!.extent, _pos('d1', 1, 0));
          await _chord(tester, [_shift], LogicalKeyboardKey.arrowRight);
          expect(controller.selection!.extent, _pos('d1', 1, 1));
          expect(controller.getText(), 'gamma\n\nS');
        },
      );
    }
  });

  group('Apple modifiers', () {
    _onPlatform(
      TargetPlatform.macOS,
      'Alt+Shift+ArrowRight extends to the '
      'next word end',
      (tester) async {
        final controller = await _pumpDocs(tester);
        controller.setSelection(_sel(_pos('d1', 0, 0), _pos('d1', 0, 5)));
        await _focusScope(tester);

        await _chord(tester, [_alt, _shift], LogicalKeyboardKey.arrowRight);
        expect(controller.getText(), 'Alpha beta');
      },
    );

    _onPlatform(
      TargetPlatform.macOS,
      'Alt+Shift+ArrowLeft pulls the extent '
      'back to the previous word start',
      (tester) async {
        final controller = await _pumpDocs(tester);
        controller.setSelection(_sel(_pos('d1', 0, 0), _pos('d1', 0, 10)));
        await _focusScope(tester);

        await _chord(tester, [_alt, _shift], LogicalKeyboardKey.arrowLeft);
        expect(controller.selection, _sel(_pos('d1', 0, 0), _pos('d1', 0, 6)));
      },
    );

    _onPlatform(
      TargetPlatform.macOS,
      'Cmd+Shift+ArrowRight extends to the '
      'line end',
      (tester) async {
        final controller = await _pumpDocs(tester);
        controller.setSelection(_sel(_pos('d1', 0, 6), _pos('d1', 0, 7)));
        await _focusScope(tester);

        await _chord(tester, [_meta, _shift], LogicalKeyboardKey.arrowRight);
        expect(controller.getText(), 'beta gamma');
      },
    );

    _onPlatform(
      TargetPlatform.macOS,
      'Cmd+Shift+ArrowLeft extends to the '
      'line start',
      (tester) async {
        final controller = await _pumpDocs(tester);
        controller.setSelection(_sel(_pos('d1', 0, 10), _pos('d1', 0, 9)));
        await _focusScope(tester);

        await _chord(tester, [_meta, _shift], LogicalKeyboardKey.arrowLeft);
        expect(controller.selection, _sel(_pos('d1', 0, 10), _pos('d1', 0, 0)));
        expect(controller.getText(), 'Alpha beta');
      },
    );

    _onPlatform(
      TargetPlatform.macOS,
      'Cmd+Shift+ArrowDown extends to the '
      'end of the last document',
      (tester) async {
        final controller = await _pumpDocs(tester);
        controller.setSelection(_sel(_pos('d1', 0, 11), _pos('d1', 0, 12)));
        await _focusScope(tester);

        await _chord(tester, [_meta, _shift], LogicalKeyboardKey.arrowDown);
        expect(controller.selection!.extent, _pos('d2', 0, _other.length));
        expect(controller.getText(), 'gamma\n\n$_second\n\n$_other');
      },
    );

    _onPlatform(
      TargetPlatform.macOS,
      'Cmd+Shift+ArrowUp extends to the '
      'start of the first document',
      (tester) async {
        final controller = await _pumpDocs(tester);
        controller.setSelection(_sel(_pos('d2', 0, 5), _pos('d2', 0, 4)));
        await _focusScope(tester);

        await _chord(tester, [_meta, _shift], LogicalKeyboardKey.arrowUp);
        expect(controller.selection!.extent, _pos('d1', 0, 0));
        expect(controller.getText(), '$_first\n\n$_second\n\nThird');
      },
    );

    _onPlatform(TargetPlatform.macOS, 'Ctrl+A is not select-all', (
      tester,
    ) async {
      final controller = await _pumpDocs(tester);
      await _focusScope(tester);

      await _chord(tester, [_ctrl], LogicalKeyboardKey.keyA);
      expect(controller.hasSelection, isFalse);
    });

    _onPlatform(
      TargetPlatform.macOS,
      'Cmd+A selects every document when '
      'cross-document selection is allowed',
      (tester) async {
        final controller = await _pumpDocs(tester);
        await _focusScope(tester);

        await _chord(tester, [_meta], LogicalKeyboardKey.keyA);
        expect(controller.getText(), '$_first\n\n$_second\n\n$_other');
      },
    );
  });

  group('Non-Apple modifiers', () {
    for (final platform in [TargetPlatform.windows, TargetPlatform.linux]) {
      _onPlatform(
        platform,
        'Ctrl+Shift+ArrowRight extends to the next word '
        'end',
        (tester) async {
          final controller = await _pumpDocs(tester);
          controller.setSelection(_sel(_pos('d1', 0, 0), _pos('d1', 0, 5)));
          await _focusScope(tester);

          await _chord(tester, [_ctrl, _shift], LogicalKeyboardKey.arrowRight);
          expect(controller.getText(), 'Alpha beta');
        },
      );

      _onPlatform(
        platform,
        'Ctrl+Shift+ArrowLeft pulls the extent back to '
        'the previous word start',
        (tester) async {
          final controller = await _pumpDocs(tester);
          controller.setSelection(_sel(_pos('d1', 0, 0), _pos('d1', 0, 10)));
          await _focusScope(tester);

          await _chord(tester, [_ctrl, _shift], LogicalKeyboardKey.arrowLeft);
          expect(
            controller.selection,
            _sel(_pos('d1', 0, 0), _pos('d1', 0, 6)),
          );
        },
      );

      _onPlatform(platform, 'Shift+Home extends to the line start', (
        tester,
      ) async {
        final controller = await _pumpDocs(tester);
        controller.setSelection(_sel(_pos('d1', 1, 11), _pos('d1', 1, 10)));
        await _focusScope(tester);

        await _chord(tester, [_shift], LogicalKeyboardKey.home);
        expect(controller.selection, _sel(_pos('d1', 1, 11), _pos('d1', 1, 0)));
        expect(controller.getText(), 'Second line');
      });

      _onPlatform(
        platform,
        'Ctrl+Shift+Home extends to the start of the '
        'first document',
        (tester) async {
          final controller = await _pumpDocs(tester);
          controller.setSelection(_sel(_pos('d2', 0, 5), _pos('d2', 0, 4)));
          await _focusScope(tester);

          await _chord(tester, [_ctrl, _shift], LogicalKeyboardKey.home);
          expect(controller.selection!.extent, _pos('d1', 0, 0));
        },
      );

      _onPlatform(platform, 'Ctrl+A selects all and Ctrl+C copies it', (
        tester,
      ) async {
        final clipboard = _captureClipboard();
        final controller = await _pumpDocs(tester);
        await _focusScope(tester);

        await _chord(tester, [_ctrl], LogicalKeyboardKey.keyA);
        expect(controller.getText(), '$_first\n\n$_second\n\n$_other');

        await _chord(tester, [_ctrl], LogicalKeyboardKey.keyC);
        await tester.pump();
        expect(clipboard, ['$_first\n\n$_second\n\n$_other']);
      });

      _onPlatform(platform, 'Meta+A and Meta+C do nothing', (tester) async {
        final clipboard = _captureClipboard();
        final controller = await _pumpDocs(tester);
        controller.setSelection(_sel(_pos('d1', 0, 0), _pos('d1', 0, 5)));
        await _focusScope(tester);

        await _chord(tester, [_meta], LogicalKeyboardKey.keyA);
        expect(controller.getText(), 'Alpha');
        await _chord(tester, [_meta], LogicalKeyboardKey.keyC);
        await tester.pump();
        expect(clipboard, isEmpty);
      });
    }
  });

  group('Vertical extension', () {
    _onPlatform(
      TargetPlatform.macOS,
      'Shift+ArrowDown moves the extent to '
      'the block below at the same x',
      (tester) async {
        final controller = await _pumpDocs(tester);
        controller.setSelection(_sel(_pos('d1', 0, 2), _pos('d1', 0, 5)));
        await _focusScope(tester);
        final before = controller.selectionEndpointGlobalRect(base: false)!;

        await _chord(tester, [_shift], LogicalKeyboardKey.arrowDown);
        final extent = controller.selection!.extent;
        expect(controller.selection!.base, _pos('d1', 0, 2));
        expect((extent.documentId, extent.blockIndex), ('d1', 1));
        final after = controller.selectionEndpointGlobalRect(base: false)!;
        expect(after.top, greaterThan(before.top));
        // Within one glyph of the starting column.
        expect((after.left - before.left).abs(), lessThanOrEqualTo(16.0));
      },
    );

    _onPlatform(
      TargetPlatform.macOS,
      'Shift+ArrowUp moves the extent to '
      'the block above',
      (tester) async {
        final controller = await _pumpDocs(tester);
        controller.setSelection(_sel(_pos('d1', 1, 8), _pos('d1', 1, 5)));
        await _focusScope(tester);

        await _chord(tester, [_shift], LogicalKeyboardKey.arrowUp);
        final extent = controller.selection!.extent;
        expect(controller.selection!.base, _pos('d1', 1, 8));
        expect((extent.documentId, extent.blockIndex), ('d1', 0));
      },
    );

    _onPlatform(
      TargetPlatform.macOS,
      'Shift+ArrowDown moves down one '
      'visual line inside a wrapped paragraph',
      (tester) async {
        const long =
            'one two three four five six seven eight nine ten eleven twelve';
        final controller = await _pumpDocs(
          tester,
          width: 140,
          firstDocument: const [long],
        );
        controller.setSelection(_sel(_pos('d1', 0, 0), _pos('d1', 0, 2)));
        await _focusScope(tester);
        final p = _paragraph(tester, 'one two');
        double topOf(int offset) => p.caretRectForLocalOffset(offset).top;
        final firstLineTop = topOf(2);

        await _chord(tester, [_shift], LogicalKeyboardKey.arrowDown);
        final extent = controller.selection!.extent;
        expect((extent.documentId, extent.blockIndex), ('d1', 0));
        final secondLineTop = topOf(extent.offset);
        expect(secondLineTop, greaterThan(firstLineTop));

        await _chord(tester, [_shift], LogicalKeyboardKey.arrowDown);
        final next = controller.selection!.extent;
        expect((next.documentId, next.blockIndex), ('d1', 0));
        expect(topOf(next.offset), greaterThan(secondLineTop));
      },
    );

    _onPlatform(
      TargetPlatform.macOS,
      'Shift+ArrowDown on the last line '
      'extends to the end of the content',
      (tester) async {
        final controller = await _pumpDocs(tester);
        controller.setSelection(_sel(_pos('d2', 0, 2), _pos('d2', 0, 5)));
        await _focusScope(tester);

        await _chord(tester, [_shift], LogicalKeyboardKey.arrowDown);
        expect(controller.selection, _sel(_pos('d2', 0, 2), _pos('d2', 0, 14)));
      },
    );

    _onPlatform(
      TargetPlatform.macOS,
      'Shift+ArrowUp on the first line '
      'extends to the start of the content',
      (tester) async {
        final controller = await _pumpDocs(tester);
        controller.setSelection(_sel(_pos('d1', 0, 8), _pos('d1', 0, 5)));
        await _focusScope(tester);

        await _chord(tester, [_shift], LogicalKeyboardKey.arrowUp);
        expect(controller.selection, _sel(_pos('d1', 0, 8), _pos('d1', 0, 0)));
      },
    );
  });

  group('Document boundaries at the keyboard', () {
    _onPlatform(
      TargetPlatform.macOS,
      'Shift+ArrowRight crosses into the '
      'next document when cross-document selection is allowed',
      (tester) async {
        final controller = await _pumpDocs(tester);
        controller.setSelection(
          _sel(_pos('d1', 1, 12), _pos('d1', 1, _second.length)),
        );
        await _focusScope(tester);

        await _chord(tester, [_shift], LogicalKeyboardKey.arrowRight);
        expect(controller.selection!.extent, _pos('d2', 0, 0));
        await _chord(tester, [_shift], LogicalKeyboardKey.arrowRight);
        expect(controller.getText(), 'here\n\nT');
      },
    );

    _onPlatform(
      TargetPlatform.macOS,
      'Shift+ArrowRight stops at the end of '
      'the anchor document when cross-document selection is off',
      (tester) async {
        final controller = await _pumpDocs(
          tester,
          allowCrossDocumentSelection: false,
        );
        final initial = _sel(_pos('d1', 1, 12), _pos('d1', 1, _second.length));
        controller.setSelection(initial);
        await _focusScope(tester);

        await _chord(tester, [_shift], LogicalKeyboardKey.arrowRight);
        await _chord(tester, [_alt, _shift], LogicalKeyboardKey.arrowRight);
        await _chord(tester, [_shift], LogicalKeyboardKey.arrowDown);
        expect(controller.selection, initial);
      },
    );

    _onPlatform(
      TargetPlatform.macOS,
      'Shift+ArrowLeft stops at the start '
      'of the anchor document when cross-document selection is off',
      (tester) async {
        final controller = await _pumpDocs(
          tester,
          allowCrossDocumentSelection: false,
        );
        final initial = _sel(_pos('d2', 0, 5), _pos('d2', 0, 0));
        controller.setSelection(initial);
        await _focusScope(tester);

        await _chord(tester, [_shift], LogicalKeyboardKey.arrowLeft);
        await _chord(tester, [_alt, _shift], LogicalKeyboardKey.arrowLeft);
        await _chord(tester, [_shift], LogicalKeyboardKey.arrowUp);
        expect(controller.selection, initial);
      },
    );

    _onPlatform(
      TargetPlatform.macOS,
      'Cmd+Shift+ArrowDown stays inside the '
      'anchor document when cross-document selection is off',
      (tester) async {
        final controller = await _pumpDocs(
          tester,
          allowCrossDocumentSelection: false,
        );
        controller.setSelection(_sel(_pos('d1', 0, 11), _pos('d1', 0, 12)));
        await _focusScope(tester);

        await _chord(tester, [_meta, _shift], LogicalKeyboardKey.arrowDown);
        expect(controller.selection!.extent, _pos('d1', 1, _second.length));
      },
    );

    _onPlatform(
      TargetPlatform.macOS,
      'Cmd+A selects only the anchor '
      'document when cross-document selection is off',
      (tester) async {
        final controller = await _pumpDocs(
          tester,
          allowCrossDocumentSelection: false,
        );
        controller.setSelection(_sel(_pos('d2', 0, 0), _pos('d2', 0, 5)));
        await _focusScope(tester);

        await _chord(tester, [_meta], LogicalKeyboardKey.keyA);
        expect(controller.getText(), _other);
      },
    );
  });

  group('Copy and dismiss', () {
    _onPlatform(
      TargetPlatform.macOS,
      'Cmd+C with a collapsed selection '
      'writes nothing',
      (tester) async {
        final clipboard = _captureClipboard();
        final controller = await _pumpDocs(tester);
        controller.setSelection(MarkdownSelection.collapsed(_pos('d1', 0, 3)));
        await _focusScope(tester);

        await _chord(tester, [_meta], LogicalKeyboardKey.keyC);
        await tester.pump();
        expect(clipboard, isEmpty);
      },
    );

    _onPlatform(
      TargetPlatform.macOS,
      'Cmd+C copies a reversed selection in '
      'reading order',
      (tester) async {
        final clipboard = _captureClipboard();
        final controller = await _pumpDocs(tester);
        controller.setSelection(_sel(_pos('d1', 1, 6), _pos('d1', 0, 11)));
        await _focusScope(tester);

        await _chord(tester, [_meta], LogicalKeyboardKey.keyC);
        await tester.pump();
        expect(clipboard, ['gamma\n\nSecond']);
      },
    );

    _onPlatform(
      TargetPlatform.macOS,
      'Esc clears the selection and does '
      'not reach an enclosing dismiss handler',
      (tester) async {
        var outerDismissed = 0;
        final controller = await _pumpDocs(
          tester,
          wrap: (scope) => Actions(
            actions: <Type, Action<Intent>>{
              DismissIntent: CallbackAction<DismissIntent>(
                onInvoke: (_) => outerDismissed++,
              ),
            },
            child: scope,
          ),
        );
        controller.setSelection(_sel(_pos('d1', 0, 0), _pos('d1', 0, 5)));
        await _focusScope(tester);
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        expect(controller.hasSelection, isFalse);
        expect(outerDismissed, 0);
      },
    );

    _onPlatform(
      TargetPlatform.macOS,
      'Esc with no selection reaches the '
      'enclosing dismiss handler',
      (tester) async {
        var outerDismissed = 0;
        await _pumpDocs(
          tester,
          wrap: (scope) => Actions(
            actions: <Type, Action<Intent>>{
              DismissIntent: CallbackAction<DismissIntent>(
                onInvoke: (_) => outerDismissed++,
              ),
            },
            child: scope,
          ),
        );
        await _focusScope(tester);

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        expect(outerDismissed, 1);
      },
    );

    _onPlatform(
      TargetPlatform.macOS,
      'a disabled scope ignores select-all, '
      'extension and copy',
      (tester) async {
        final clipboard = _captureClipboard();
        final controller = await _pumpDocs(tester, enabled: false);
        final initial = _sel(_pos('d1', 0, 0), _pos('d1', 0, 5));
        controller.setSelection(initial);
        final state = tester.state<MarkdownSelectionScopeState>(
          find.byType(MarkdownSelectionScope),
        );
        state.focusNode.requestFocus();
        await tester.pump();

        await _chord(tester, [_meta], LogicalKeyboardKey.keyA);
        await _chord(tester, [_shift], LogicalKeyboardKey.arrowRight);
        await _chord(tester, [_meta], LogicalKeyboardKey.keyC);
        await tester.pump();
        expect(controller.selection, initial);
        expect(clipboard, isEmpty);
      },
    );

    _onPlatform(
      TargetPlatform.macOS,
      'Shift+Arrow with no selection is a '
      'no-op',
      (tester) async {
        final controller = await _pumpDocs(tester);
        await _focusScope(tester);

        await _chord(tester, [_shift], LogicalKeyboardKey.arrowRight);
        await _chord(tester, [_shift], LogicalKeyboardKey.arrowDown);
        await _chord(tester, [_alt, _shift], LogicalKeyboardKey.arrowLeft);
        expect(controller.selection, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

/// Controller-only extension behaviour: no surface is mounted, so these also
/// pin the model fallbacks used while the extent is scrolled off-screen.
void _controllerExtensionTests() {
  group('Controller extension without mounted surfaces', () {
    MarkdownSelectionController controllerWith(
      Map<String, MarkdownDocument> documents, {
      bool allowCrossDocumentSelection = true,
    }) {
      final controller = MarkdownSelectionController(
        allowCrossDocumentSelection: allowCrossDocumentSelection,
      );
      addTearDown(controller.dispose);
      var order = 0;
      documents.forEach((id, document) {
        controller.putDocument(
          MarkdownDocumentRef(id: id, order: order++, document: document),
        );
      });
      return controller;
    }

    const breakDoc = MarkdownDocument(
      blocks: [
        ParagraphBlock(inlines: [TextInline('before')]),
        ThematicBreakBlock(),
        ParagraphBlock(inlines: [TextInline('after')]),
      ],
    );

    test('every extension returns false when nothing is selected', () {
      final controller = controllerWith({
        'a': _doc(['one two']),
      });
      var notified = 0;
      controller.addListener(() => notified++);

      for (final forward in [true, false]) {
        expect(controller.extendByCharacter(forward: forward), isFalse);
        expect(controller.extendByWord(forward: forward), isFalse);
        expect(controller.extendToLineBreak(forward: forward), isFalse);
        expect(controller.extendToAdjacentLine(forward: forward), isFalse);
        expect(controller.extendToDocumentBoundary(forward: forward), isFalse);
      }
      expect(controller.selection, isNull);
      expect(notified, 0);
    });

    test('a successful step notifies once and keeps the base', () {
      final controller = controllerWith({
        'a': _doc(['one two']),
      });
      controller.setSelection(_sel(_pos('a', 0, 1), _pos('a', 0, 2)));
      var notified = 0;
      controller.addListener(() => notified++);

      expect(controller.extendByCharacter(forward: true), isTrue);
      expect(notified, 1);
      expect(controller.selection, _sel(_pos('a', 0, 1), _pos('a', 0, 3)));
    });

    test('a step that cannot move does not notify', () {
      final controller = controllerWith({
        'a': _doc(['one two']),
      });
      controller.setSelection(_sel(_pos('a', 0, 1), _pos('a', 0, 7)));
      var notified = 0;
      controller.addListener(() => notified++);

      expect(controller.extendByCharacter(forward: true), isFalse);
      expect(controller.extendByWord(forward: true), isFalse);
      expect(controller.extendToDocumentBoundary(forward: true), isFalse);
      expect(notified, 0);
    });

    test('character steps move over a whole emoji sequence', () {
      const family = '\u{1F468}‍\u{1F469}‍\u{1F467}';
      final text = 'a${family}b';
      final controller = controllerWith({
        'a': _doc([text]),
      });
      controller.setSelection(MarkdownSelection.collapsed(_pos('a', 0, 1)));

      expect(controller.extendByCharacter(forward: true), isTrue);
      expect(controller.selection!.extent.offset, 1 + family.length);
      expect(controller.getText(), family);

      expect(controller.extendByCharacter(forward: false), isTrue);
      expect(controller.selection!.extent.offset, 1);
    });

    test('character steps keep a combining mark with its base letter', () {
      const text = 'éx';
      final controller = controllerWith({
        'a': _doc([text]),
      });
      controller.setSelection(MarkdownSelection.collapsed(_pos('a', 0, 0)));

      expect(controller.extendByCharacter(forward: true), isTrue);
      expect(controller.selection!.extent.offset, 2);
    });

    test('forward word steps strictly advance, stop at every word end and '
        'reach the block end', () {
      const text = 'foo, bar  baz';
      final controller = controllerWith({
        'a': _doc([text]),
      });
      controller.setSelection(MarkdownSelection.collapsed(_pos('a', 0, 0)));

      final stops = <int>[];
      for (var i = 0; i < text.length; i++) {
        final before = controller.selection!.extent.offset;
        if (before == text.length) break;
        expect(controller.extendByWord(forward: true), isTrue);
        final after = controller.selection!.extent.offset;
        expect(after, greaterThan(before));
        stops.add(after);
      }
      expect(stops, containsAll(<int>[3, 8, 13]));
      expect(stops.last, text.length);
    });

    test('backward word steps strictly retreat, stop at every word start '
        'and reach the block start', () {
      const text = 'foo, bar  baz';
      final controller = controllerWith({
        'a': _doc([text]),
      });
      controller.setSelection(
        MarkdownSelection.collapsed(_pos('a', 0, text.length)),
      );

      final stops = <int>[];
      for (var i = 0; i < text.length; i++) {
        final before = controller.selection!.extent.offset;
        if (before == 0) break;
        expect(controller.extendByWord(forward: false), isTrue);
        final after = controller.selection!.extent.offset;
        expect(after, lessThan(before));
        stops.add(after);
      }
      expect(stops, containsAll(<int>[10, 5, 0]));
      expect(stops.last, 0);
    });

    test('a word step off a block end lands on the next block start', () {
      final controller = controllerWith({
        'a': _doc(['one', 'two']),
      });
      controller.setSelection(_sel(_pos('a', 0, 0), _pos('a', 0, 3)));

      expect(controller.extendByWord(forward: true), isTrue);
      expect(controller.selection!.extent, _pos('a', 1, 0));
    });

    test('a word step off a block start lands on the previous block end', () {
      final controller = controllerWith({
        'a': _doc(['one', 'two']),
      });
      controller.setSelection(_sel(_pos('a', 1, 3), _pos('a', 1, 0)));

      expect(controller.extendByWord(forward: false), isTrue);
      expect(controller.selection!.extent, _pos('a', 0, 3));
    });

    test('stepping forward skips a thematic break', () {
      final controller = controllerWith({'a': breakDoc});
      controller.setSelection(_sel(_pos('a', 0, 3), _pos('a', 0, 6)));

      expect(controller.extendByCharacter(forward: true), isTrue);
      expect(controller.selection!.extent, _pos('a', 2, 0));
      expect(controller.extendByCharacter(forward: true), isTrue);
      expect(controller.getText(), 'ore\n\na');
    });

    test('stepping backward skips a thematic break', () {
      final controller = controllerWith({'a': breakDoc});
      controller.setSelection(_sel(_pos('a', 2, 2), _pos('a', 2, 0)));

      expect(controller.extendByCharacter(forward: false), isTrue);
      expect(controller.selection!.extent, _pos('a', 0, 6));
    });

    test('stepping forward off the last block of a document lands in the '
        'next document', () {
      final controller = controllerWith({
        'a': _doc(['one']),
        'b': _doc(['two']),
      });
      controller.setSelection(_sel(_pos('a', 0, 1), _pos('a', 0, 3)));

      expect(controller.extendByCharacter(forward: true), isTrue);
      expect(controller.selection!.extent, _pos('b', 0, 0));
    });

    test('stepping backward off the first block of a document lands in the '
        'previous document', () {
      final controller = controllerWith({
        'a': _doc(['one']),
        'b': _doc(['two']),
      });
      controller.setSelection(_sel(_pos('b', 0, 2), _pos('b', 0, 0)));

      expect(controller.extendByCharacter(forward: false), isTrue);
      expect(controller.selection!.extent, _pos('a', 0, 3));
    });

    test('stepping between documents skips an empty document', () {
      final controller = controllerWith({
        'a': _doc(['one']),
        'empty': const MarkdownDocument(blocks: []),
        'c': _doc(['two']),
      });
      controller.setSelection(_sel(_pos('a', 0, 1), _pos('a', 0, 3)));

      expect(controller.extendByCharacter(forward: true), isTrue);
      expect(controller.selection!.extent, _pos('c', 0, 0));
      expect(controller.extendByCharacter(forward: false), isTrue);
      expect(controller.selection!.extent, _pos('a', 0, 3));
    });

    test('stepping never leaves the anchor document when cross-document '
        'selection is off', () {
      final controller = controllerWith({
        'a': _doc(['one']),
        'b': _doc(['two']),
      }, allowCrossDocumentSelection: false);
      final atEnd = _sel(_pos('a', 0, 1), _pos('a', 0, 3));
      controller.setSelection(atEnd);
      expect(controller.extendByCharacter(forward: true), isFalse);
      expect(controller.extendByWord(forward: true), isFalse);
      expect(controller.extendToAdjacentLine(forward: true), isFalse);
      expect(controller.selection, atEnd);

      final atStart = _sel(_pos('b', 0, 2), _pos('b', 0, 0));
      controller.setSelection(atStart);
      expect(controller.extendByCharacter(forward: false), isFalse);
      expect(controller.extendByWord(forward: false), isFalse);
      expect(controller.extendToAdjacentLine(forward: false), isFalse);
      expect(controller.selection, atStart);
    });

    test('extendToLineBreak falls back to hard line breaks while the extent '
        'is unmounted', () {
      final document = GfmMarkdownParser().parse('```\na\nbb\nccc\n```');
      final text = extractBlockRenderedText(document.blocks.single);
      expect(text, startsWith('a\nbb\nccc'));
      final controller = controllerWith({'a': document});

      controller.setSelection(MarkdownSelection.collapsed(_pos('a', 0, 3)));
      expect(controller.extendToLineBreak(forward: true), isTrue);
      expect(controller.selection!.extent.offset, 4);

      controller.setSelection(MarkdownSelection.collapsed(_pos('a', 0, 3)));
      expect(controller.extendToLineBreak(forward: false), isTrue);
      expect(controller.selection!.extent.offset, 2);
      expect(controller.getText(), 'b');
    });

    test('extendToLineBreak at a line edge reports no change', () {
      final controller = controllerWith({
        'a': _doc(['single line']),
      });
      controller.setSelection(_sel(_pos('a', 0, 3), _pos('a', 0, 11)));
      expect(controller.extendToLineBreak(forward: true), isFalse);

      controller.setSelection(_sel(_pos('a', 0, 3), _pos('a', 0, 0)));
      expect(controller.extendToLineBreak(forward: false), isFalse);
    });

    test('extendToAdjacentLine falls back to the neighbouring block edge '
        'while the extent is unmounted', () {
      final controller = controllerWith({
        'a': _doc(['one', 'two', 'three']),
      });
      controller.setSelection(_sel(_pos('a', 1, 0), _pos('a', 1, 2)));

      expect(controller.extendToAdjacentLine(forward: true), isTrue);
      expect(controller.selection!.extent, _pos('a', 2, 0));

      controller.setSelection(_sel(_pos('a', 1, 3), _pos('a', 1, 1)));
      expect(controller.extendToAdjacentLine(forward: false), isTrue);
      expect(controller.selection!.extent, _pos('a', 0, 3));
    });

    test('extendToDocumentBoundary ignores leading and trailing thematic '
        'breaks', () {
      const document = MarkdownDocument(
        blocks: [
          ThematicBreakBlock(),
          ParagraphBlock(inlines: [TextInline('first')]),
          ParagraphBlock(inlines: [TextInline('last')]),
          ThematicBreakBlock(),
        ],
      );
      final controller = controllerWith({'a': document});
      controller.setSelection(_sel(_pos('a', 1, 2), _pos('a', 1, 3)));

      expect(controller.extendToDocumentBoundary(forward: true), isTrue);
      expect(controller.selection!.extent, _pos('a', 2, 4));
      expect(controller.getText(), 'rst\n\nlast');

      expect(controller.extendToDocumentBoundary(forward: false), isTrue);
      expect(controller.selection!.extent, _pos('a', 1, 0));
      expect(controller.isSelectionReversed, isTrue);
      expect(controller.getText(), 'fi');
    });

    test('extendToDocumentBoundary spans to the last non-empty document', () {
      final controller = controllerWith({
        'a': _doc(['one']),
        'b': _doc(['two']),
        'empty': const MarkdownDocument(blocks: []),
      });
      controller.setSelection(_sel(_pos('a', 0, 1), _pos('a', 0, 2)));

      expect(controller.extendToDocumentBoundary(forward: true), isTrue);
      expect(controller.selection!.extent, _pos('b', 0, 3));
      expect(controller.getText(), 'ne\n\ntwo');
    });
  });
}
