import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/models/messages.dart';
import 'package:ccpocket/theme/app_theme.dart';
import 'package:ccpocket/widgets/bubbles/guardian_approval_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows a compact notice and expands approval details', (
    tester,
  ) async {
    const reason =
        'Launching the app writes build files outside the workspace.';
    await tester.pumpWidget(
      _wrap(
        const GuardianApprovalMessage(
          risk: GuardianApprovalRisk.medium,
          reason: reason,
          authorization: 'medium',
        ),
      ),
    );

    expect(find.text('Auto Review approved'), findsOneWidget);
    expect(find.text('· Medium risk'), findsOneWidget);
    expect(find.text(reason), findsNothing);
    expect(find.byIcon(Icons.warning_amber), findsNothing);
    expect(find.byIcon(Icons.error_outline), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('guardian_approval_details_button')),
    );
    await tester.pumpAndSettle();

    expect(find.text(reason), findsOneWidget);
    expect(find.text('Authorization: medium'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('localizes the high-risk label', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const GuardianApprovalMessage(
          risk: GuardianApprovalRisk.high,
          reason: 'ワークスペース外のファイルを変更します。',
        ),
        locale: const Locale('ja'),
      ),
    );

    expect(find.text('自動レビューで承認'), findsOneWidget);
    expect(find.text('· 高リスク'), findsOneWidget);
  });
}

Widget _wrap(GuardianApprovalMessage message, {Locale? locale}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.darkTheme,
    home: Scaffold(body: GuardianApprovalNotice(message: message)),
  );
}
