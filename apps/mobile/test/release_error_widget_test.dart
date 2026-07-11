import 'package:ccpocket/widgets/release_error_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ErrorWidgetBuilder originalBuilder;

  setUp(() {
    originalBuilder = ErrorWidget.builder;
    updateReleaseErrorWidgetLocale(const Locale('en'));
    addTearDown(() {
      ErrorWidget.builder = originalBuilder;
      updateReleaseErrorWidgetLocale(null);
    });
  });

  test('keeps the default builder outside release mode', () {
    installReleaseErrorWidget(isReleaseMode: false);

    expect(identical(ErrorWidget.builder, originalBuilder), isTrue);
  });

  test('installs the fallback in release mode', () {
    installReleaseErrorWidget(isReleaseMode: true);

    expect(identical(ErrorWidget.builder, originalBuilder), isFalse);
  });

  test('localizes the generic message without exposing error details', () {
    const messages = {
      'en': "This content couldn't be displayed.",
      'ja': 'このコンテンツを表示できませんでした',
      'ko': '이 콘텐츠를 표시할 수 없습니다.',
      'zh': '无法显示此内容。',
      'fr': "This content couldn't be displayed.",
    };

    for (final entry in messages.entries) {
      expect(releaseErrorMessageForLocale(Locale(entry.key)), entry.value);
    }
  });

  testWidgets('replaces a widget that throws during build', (tester) async {
    installReleaseErrorWidget(isReleaseMode: true);

    try {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: _ThrowingWidget(),
        ),
      );

      expect(tester.takeException(), isA<StateError>());
      final fallback = tester.widget<ReleaseErrorWidget>(
        find.byType(ReleaseErrorWidget),
      );
      expect(fallback.message, "This content couldn't be displayed.");
      expect(fallback.message, isNot(contains('boom')));
      expect(
        fallback.toDiagnosticsNode().toStringDeep(),
        isNot(contains('boom')),
      );
    } finally {
      ErrorWidget.builder = originalBuilder;
    }
  });

  testWidgets('reads the current system locale without an app override', (
    tester,
  ) async {
    updateReleaseErrorWidgetLocale(null);
    tester.binding.platformDispatcher.localeTestValue = const Locale('ja');

    try {
      final fallback =
          buildReleaseErrorWidget(
                FlutterErrorDetails(exception: StateError('boom')),
              )
              as ReleaseErrorWidget;

      expect(fallback.message, 'このコンテンツを表示できませんでした');
    } finally {
      tester.binding.platformDispatcher.clearLocaleTestValue();
    }
  });

  testWidgets('handles zero and tiny constraints without another exception', (
    tester,
  ) async {
    final details = FlutterErrorDetails(exception: StateError('boom'));

    for (final size in [Size.zero, const Size(1, 1)]) {
      await tester.pumpWidget(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox.fromSize(
            size: size,
            child: buildReleaseErrorWidget(details),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(ReleaseErrorWidget)), size);
    }
  });

  testWidgets('exposes the generic message to accessibility services', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final details = FlutterErrorDetails(exception: StateError('boom'));

    try {
      await tester.pumpWidget(
        SizedBox(
          width: 240,
          height: 80,
          child: buildReleaseErrorWidget(details),
        ),
      );

      expect(
        tester.getSemantics(find.byType(ReleaseErrorWidget)).label,
        "This content couldn't be displayed.",
      );
    } finally {
      semantics.dispose();
    }
  });
}

class _ThrowingWidget extends StatelessWidget {
  const _ThrowingWidget();

  @override
  Widget build(BuildContext context) {
    throw StateError('boom');
  }
}
