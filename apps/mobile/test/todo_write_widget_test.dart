import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/bubbles/todo_write_widget.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

Map<String, dynamic> _buildInput(List<Map<String, dynamic>> todos) {
  return {'todos': todos};
}

Map<String, dynamic> _todo(
  String content,
  String status, [
  String activeForm = '',
]) {
  return {'content': content, 'status': status, 'activeForm': activeForm};
}

void main() {
  group('TodoWriteWidget - empty', () {
    testWidgets('empty todos renders nothing', (tester) async {
      await tester.pumpWidget(_wrap(TodoWriteWidget(input: _buildInput([]))));
      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.text('Tasks'), findsNothing);
    });
  });

  group('TodoWriteWidget - no truncation (4 or fewer)', () {
    testWidgets('3 items shows all items without more indicator', (
      tester,
    ) async {
      final input = _buildInput([
        _todo('Task 1', 'completed'),
        _todo('Task 2', 'pending'),
        _todo('Task 3', 'pending'),
      ]);
      await tester.pumpWidget(_wrap(TodoWriteWidget(input: input)));

      expect(find.text('Task 1'), findsOneWidget);
      expect(find.text('Task 2'), findsOneWidget);
      expect(find.text('Task 3'), findsOneWidget);
      expect(find.textContaining('more'), findsNothing);
    });
  });

  group('TodoWriteWidget - Codex plan update', () {
    testWidgets('shows custom title and explanation', (tester) async {
      final input = {
        'title': 'Plan update',
        'explanation': 'Initial plan drafted',
        'todos': [
          _todo('Gather requirements', 'in_progress'),
          _todo('Write tests', 'pending'),
          _todo('Implement fix', 'completed'),
        ],
      };
      await tester.pumpWidget(_wrap(TodoWriteWidget(input: input)));

      expect(find.text('Plan update'), findsOneWidget);
      expect(find.text('Initial plan drafted'), findsOneWidget);
      expect(find.text('Gather requirements'), findsOneWidget);
      expect(find.text('Write tests'), findsOneWidget);
      expect(find.text('Implement fix'), findsOneWidget);
    });
  });

  group('TodoWriteWidget - truncation (5+ items)', () {
    testWidgets('7 items shows 4 + "and 3 more"', (tester) async {
      final input = _buildInput([
        _todo('Task 1', 'completed'),
        _todo('Task 2', 'completed'),
        _todo('Task 3', 'pending'),
        _todo('Task 4', 'pending'),
        _todo('Task 5', 'pending'),
        _todo('Task 6', 'pending'),
        _todo('Task 7', 'pending'),
      ]);
      await tester.pumpWidget(_wrap(TodoWriteWidget(input: input)));

      // First 4 visible
      expect(find.text('Task 1'), findsOneWidget);
      expect(find.text('Task 2'), findsOneWidget);
      expect(find.text('Task 3'), findsOneWidget);
      expect(find.text('Task 4'), findsOneWidget);
      // 5-7 hidden
      expect(find.text('Task 5'), findsNothing);
      expect(find.text('Task 6'), findsNothing);
      expect(find.text('Task 7'), findsNothing);
      // More indicator
      expect(find.textContaining('3 more'), findsOneWidget);
    });

    testWidgets('tap "more" expands to show all items', (tester) async {
      final input = _buildInput([
        _todo('Task 1', 'completed'),
        _todo('Task 2', 'completed'),
        _todo('Task 3', 'pending'),
        _todo('Task 4', 'pending'),
        _todo('Task 5', 'pending'),
        _todo('Task 6', 'pending'),
        _todo('Task 7', 'pending'),
      ]);
      await tester.pumpWidget(_wrap(TodoWriteWidget(input: input)));

      // Tap the "more" indicator
      await tester.tap(find.textContaining('3 more'));
      await tester.pump();

      // All items now visible
      expect(find.text('Task 5'), findsOneWidget);
      expect(find.text('Task 6'), findsOneWidget);
      expect(find.text('Task 7'), findsOneWidget);
      // "more" gone
      expect(find.textContaining('more'), findsNothing);
    });

    testWidgets('expanded state shows "Show less" and can collapse', (
      tester,
    ) async {
      final input = _buildInput([
        _todo('Task 1', 'completed'),
        _todo('Task 2', 'completed'),
        _todo('Task 3', 'pending'),
        _todo('Task 4', 'pending'),
        _todo('Task 5', 'pending'),
        _todo('Task 6', 'pending'),
        _todo('Task 7', 'pending'),
      ]);
      await tester.pumpWidget(_wrap(TodoWriteWidget(input: input)));

      // Expand
      await tester.tap(find.textContaining('3 more'));
      await tester.pump();

      // "Show less" should appear
      expect(find.textContaining('Show less'), findsOneWidget);

      // Tap "Show less" to collapse
      await tester.tap(find.textContaining('Show less'));
      await tester.pump();

      // Back to truncated
      expect(find.text('Task 5'), findsNothing);
      expect(find.textContaining('3 more'), findsOneWidget);
    });
  });

  group('TodoWriteWidget - in_progress + truncation', () {
    testWidgets('in_progress shown separately, others truncated', (
      tester,
    ) async {
      final input = _buildInput([
        _todo('Active task', 'in_progress', 'Running active task'),
        _todo('Task 1', 'completed'),
        _todo('Task 2', 'pending'),
        _todo('Task 3', 'pending'),
        _todo('Task 4', 'pending'),
        _todo('Task 5', 'pending'),
        _todo('Task 6', 'pending'),
      ]);
      await tester.pumpWidget(_wrap(TodoWriteWidget(input: input)));

      // in_progress always shown
      expect(find.text('Active task'), findsOneWidget);
      expect(find.text('Running active task'), findsOneWidget);

      // First 4 non-in_progress shown
      expect(find.text('Task 1'), findsOneWidget);
      expect(find.text('Task 2'), findsOneWidget);
      expect(find.text('Task 3'), findsOneWidget);
      expect(find.text('Task 4'), findsOneWidget);

      // Rest hidden
      expect(find.text('Task 5'), findsNothing);
      expect(find.text('Task 6'), findsNothing);
      expect(find.textContaining('2 more'), findsOneWidget);
    });
  });

  group('TodoWriteWidget - PageStorage persistence', () {
    testWidgets('expanded state persists across rebuilds', (tester) async {
      final input = _buildInput([
        _todo('Task 1', 'pending'),
        _todo('Task 2', 'pending'),
        _todo('Task 3', 'pending'),
        _todo('Task 4', 'pending'),
        _todo('Task 5', 'pending'),
        _todo('Task 6', 'pending'),
      ]);

      final bucket = PageStorageBucket();
      Widget buildWidget() {
        return MaterialApp(
          theme: AppTheme.darkTheme,
          home: PageStorage(
            bucket: bucket,
            child: Scaffold(
              body: SingleChildScrollView(child: TodoWriteWidget(input: input)),
            ),
          ),
        );
      }

      // Initial: collapsed
      await tester.pumpWidget(buildWidget());
      expect(find.text('Task 5'), findsNothing);

      // Expand
      await tester.tap(find.textContaining('2 more'));
      await tester.pump();
      expect(find.text('Task 5'), findsOneWidget);

      // Rebuild widget tree (simulates scroll off/on screen)
      await tester.pumpWidget(buildWidget());

      // Still expanded after rebuild
      expect(find.text('Task 5'), findsOneWidget);
      expect(find.text('Task 6'), findsOneWidget);
    });
  });
}
