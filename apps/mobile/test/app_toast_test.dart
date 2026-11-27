import 'package:ccpocket/widgets/app_toast.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  const toastKey = ValueKey('app_toast');

  Future<void> pumpHost(WidgetTester tester, WidgetBuilder body) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Host')),
          body: Builder(builder: body),
          bottomNavigationBar: const SizedBox(
            key: ValueKey('input_bar'),
            height: 80,
          ),
        ),
      ),
    );
  }

  testWidgets('appears under the app bar, clear of the bottom input', (
    tester,
  ) async {
    await pumpHost(
      tester,
      (context) => TextButton(
        onPressed: () => AppToast.of(context).show('Copied'),
        child: const Text('Show'),
      ),
    );
    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();

    final toast = tester.getRect(find.byKey(toastKey));
    expect(toast.top, greaterThanOrEqualTo(kToolbarHeight));
    expect(
      toast.bottom,
      lessThan(tester.getRect(find.byKey(const ValueKey('input_bar'))).top),
    );
    expect(toast.overlaps(tester.getRect(find.byType(AppBar))), isFalse);
  });

  testWidgets('disappears after its duration and replaces an earlier toast', (
    tester,
  ) async {
    late AppToastMessenger messenger;
    await pumpHost(tester, (context) {
      messenger = AppToast.of(context);
      return const SizedBox.shrink();
    });

    messenger.show('First', duration: const Duration(seconds: 1));
    await tester.pump();
    messenger.show('Second', duration: const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byKey(toastKey), findsNothing);
  });

  testWidgets('tapping dismisses it and the action runs once', (tester) async {
    var copied = 0;
    late AppToastMessenger messenger;
    await pumpHost(tester, (context) {
      messenger = AppToast.of(context);
      return const SizedBox.shrink();
    });

    messenger.show(
      'Could not open',
      action: AppToastAction(label: 'Copy', onPressed: () => copied++),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(copied, 1);
    expect(find.byKey(toastKey), findsNothing);

    messenger.show('Plain');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(toastKey));
    await tester.pumpAndSettle();
    expect(find.byKey(toastKey), findsNothing);
  });

  testWidgets('stays on top of a sheet opened before or after it', (
    tester,
  ) async {
    await pumpHost(
      tester,
      (context) => TextButton(
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (sheetContext) => SizedBox.expand(
            child: Center(
              child: TextButton(
                onPressed: () => AppToast.of(sheetContext).show('From sheet'),
                child: const Text('Toast'),
              ),
            ),
          ),
        ),
        child: const Text('Open sheet'),
      ),
    );

    // Toast shown from inside an open sheet.
    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Toast'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(toastKey));
    await tester.pumpAndSettle();
    expect(find.byKey(toastKey), findsNothing);
    expect(find.text('Toast'), findsOneWidget, reason: 'sheet stays open');

    // Toast already showing when another route is pushed over it.
    await tester.tap(find.text('Toast'));
    await tester.pump();
    showDialog<void>(
      context: tester.element(find.text('Toast')),
      builder: (_) => const AlertDialog(content: Text('Dialog')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Dialog'), findsOneWidget);
    await tester.tap(find.byKey(toastKey));
    await tester.pumpAndSettle();
    expect(find.byKey(toastKey), findsNothing);
    expect(find.text('Dialog'), findsOneWidget, reason: 'dialog stays open');
  });

  testWidgets('a messenger captured before the screen closed does nothing', (
    tester,
  ) async {
    late AppToastMessenger messenger;
    await pumpHost(tester, (context) {
      messenger = AppToast.of(context);
      return const SizedBox.shrink();
    });
    await tester.pumpWidget(const SizedBox.shrink());

    expect(messenger.mounted, isFalse);
    messenger.show('Late');
    await tester.pump();
    expect(find.text('Late'), findsNothing);
  });
}
