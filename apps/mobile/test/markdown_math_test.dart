import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/markdown/ccpocket_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _pump(
  WidgetTester tester,
  String data, {
  double width = 360,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: SingleChildScrollView(child: CcpocketMarkdown(data: data)),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('inline and display math are typeset', (tester) async {
    await _pump(
      tester,
      r'Pythagoras: \(x^2 + y^2 = z^2\) holds.'
      '\n\n'
      r'\[\int_0^1 x^2\,dx = \frac{1}{3}\]'
      '\n',
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(Math), findsNWidgets(2));
    final styles = tester
        .widgetList<Math>(find.byType(Math))
        .map((m) => m.mathStyle);
    expect(styles, [MathStyle.text, MathStyle.display]);
    // The raw source must not leak next to the typeset formula.
    expect(find.textContaining(r'\frac', findRichText: true), findsNothing);
  });

  // A parsed tree keeps the GlobalKeys of the widgets built from it, so the
  // same formula shown twice must not share one.
  testWidgets('the same formula can appear more than once', (tester) async {
    await _pump(
      tester,
      r'First \(E = mc^2\), again \(E = mc^2\).'
      '\n\n'
      r'\[E = mc^2\]'
      '\n',
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(Math), findsNWidgets(3));
  });

  testWidgets('a formula the typesetter rejects falls back to text', (
    tester,
  ) async {
    await _pump(tester, r'Broken \(\notacommand{x} + \alpha\) here.');

    expect(tester.takeException(), isNull);
    expect(find.byType(Math), findsNothing);
    expect(find.textContaining('α', findRichText: true), findsOneWidget);
  });

  testWidgets('a display formula that is still streaming is not typeset', (
    tester,
  ) async {
    await _pump(tester, r'\[\int_0^1 x^2');

    expect(tester.takeException(), isNull);
    expect(find.byType(Math), findsNothing);
  });

  testWidgets('a wide display formula scrolls instead of overflowing', (
    tester,
  ) async {
    await _pump(
      tester,
      r'\[a_1 + a_2 + a_3 + a_4 + a_5 + a_6 + a_7 + a_8 + a_9 + a_{10} + '
      r'a_{11} + a_{12} + a_{13} + a_{14} + a_{15} + a_{16} = \sum_{i=1}^{16} a_i\]',
      width: 240,
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(Math), findsOneWidget);
  });

  testWidgets('inline math lays out inside a narrow table', (tester) async {
    await _pump(
      tester,
      '| Name | Formula |\n'
      '|---|---|\n'
      r'| Energy | \(E = mc^2\) |'
      '\n'
      r'| Root | \(\sqrt{b^2 - 4ac}\) |'
      '\n',
      width: 240,
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(Math), findsNWidgets(2));

    // Measuring the table again after layout asks for the dry baseline a
    // second time; it has to match the first answer.
    tester.view.physicalSize = const Size(300, 800);
    await tester.pump();
    tester.view.physicalSize = const Size(240, 800);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
