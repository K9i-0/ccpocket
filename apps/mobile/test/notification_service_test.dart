import 'package:ccpocket/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('local notification fallback', () {
    test('stays silent while the app is foregrounded', () {
      expect(
        shouldUseLocalNotificationFallback(
          isBackground: false,
          remoteNotificationsEnabled: false,
        ),
        isFalse,
      );
    });

    test('notifies in the background when remote push is unavailable', () {
      expect(
        shouldUseLocalNotificationFallback(
          isBackground: true,
          remoteNotificationsEnabled: false,
        ),
        isTrue,
      );
    });

    test('defers to remote push in the background when enabled', () {
      expect(
        shouldUseLocalNotificationFallback(
          isBackground: true,
          remoteNotificationsEnabled: true,
        ),
        isFalse,
      );
    });
  });
}
