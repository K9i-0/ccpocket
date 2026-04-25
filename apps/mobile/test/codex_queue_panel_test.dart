import 'package:ccpocket/features/codex_session/codex_session_screen.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CodexQueuedInputPanel exposes steer edit and cancel actions', (
    tester,
  ) async {
    var steered = false;
    var edited = false;
    var canceled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CodexQueuedInputPanel(
            item: const QueuedInputItem(
              itemId: 'q1',
              text: 'Follow up after this turn',
              createdAt: '2026-04-25T00:00:00.000Z',
            ),
            onSteer: () => steered = true,
            onEdit: () => edited = true,
            onCancel: () => canceled = true,
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('codex_queue_panel')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('codex_queue_steer_button')),
      findsOneWidget,
    );
    expect(find.text('Follow up after this turn'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('codex_queue_steer_button')));
    expect(steered, isTrue);

    await tester.tap(find.byKey(const ValueKey('codex_queue_edit_button')));
    expect(edited, isTrue);

    await tester.tap(find.byKey(const ValueKey('codex_queue_cancel_button')));
    expect(canceled, isTrue);
  });

  test('moveQueuedInputToComposer cancels queue and overwrites input text', () {
    var canceled = false;
    final controller = TextEditingController(text: 'existing draft');
    addTearDown(controller.dispose);

    moveQueuedInputToComposer(
      inputController: controller,
      item: const QueuedInputItem(
        itemId: 'q1',
        text: 'Queued replacement',
        createdAt: '2026-04-25T00:00:00.000Z',
      ),
      cancelQueuedInput: () => canceled = true,
    );

    expect(canceled, isTrue);
    expect(controller.text, 'Queued replacement');
    expect(controller.selection.baseOffset, 'Queued replacement'.length);
  });
}
