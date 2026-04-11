import 'package:ccpocket/features/session_list/widgets/session_list_app_bar.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/services/revenuecat_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeRevenueCatService extends RevenueCatService {
  FakeRevenueCatService(SupporterState initial)
    : super(publicApiKey: '', platform: TargetPlatform.iOS) {
    supporterState.value = initial;
  }
}

Widget _wrap(Widget child, RevenueCatService revenueCatService) {
  return RepositoryProvider<RevenueCatService>.value(
    value: revenueCatService,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: CustomScrollView(slivers: [child]),
    ),
  );
}

void main() {
  testWidgets('shows supporter badge when active', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SessionListSliverAppBar(onTitleTap: () {}, onDisconnect: () {}),
        FakeRevenueCatService(const SupporterState.active()),
      ),
    );

    expect(find.text('Supporter'), findsOneWidget);
  });

  testWidgets('hides supporter badge when inactive', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SessionListSliverAppBar(onTitleTap: () {}, onDisconnect: () {}),
        FakeRevenueCatService(const SupporterState.inactive()),
      ),
    );

    expect(find.text('Supporter'), findsNothing);
  });
}
