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

  group('ErrorBubble auth UI', () {
    testWidgets('shows API key guidance for auth_api_error', (tester) async {
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

      expect(find.text('APIキーが必要です'), findsOneWidget);
      expect(
        find.text(
          'Anthropic の現行 Claude Agent SDK ドキュメントでは、'
          'サードパーティ製品で Claude のサブスクリプションログインを'
          '使うことは許可されていません。APIキーをご利用ください。',
        ),
        findsOneWidget,
      );
      expect(find.text('APIキーの取得:'), findsOneWidget);
      expect(find.text('ANTHROPIC_API_KEY=sk-ant-...'), findsOneWidget);
      expect(find.text('console.anthropic.com/settings/keys'), findsOneWidget);
      expect(find.text('手順を見る'), findsNothing);
      expect(find.text('claude'), findsNothing);
      expect(find.text('/login'), findsNothing);
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
        message:
            'Codex CLI is not installed or not available on PATH on the Bridge machine.',
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
        message:
            'You are not logged into any GitHub hosts. To log in, run: gh auth login',
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
