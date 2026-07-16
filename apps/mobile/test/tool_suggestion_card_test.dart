import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/features/codex_session/widgets/tool_suggestion_card.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/theme/app_theme.dart';

void main() {
  Widget buildSubject({
    required PermissionRequestMessage permission,
    VoidCallback? onInstall,
    VoidCallback? onComplete,
    VoidCallback? onReject,
    ValueChanged<String>? onOpenUrl,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: ToolSuggestionCard(
          appColors: AppColors.dark(),
          permission: permission,
          onInstall: onInstall ?? () {},
          onComplete: onComplete ?? () {},
          onReject: onReject ?? () {},
          onOpenUrl: onOpenUrl ?? (_) {},
        ),
      ),
    );
  }

  testWidgets('shows install and decline actions for a new suggestion', (
    tester,
  ) async {
    var installed = false;
    var rejected = false;
    await tester.pumpWidget(
      buildSubject(
        permission: const PermissionRequestMessage(
          toolUseId: 'approval-0',
          toolName: 'ToolSuggestion',
          input: {
            'toolName': 'GitHub',
            'toolType': 'plugin',
            'suggestReason': 'Inspect forks and compare their changes.',
            'installState': 'idle',
          },
        ),
        onInstall: () => installed = true,
        onReject: () => rejected = true,
      ),
    );

    expect(find.text('Add GitHub to Codex?'), findsOneWidget);
    expect(
      find.text('Inspect forks and compare their changes.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('tool_suggestion_install_button')),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('tool_suggestion_install_button')),
    );
    await tester.tap(
      find.byKey(const ValueKey('tool_suggestion_decline_button')),
    );
    expect(installed, isTrue);
    expect(rejected, isTrue);
  });

  testWidgets('opens auth URL and completes after app authentication', (
    tester,
  ) async {
    String? openedUrl;
    var completed = false;
    await tester.pumpWidget(
      buildSubject(
        permission: const PermissionRequestMessage(
          toolUseId: 'approval-0',
          toolName: 'ToolSuggestion',
          input: {
            'toolName': 'GitHub',
            'toolType': 'plugin',
            'suggestReason': 'Inspect forks.',
            'installState': 'needs_auth',
            'appsNeedingAuth': [
              {
                'id': 'github-app',
                'name': 'GitHub',
                'installUrl': 'https://example.com/connect/github',
              },
            ],
          },
        ),
        onComplete: () => completed = true,
        onOpenUrl: (url) => openedUrl = url,
      ),
    );

    expect(
      find.byKey(const ValueKey('tool_suggestion_auth_github-app_button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('tool_suggestion_complete_button')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('tool_suggestion_auth_github-app_button')),
    );
    await tester.tap(
      find.byKey(const ValueKey('tool_suggestion_complete_button')),
    );
    expect(openedUrl, 'https://example.com/connect/github');
    expect(completed, isTrue);
  });

  testWidgets('shows progress and installation failure states', (tester) async {
    await tester.pumpWidget(
      buildSubject(
        permission: const PermissionRequestMessage(
          toolUseId: 'approval-0',
          toolName: 'ToolSuggestion',
          input: {'toolName': 'GitHub', 'installState': 'installing'},
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey('tool_suggestion_installing')),
      findsOneWidget,
    );

    await tester.pumpWidget(
      buildSubject(
        permission: const PermissionRequestMessage(
          toolUseId: 'approval-0',
          toolName: 'ToolSuggestion',
          input: {
            'toolName': 'GitHub',
            'installState': 'failed',
            'installError': 'Plugin marketplace unavailable',
          },
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Installation failed'), findsOneWidget);
    expect(
      find.textContaining('Plugin marketplace unavailable'),
      findsOneWidget,
    );
    expect(find.text('Try Again'), findsOneWidget);
  });
}
