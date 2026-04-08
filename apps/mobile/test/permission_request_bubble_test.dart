import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/bubbles/permission_request_bubble.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    home: Scaffold(body: child),
  );
}

void main() {
  const permission = PermissionRequestMessage(
    toolUseId: 'tu-why',
    toolName: 'Bash',
    input: {
      'command': '/bin/zsh -lc "mise ls flutter"',
      'reason': 'Verify whether Flutter 3.41.6 finished installing',
      'additionalPermissions': {
        'fileSystem': {
          'write': ['/tmp/project'],
        },
      },
    },
  );

  testWidgets('codex bubble hides duplicated Why line', (tester) async {
    await tester.pumpWidget(
      _wrap(const PermissionRequestBubble(message: permission, isCodex: true)),
    );

    expect(
      find.text('Verify whether Flutter 3.41.6 finished installing'),
      findsOneWidget,
    );
    expect(
      find.text('Why: Verify whether Flutter 3.41.6 finished installing'),
      findsNothing,
    );
    expect(
      find.text('Additional permissions: fileSystem.write=/tmp/project'),
      findsOneWidget,
    );
  });

  testWidgets('claude bubble keeps Why line', (tester) async {
    await tester.pumpWidget(
      _wrap(const PermissionRequestBubble(message: permission, isCodex: false)),
    );

    expect(
      find.text('Why: Verify whether Flutter 3.41.6 finished installing'),
      findsOneWidget,
    );
  });
}
