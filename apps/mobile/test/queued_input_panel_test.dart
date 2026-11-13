import 'package:ccpocket/features/chat_session/widgets/queued_input_panel.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/l10n/app_localizations_delegates.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('unknown reset stays queued without promising a send time', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        QueuedInputPanel(
          item: const QueuedInputItem(
            itemId: 'unknown',
            text: 'Wait',
            createdAt: '',
            waitingForUsageLimit: true,
          ),
          onSteer: null,
          onEdit: () {},
          onCancel: () {},
        ),
      ),
    );
    expect(
      find.text('Waiting for usage limit · checking reset time'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('codex_queue_steer_button')),
      findsNothing,
    );
  });

  testWidgets('usage-limit queue shows reset time and keeps edit and cancel', (
    tester,
  ) async {
    var edited = false;
    var canceled = false;
    final item = QueuedInputItem.fromJson({
      'itemId': 'limit-queue',
      'text': 'After the limit',
      'createdAt': '2026-11-03T01:00:00Z',
      'retryAt': '2026-11-03T02:40:00Z',
    });
    await tester.pumpWidget(
      _wrap(
        QueuedInputPanel(
          item: item,
          onSteer: () => fail('must not steer during limit'),
          onEdit: () => edited = true,
          onCancel: () => canceled = true,
        ),
      ),
    );
    expect(item.retryAt, '2026-11-03T02:40:00Z');
    expect(find.textContaining('Usage limit · scheduled for'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('codex_queue_steer_button')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('codex_queue_edit_button')));
    await tester.tap(find.byKey(const ValueKey('codex_queue_cancel_button')));
    expect(edited, isTrue);
    expect(canceled, isTrue);
  });

  testWidgets('QueuedInputPanel exposes steer edit and cancel actions', (
    tester,
  ) async {
    var steered = false;
    var edited = false;
    var canceled = false;

    await tester.pumpWidget(
      _wrap(
        QueuedInputPanel(
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

  testWidgets('QueuedInputPanel shows reconnect copy for offline queue', (
    tester,
  ) async {
    var edited = false;
    var canceled = false;

    await tester.pumpWidget(
      _wrap(
        QueuedInputPanel(
          item: const QueuedInputItem(
            itemId: 'offline:cm1',
            text: 'Offline pending message',
            createdAt: '2026-04-25T00:00:00.000Z',
          ),
          isOfflinePending: true,
          onSteer: null,
          onEdit: () => edited = true,
          onCancel: () => canceled = true,
        ),
      ),
    );

    expect(find.text('Queued for reconnect'), findsOneWidget);
    final steerButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('codex_queue_steer_button')),
    );
    expect(steerButton.onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('codex_queue_edit_button')));
    expect(edited, isTrue);

    await tester.tap(find.byKey(const ValueKey('codex_queue_cancel_button')));
    expect(canceled, isTrue);
  });

  testWidgets('QueuedInputPanel hides steer for delivery pending', (
    tester,
  ) async {
    var edited = false;
    var canceled = false;

    await tester.pumpWidget(
      _wrap(
        QueuedInputPanel(
          item: const QueuedInputItem(
            itemId: 'pending:cm1',
            text: 'Slow delivery message',
            createdAt: '2026-04-25T00:00:00.000Z',
          ),
          isDeliveryPending: true,
          onSteer: null,
          onEdit: () => edited = true,
          onCancel: () => canceled = true,
        ),
      ),
    );

    expect(find.text('Pending delivery'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('codex_queue_steer_button')),
      findsNothing,
    );

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
