import 'package:ccpocket/features/session_link/session_link_screen.dart';
import 'package:ccpocket/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );
  }

  testWidgets('shows a friendly unavailable state with a recovery action', (
    tester,
  ) async {
    var openedRecentSessions = false;
    await tester.pumpWidget(
      wrap(
        SessionLinkStatusView(
          unavailable: true,
          resuming: false,
          onOpenRecentSessions: () => openedRecentSessions = true,
        ),
      ),
    );

    expect(find.text('Session unavailable'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('open_recent_sessions_button')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('open_recent_sessions_button')));
    expect(openedRecentSessions, isTrue);
  });

  testWidgets('distinguishes resolving from resuming', (tester) async {
    await tester.pumpWidget(
      wrap(
        SessionLinkStatusView(
          unavailable: false,
          resuming: false,
          onOpenRecentSessions: () {},
        ),
      ),
    );
    expect(find.text('Finding session...'), findsOneWidget);

    await tester.pumpWidget(
      wrap(
        SessionLinkStatusView(
          unavailable: false,
          resuming: true,
          onOpenRecentSessions: () {},
        ),
      ),
    );
    expect(find.text('Resuming session...'), findsOneWidget);
  });

  testWidgets(
    'read-only history exposes refresh, resume-when-idle, and Remote guidance',
    (tester) async {
      var refreshCount = 0;
      var resumeCount = 0;
      var remoteCount = 0;
      await tester.pumpWidget(
        wrap(
          SessionLinkStatusView(
            unavailable: false,
            resuming: false,
            readOnly: true,
            reason: 'external_owner_active',
            onRefresh: () => refreshCount++,
            onResumeWhenIdle: () => resumeCount++,
            onOpenRemoteGuidance: () => remoteCount++,
            onOpenRecentSessions: () {},
          ),
        ),
      );

      expect(find.text('Read-only history'), findsOneWidget);
      expect(find.textContaining('external owner'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('refresh_session_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('resume_when_idle_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('official_remote_guidance_button')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('message_input')), findsNothing);
      expect(find.byKey(const ValueKey('approve_button')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('refresh_session_button')));
      await tester.tap(find.byKey(const ValueKey('resume_when_idle_button')));
      await tester.tap(
        find.byKey(const ValueKey('official_remote_guidance_button')),
      );
      expect((refreshCount, resumeCount, remoteCount), (1, 1, 1));
    },
  );

  testWidgets('unavailable renders the scoped failure and recovery action', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        SessionLinkStatusView(
          unavailable: true,
          resuming: false,
          reason: 'stale_generation',
          recoveryAction: 'refresh_sessions',
          onOpenRecentSessions: () {},
        ),
      ),
    );

    expect(find.textContaining('stale generation'), findsOneWidget);
    expect(find.textContaining('refresh sessions'), findsOneWidget);
  });
}
