import 'package:flutter/foundation.dart' show ChangeNotifier, kIsWeb;
import 'package:flutter/scheduler.dart' show SchedulerBinding, SchedulerPhase;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/messages.dart';

class NotificationService extends ChangeNotifier {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _activeSessionId;
  String? _activeProvider;
  bool _notifyScheduled = false;

  String? get activeSessionId => _activeSessionId;
  String? get activeProvider => _activeProvider;

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
    const macosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: macosSettings,
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
    if (_activeSessionId == sessionId && _activeProvider == provider) return;
    _activeSessionId = sessionId;
    _activeProvider = provider;
    _notifyListenersSafely();
  }

  void clearActiveSession({String? sessionId, String? provider}) {
    if (sessionId != null && _activeSessionId != sessionId) return;
    if (provider != null && _activeProvider != provider) return;
    if (_activeSessionId == null && _activeProvider == null) return;
    _activeSessionId = null;
    _activeProvider = null;
    _notifyListenersSafely();
  }

  void _notifyListenersSafely() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    final canNotifyNow =
        phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks;
    if (canNotifyNow) {
      notifyListeners();
      return;
    }
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      notifyListeners();
    });
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
    const macosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: macosDetails,
    );

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  Future<void> showApprovalNotification(
    PermissionRequestMessage permission, {
    int id = 1,
    String? payload,
  }) {
    final copy = permission.notificationCopy;
    return show(title: copy.title, body: copy.body, id: id, payload: payload);
  }

  Future<void> showSessionCompleteNotification({
    required String body,
    int id = 3,
    String? payload,
  }) {
    return show(
      title: 'Session Complete',
      body: body,
      id: id,
      payload: payload,
    );
  }
}
