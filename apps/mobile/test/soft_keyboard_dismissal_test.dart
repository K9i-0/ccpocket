import 'package:ccpocket/widgets/soft_keyboard_dismissal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  bool hideRequested(WidgetTester tester) =>
      tester.testTextInput.log.any((call) => call.method == 'TextInput.hide');

  Widget buildList({FocusNode? fieldFocus}) {
    return MaterialApp(
      home: Scaffold(
        body: DismissKeyboardOnUserScroll(
          child: ListView(
            key: const ValueKey('list'),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (fieldFocus != null)
                TextField(key: const ValueKey('field'), focusNode: fieldFocus),
              for (var i = 0; i < 40; i++)
                SizedBox(height: 60, child: Text('row $i')),
            ],
          ),
        ),
      ),
    );
  }

  void showKeyboardInset(WidgetTester tester) {
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
  }

  testWidgets('hides a keyboard left behind without a focused field', (
    tester,
  ) async {
    showKeyboardInset(tester);
    await tester.pumpWidget(buildList());
    tester.testTextInput.log.clear();

    await tester.drag(
      find.byKey(const ValueKey('list')),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    expect(hideRequested(tester), isTrue);
  });

  testWidgets('unfocuses a focused field in the list on drag', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    showKeyboardInset(tester);
    await tester.pumpWidget(buildList(fieldFocus: focus));
    await tester.tap(find.byKey(const ValueKey('field')));
    await tester.pump();
    expect(focus.hasFocus, isTrue);

    await tester.drag(
      find.byKey(const ValueKey('list')),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    expect(focus.hasFocus, isFalse);
    expect(hideRequested(tester), isTrue);
  });

  testWidgets('dismisses on a drag at the top edge', (tester) async {
    showKeyboardInset(tester);
    await tester.pumpWidget(buildList());
    tester.testTextInput.log.clear();

    await tester.drag(find.byKey(const ValueKey('list')), const Offset(0, 200));
    await tester.pumpAndSettle();

    expect(hideRequested(tester), isTrue);
  });

  testWidgets('leaves focus alone without an on-screen keyboard', (
    tester,
  ) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(buildList(fieldFocus: focus));
    await tester.tap(find.byKey(const ValueKey('field')));
    await tester.pump();
    tester.testTextInput.log.clear();

    await tester.drag(
      find.byKey(const ValueKey('list')),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    expect(focus.hasFocus, isTrue);
    expect(hideRequested(tester), isFalse);
  });

  testWidgets('ignores programmatic scrolling', (tester) async {
    showKeyboardInset(tester);
    await tester.pumpWidget(buildList());
    tester.testTextInput.log.clear();

    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;
    position.jumpTo(300);
    await tester.pumpAndSettle();

    expect(hideRequested(tester), isFalse);
  });
}
