import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/features/chat_session/permission_transcript.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/l10n/app_localizations_delegates.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/bubbles/permission_request_bubble.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(body: SingleChildScrollView(child: child)),
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

  testWidgets('collapsed bubble keeps the transcript compact', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const PermissionRequestBubble(
          message: permission,
          isCodex: true,
          status: PermissionTranscriptStatus.pending,
        ),
      ),
    );

    expect(find.text('Command Approval'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('/bin/zsh -lc "mise ls flutter"'), findsOneWidget);
    expect(
      find.text('Verify whether Flutter 3.41.6 finished installing'),
      findsNothing,
    );
    expect(
      find.text('Additional permissions: fileSystem.write=/tmp/project'),
      findsNothing,
    );
  });

  testWidgets('expanded bubble preserves rationale and raw details', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const PermissionRequestBubble(message: permission, isCodex: true)),
    );

    await tester.tap(find.byType(InkWell));
    await tester.pump();

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

  testWidgets('bubble also dedupes duplicated reason line for non-codex', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const PermissionRequestBubble(message: permission, isCodex: false)),
    );

    await tester.tap(find.byType(InkWell));
    await tester.pump();

    expect(
      find.text('Why: Verify whether Flutter 3.41.6 finished installing'),
      findsNothing,
    );
  });

  testWidgets('bubble shows structured MCP approval details', (tester) async {
    const mcpPermission = PermissionRequestMessage(
      toolUseId: 'approval-1',
      toolName: 'McpElicitation',
      input: {
        'serverName': 'dart-mcp',
        'message': 'Tool call needs your approval. Reason: Potentially unsafe action: launching a local application on user\'s machine.',
        '_meta': {
          'tool_description':
              'Launches a Flutter application and returns its DTD URI.',
          'tool_params_display': [
            {
              'name': 'device',
              'display_name': 'device',
              'value': 'iPhone 17 Pro',
            },
            {
              'name': 'root',
              'display_name': 'project',
              'value': '/Users/k9i-mini/Workspace/ccpocket/apps/mobile',
            },
            {
              'name': 'target',
              'display_name': 'target',
              'value': 'lib/main.dart',
            },
          ],
        },
      },
    );

    await tester.pumpWidget(
      _wrap(const PermissionRequestBubble(message: mcpPermission)),
    );

    await tester.tap(find.byType(InkWell));
    await tester.pump();

    expect(find.text('MCP: dart-mcp'), findsOneWidget);
    expect(
      find.text('Launches a Flutter application and returns its DTD URI.'),
      findsOneWidget,
    );
    expect(find.text('Server: dart-mcp'), findsOneWidget);
    expect(find.text('Device: iPhone 17 Pro'), findsOneWidget);
    expect(find.text('Target: lib/main.dart'), findsOneWidget);
    expect(
      find.textContaining('Reason: Tool call needs your approval.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'differentiates pending vs resolved surfaces, badge semantics, and uses code font',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Column(
            children: [
              PermissionRequestBubble(
                key: ValueKey('pending_bubble'),
                message: permission,
                status: PermissionTranscriptStatus.pending,
              ),
              PermissionRequestBubble(
                key: ValueKey('approved_bubble'),
                message: permission,
                status: PermissionTranscriptStatus.approved,
              ),
              PermissionRequestBubble(
                key: ValueKey('rejected_bubble'),
                message: permission,
                status: PermissionTranscriptStatus.rejected,
              ),
            ],
          ),
        ),
      );

      final theme = AppTheme.darkTheme;
      final appColors = theme.extension<AppColors>()!;
      final pendingContainer = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(const ValueKey('pending_bubble')),
              matching: find.byType(Container),
            )
            .first,
      );
      final approvedContainer = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(const ValueKey('approved_bubble')),
              matching: find.byType(Container),
            )
            .first,
      );

      final pendingDeco = pendingContainer.decoration! as BoxDecoration;
      final approvedDeco = approvedContainer.decoration! as BoxDecoration;
      expect(approvedDeco.color, theme.colorScheme.surfaceContainerLow);
      expect(pendingDeco.color, isNot(approvedDeco.color));

      final approvedBadgeText = tester.widget<Text>(find.text('Approved'));
      expect(approvedBadgeText.style?.color, appColors.diffAdditionText);
      expect(approvedBadgeText.style?.color, isNot(theme.colorScheme.primary));

      final rejectedBadgeText = tester.widget<Text>(find.text('Rejected'));
      expect(rejectedBadgeText.style?.color, appColors.diffDeletionText);

      final targetText = tester
          .widgetList<Text>(find.text('/bin/zsh -lc "mise ls flutter"'))
          .first;
      expect(targetText.style?.fontFamily, 'JetBrainsMono');
      expect(targetText.style?.fontFamilyFallback, contains('monospace'));
    },
  );
}
