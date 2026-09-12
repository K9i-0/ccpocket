import 'package:flutter_test/flutter_test.dart';

/// Image codecs and rasterization finish outside the widget test's fake clock.
Future<void> pumpNativeImageUntil(
  WidgetTester tester,
  bool Function() ready,
) async {
  await tester.pump();
  for (var attempt = 0; attempt < 200; attempt++) {
    if (ready()) {
      await tester.pumpAndSettle();
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  fail('Native image operation did not finish');
}
