import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _activeSessionId;
  String? _activeProvider;

  /// Called when the user taps a notification. The [payload] string
  /// (typically a sessionId) is forwarded.
  void Function(String? payload)? onNotificationTap;

  Future<void> init() async {
    if (kIsWeb) return;
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/launcher_icon',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Create the notification channel eagerly so FCM uses it instead of
    // the low-priority fcm_fallback_notification_channel.
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'ccpocket_channel',
          'ccpocket',
          description: 'Claude Code session notifications',
          importance: Importance.high,
        ),
      );
    }

    _initialized = true;
  }

  void _onNotificationResponse(NotificationResponse response) {
    onNotificationTap?.call(response.payload);
  }

  void setActiveSession({required String sessionId, required String provider}) {
    _activeSessionId = sessionId;
    _activeProvider = provider;
  }

  void clearActiveSession({String? sessionId, String? provider}) {
    if (sessionId != null && _activeSessionId != sessionId) return;
    if (provider != null && _activeProvider != provider) return;
    _activeSessionId = null;
    _activeProvider = null;
  }

  bool isActiveSession({required String sessionId, required String provider}) {
    return _activeSessionId == sessionId && _activeProvider == provider;
  }

  /// Dismiss all previously shown notifications from the notification center.
  Future<void> cancelAll() async {
    if (!_initialized) return;
    await _plugin.cancelAll();
  }

  Future<void> show({
    required String title,
    required String body,
    int id = 0,
    String? payload,
  }) async {
    if (!_initialized) return;

    const androidDetails = AndroidNotificationDetails(
      'ccpocket_channel',
      'ccpocket',
      channelDescription: 'Claude Code session notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }
}
