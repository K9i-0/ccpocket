import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/bubbles/error_bubble.dart';

Widget _wrapErrorBubble({required Widget child, required Locale locale}) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: locale,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('renders Codex warnings with a warning title', (tester) async {
    await tester.pumpWidget(
      _wrapErrorBubble(
        locale: const Locale('en'),
        child: const ErrorBubble(
          message: ErrorMessage(
            message: 'Check your Codex configuration.',
            errorCode: 'codex_warning',
          ),
        ),
      ),
    );

    expect(find.text('Codex Warning'), findsOneWidget);
    expect(find.text('Check your Codex configuration.'), findsOneWidget);
  });

  group('ErrorBubble protocol guidance', () {
    testWidgets('asks for an App update when the Bridge protocol is newer', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapErrorBubble(
          locale: const Locale('en'),
          child: const ErrorBubble(
            message: ErrorMessage(
              message: 'Protocol ranges do not overlap.',
              errorCode: 'incompatible_protocol',
              protocolVersion: 2,
              minimumProtocolVersion: 2,
            ),
          ),
        ),
      );

      expect(
        find.text(
          'Update CC Pocket from the source where you installed it, then reconnect.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.copy), findsNothing);
    });

    testWidgets('offers the pinned command when the Bridge must be updated', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapErrorBubble(
          locale: const Locale('en'),
          child: const ErrorBubble(
            message: ErrorMessage(
              message: 'Protocol ranges do not overlap.',
              errorCode: 'incompatible_protocol',
              protocolVersion: 0,
              minimumProtocolVersion: 0,
            ),
          ),
        ),
      );

      expect(
        find.text(
          'The protocol declaration is invalid or incomplete. Update both CC Pocket and the Bridge before reconnecting.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.copy), findsOneWidget);
    });
  });

  group('ErrorBubble auth UI', () {
    testWidgets('shows generic authentication guidance for auth_api_error', (
      tester,
    ) async {
      const message = ErrorMessage(
        message: 'Failed to authenticate. API Error: 401 terminated',
        errorCode: 'auth_api_error',
      );

      await tester.pumpWidget(
        _wrapErrorBubble(
          locale: const Locale('ja'),
          child: const ErrorBubble(message: message),
        ),
      );

      expect(find.text('Authentication Error'), findsOneWidget);
      expect(find.text(message.message), findsOneWidget);
      expect(
        find.text('Set ANTHROPIC_API_KEY on the Bridge machine'),
        findsOneWidget,
      );
      expect(find.text('手順を見る'), findsNothing);
      expect(find.text('claude'), findsNothing);
      expect(find.text('/login'), findsNothing);
    });

    testWidgets('shows subscription opt-in guidance for dedicated error', (
      tester,
    ) async {
      const message = ErrorMessage(
        message: 'Claude subscription authentication requires explicit opt-in',
        errorCode: 'claude_oauth_opt_in_required',
      );

      await tester.pumpWidget(
        _wrapErrorBubble(
          locale: const Locale('ja'),
          child: const ErrorBubble(message: message),
        ),
      );

      expect(find.text('サブスクリプション認証には明示的な有効化が必要です'), findsOneWidget);
      expect(
        find.text(
          'Anthropicはホストされた未改変のClaude Codeへのユーザー自身のログインを認める一方、'
          'Agent SDKガイドでは第三者製品にAPIキーを案内しています。'
          'そのためCC Pocketではサブスクリプション認証をデフォルトで無効にしています。',
        ),
        findsOneWidget,
      );
      expect(find.text('BRIDGE_ALLOW_CLAUDE_OAUTH=1'), findsOneWidget);
      expect(find.text('console.anthropic.com/settings/keys'), findsOneWidget);
      expect(find.byKey(const ValueKey('auth_help_button')), findsOneWidget);
    });

    testWidgets('keeps non-auth error layout unchanged', (tester) async {
      const message = ErrorMessage(
        message: 'Project path not allowed',
        errorCode: 'path_not_allowed',
      );

      await tester.pumpWidget(
        _wrapErrorBubble(
          locale: const Locale('en'),
          child: const ErrorBubble(message: message),
        ),
      );

      expect(find.text('Path Not Allowed'), findsOneWidget);
      expect(find.text('Project path not allowed'), findsOneWidget);
      expect(find.text('View steps'), findsNothing);
    });

    testWidgets('shows Codex CLI install guidance', (tester) async {
      const message = ErrorMessage(
        message: 'Codex CLI is not installed or not available on PATH on the Bridge machine.',
        errorCode: 'codex_cli_not_found',
      );

      await tester.pumpWidget(
        _wrapErrorBubble(
          locale: const Locale('en'),
          child: const ErrorBubble(message: message),
        ),
      );

      expect(find.text('Codex CLI Not Installed'), findsOneWidget);
      expect(
        find.text(
          'Install Codex CLI on the Bridge machine, then restart Bridge',
        ),
        findsOneWidget,
      );
    });

    testWidgets('does not show Claude login card for GitHub CLI auth text', (
      tester,
    ) async {
      const message = ErrorMessage(
        message: 'You are not logged into any GitHub hosts. To log in, run: gh auth login',
      );

      await tester.pumpWidget(
        _wrapErrorBubble(
          locale: const Locale('en'),
          child: const ErrorBubble(message: message),
        ),
      );

      expect(find.text('Claude login required'), findsNothing);
      expect(find.text('claude'), findsNothing);
      expect(find.text('/login'), findsNothing);
      expect(find.textContaining('gh auth login'), findsOneWidget);
    });
  });
}
