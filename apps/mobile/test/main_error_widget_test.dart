import 'package:ccpocket/main.dart' as app_main;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('does not install the release fallback outside release mode', () {
    final originalBuilder = ErrorWidget.builder;

    app_main.installReleaseErrorWidget(isReleaseMode: false);

    expect(identical(ErrorWidget.builder, originalBuilder), isTrue);
  });

  test('installs the release fallback in release mode', () {
    final originalBuilder = ErrorWidget.builder;

    app_main.installReleaseErrorWidget(isReleaseMode: true);

    expect(identical(ErrorWidget.builder, originalBuilder), isFalse);
    ErrorWidget.builder = originalBuilder;
  });

  testWidgets('release fallback renders a scoped error message', (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: app_main.buildReleaseErrorWidget(
          FlutterErrorDetails(exception: StateError('boom')),
        ),
      ),
    );

    expect(
      find.text('Something went wrong rendering this content.'),
      findsOneWidget,
    );
  });
}
