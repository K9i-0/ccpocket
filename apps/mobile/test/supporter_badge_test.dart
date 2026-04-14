import 'package:ccpocket/features/session_list/widgets/session_list_app_bar.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: CustomScrollView(slivers: [child]),
  );
}

void main() {
  testWidgets('shows app title without supporter badge', (tester) async {
    await tester.pumpWidget(
      _wrap(SessionListSliverAppBar(onTitleTap: () {}, onDisconnect: () {})),
    );

    final l = AppLocalizations.of(
      tester.element(find.byType(SessionListSliverAppBar)),
    );
    expect(find.text(l.appTitle), findsOneWidget);
    expect(find.text(l.supporterTitle), findsNothing);
  });
}
