import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/bubbles/system_chip.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('renders codex init messages as environment summary', (
    tester,
  ) async {
    const message = SystemMessage(
      subtype: 'init',
      provider: 'codex',
      model: 'gpt-5.4',
      sandboxMode: 'workspace-write',
    );

    await tester.pumpWidget(_wrap(const SystemChip(message: message)));

    expect(find.text('Session started'), findsOneWidget);
    expect(find.text('gpt-5.4 Default'), findsOneWidget);
    expect(find.text('Sandbox'), findsOneWidget);
    expect(find.text('System: init'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'renders non-session-created system messages even with model set',
    (tester) async {
      const message = SystemMessage(
        subtype: 'supported_commands',
        provider: 'codex',
        model: 'gpt-5.4',
      );

      await tester.pumpWidget(_wrap(const SystemChip(message: message)));

      expect(find.text('System: supported_commands'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
