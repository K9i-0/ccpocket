import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:ccpocket/features/session_link/session_link_screen.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:ccpocket/l10n/app_localizations_delegates.dart';
import 'package:ccpocket/router/app_router.dart';
import 'package:ccpocket/services/bridge_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _SessionLinkBridge extends BridgeService {
  var resolution = Completer<SessionLinkResolveResult>();

  @override
  Future<SessionLinkResolveResult> resolveSessionLink(
    String sessionId, {
    String provider = 'claude',
    Duration timeout = const Duration(seconds: 10),
  }) {
    return resolution.future;
  }
}

final _originPage = PageInfo(
  'OriginRoute',
  builder: (_) => const Scaffold(body: Center(child: Text('origin screen'))),
);

class _TestRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
    AutoRoute(page: _originPage, path: '/', initial: true),
    CustomRoute(
      page: SessionLinkRoute.page,
      path: '/session-link/:sessionId',
      opaque: false,
      transitionsBuilder: TransitionsBuilders.fadeIn,
    ),
  ];
}

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );
  }

  testWidgets('distinguishes resolving from resuming', (tester) async {
    await tester.pumpWidget(wrap(const SessionLinkStatusView(resuming: false)));
    expect(find.text('Finding session...'), findsOneWidget);

    await tester.pumpWidget(wrap(const SessionLinkStatusView(resuming: true)));
    expect(find.text('Resuming session...'), findsOneWidget);
  });

  testWidgets(
    'an unavailable link returns to the origin screen with a snackbar',
    (tester) async {
      final bridge = _SessionLinkBridge();
      addTearDown(bridge.dispose);
      final router = _TestRouter();
      await tester.pumpWidget(
        RepositoryProvider<BridgeService>.value(
          value: bridge,
          child: MaterialApp.router(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router.config(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      unawaited(router.push(SessionLinkRoute(sessionId: 'stopped-session')));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // The origin screen stays visible underneath while the link resolves.
      expect(find.text('Finding session...'), findsOneWidget);
      expect(find.text('origin screen'), findsOneWidget);

      bridge.resolution.complete(const SessionLinkResolveResult.unavailable());
      await tester.pumpAndSettle();

      expect(router.stack, hasLength(1));
      expect(router.current.name, 'OriginRoute');
      expect(find.text('origin screen'), findsOneWidget);
      expect(find.text('Finding session...'), findsNothing);
      expect(find.text('Session unavailable'), findsNothing);
      expect(
        find.byKey(const ValueKey('session_link_unavailable_snackbar')),
        findsOneWidget,
      );
    },
  );

  testWidgets('a failure is not reported once another link has been opened', (
    tester,
  ) async {
    final bridge = _SessionLinkBridge();
    addTearDown(bridge.dispose);
    final router = _TestRouter();
    await tester.pumpWidget(
      RepositoryProvider<BridgeService>.value(
        value: bridge,
        child: MaterialApp.router(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router.config(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    unawaited(router.push(SessionLinkRoute(sessionId: 'first')));
    await tester.pump();
    await tester.pump();
    bridge.resolution.complete(const SessionLinkResolveResult.unavailable());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // The second link is opened before the first failure is reported.
    bridge.resolution = Completer<SessionLinkResolveResult>();
    unawaited(router.push(SessionLinkRoute(sessionId: 'second')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Finding session...'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('session_link_unavailable_snackbar')),
      findsNothing,
    );

    bridge.resolution.complete(const SessionLinkResolveResult.unavailable());
    await tester.pumpAndSettle();

    expect(router.stack, hasLength(1));
    expect(
      find.byKey(const ValueKey('session_link_unavailable_snackbar')),
      findsOneWidget,
    );
  });
}
