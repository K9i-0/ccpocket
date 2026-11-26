import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/markdown/ccpocket_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  // Table columns holding an inline widget size to their real content, which
  // goes through intrinsic measurement. The colour swatch is a
  // baseline-aligned WidgetSpan, the case most likely to trip that path.
  testWidgets('a table with colour swatches and images lays out when narrow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: SingleChildScrollView(
            child: CcpocketMarkdown(
              data:
                  '| Name | Colour | Shot |\n'
                  '|---|---|---|\n'
                  '| Primary | `#FF5733` | ![login screen](shots/login.png) |\n'
                  '| A much longer name here | `#00AA88` text `lib/main.dart` | |\n',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    final swatchCell = tester.getSize(
      find.textContaining('#FF5733', findRichText: true).first,
    );
    expect(swatchCell.width, greaterThan(60));
    expect(swatchCell.height, lessThan(40), reason: 'must stay on one line');
  });
}
