import 'package:ccpocket/services/notification_service.dart';
import 'package:ccpocket/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('local notification fallback', () {
    test('stays silent while the app is foregrounded', () {
      expect(
        shouldUseLocalNotificationFallback(
          isBackground: false,
          localNotificationsAllowed: true,
          remoteNotificationsReady: false,
        ),
        isFalse,
      );
    });

    test('notifies in the background when remote push is unavailable', () {
      expect(
        shouldUseLocalNotificationFallback(
          isBackground: true,
          localNotificationsAllowed: true,
          remoteNotificationsReady: false,
        ),
        isTrue,
      );
    });

    test('defers to remote push in the background when enabled', () {
      expect(
        shouldUseLocalNotificationFallback(
          isBackground: true,
          localNotificationsAllowed: true,
          remoteNotificationsReady: true,
        ),
        isFalse,
      );
    });

    test('stays silent when the user disabled notifications', () {
      expect(
        shouldUseLocalNotificationFallback(
          isBackground: true,
          localNotificationsAllowed: false,
          remoteNotificationsReady: false,
        ),
        isFalse,
      );
    });
  });

  group('session notification identity', () {
    test('round-trips a Codex target without exposing it as Claude', () {
      final payload = sessionNotificationPayload(
        sessionId: 'session-1',
        provider: 'codex',
      );

      final target = parseSessionNotificationPayload(payload);
      expect(target?.sessionId, 'session-1');
      expect(target?.provider, 'codex');
    });

    test('keeps legacy plain payloads compatible with Claude', () {
      final target = parseSessionNotificationPayload('legacy-session');

      expect(target?.sessionId, 'legacy-session');
      expect(target?.provider, 'claude');
    });

    test('uses stable IDs without cross-session or cross-provider overlap', () {
      final first = sessionNotificationId(
        sessionId: 'session-1',
        provider: 'claude',
        eventType: SessionNotificationEvent.approval,
      );

      expect(
        sessionNotificationId(
          sessionId: 'session-1',
          provider: 'claude',
          eventType: SessionNotificationEvent.approval,
        ),
        first,
      );
      expect(
        sessionNotificationId(
          sessionId: 'session-2',
          provider: 'claude',
          eventType: SessionNotificationEvent.approval,
        ),
        isNot(first),
      );
      expect(
        sessionNotificationId(
          sessionId: 'session-1',
          provider: 'codex',
          eventType: SessionNotificationEvent.approval,
        ),
        isNot(first),
      );
      expect(
        sessionNotificationId(
          sessionId: 'session-1',
          provider: 'claude',
          eventType: SessionNotificationEvent.complete,
        ),
        isNot(first),
      );
    });
  });

  test('queues a cold-launch tap until routing is ready, exactly once', () {
    final dispatcher = NotificationTapDispatcher();
    final received = <String?>[];

    dispatcher.dispatch('cold-session');
    expect(received, isEmpty);

    dispatcher.handler = received.add;
    expect(received, ['cold-session']);

    dispatcher.handler = received.add;
    expect(received, ['cold-session']);
  });

  test('privacy copy hides the standard notification body', () {
    final l = AppLocalizationsEn();

    expect(
      localNotificationBody(
        standardBody: 'sensitive tool summary',
        privacyMode: true,
        l: l,
      ),
      l.notificationPrivateBody,
    );
    expect(
      localNotificationBody(
        standardBody: 'safe summary',
        privacyMode: false,
        l: l,
      ),
      'safe summary',
    );
  });
}
