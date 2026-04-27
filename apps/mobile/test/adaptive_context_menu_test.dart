import 'package:ccpocket/widgets/adaptive_context_menu.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('opens action menu on secondary click', (tester) async {
    String? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) {
                return AdaptiveContextMenuRegion(
                  onOpen: (position) async {
                    selected = await showAdaptiveActionMenu<String>(
                      context: context,
                      position: position,
                      items: const [
                        AdaptiveActionMenuItem(
                          value: 'copy',
                          icon: Icons.copy,
                          label: 'Copy',
                        ),
                      ],
                    );
                  },
                  child: const SizedBox(
                    width: 120,
                    height: 80,
                    child: Center(child: Text('Target')),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(
      tester.getCenter(find.text('Target')),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();

    expect(find.text('Copy'), findsOneWidget);

    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();

    expect(selected, 'copy');
  });
}
