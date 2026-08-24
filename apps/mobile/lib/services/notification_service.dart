import 'dart:convert';

import 'package:flutter/foundation.dart' show ChangeNotifier, kIsWeb;
import 'package:flutter/scheduler.dart' show SchedulerBinding, SchedulerPhase;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/logger.dart';
import '../l10n/app_localizations.dart';
import '../models/messages.dart';

bool shouldUseLocalNotificationFallback({
  required bool isBackground,
  required bool localNotificationsAllowed,
  required bool remoteNotificationsReady,
}) => isBackground && localNotificationsAllowed && !remoteNotificationsReady;

class SessionNotificationEvent {
  static const approval = 'approval_required';
  static const question = 'ask_user_question';
  static const complete = 'session_completed';
}

class NotificationSessionTarget {
  const NotificationSessionTarget({
    required this.sessionId,
    required this.provider,
  });

  final String sessionId;
  final String provider;
}

String sessionNotificationPayload({
  required String sessionId,
  required String provider,
}) => jsonEncode({
  'sessionId': sessionId,
  'provider': provider == 'codex' ? 'codex' : 'claude',
});

NotificationSessionTarget? parseSessionNotificationPayload(String? payload) {
  if (payload == null || payload.isEmpty) return null;
  try {
    final decoded = jsonDecode(payload);
    if (decoded is Map<String, dynamic>) {
      final sessionId = decoded['sessionId']?.toString();
      if (sessionId == null || sessionId.isEmpty) return null;
      return NotificationSessionTarget(
        sessionId: sessionId,
        provider: decoded['provider'] == 'codex' ? 'codex' : 'claude',
      );
    }
  } catch (_) {
    // Legacy notifications stored the Claude session ID as plain text.
  }
  return NotificationSessionTarget(sessionId: payload, provider: 'claude');
}

int sessionNotificationId({
  required String sessionId,
  required String provider,
  required String eventType,
}) {
  final raw = '$provider:$sessionId:$eventType';
  var hash = 0;
  for (final code in raw.codeUnits) {
    hash = ((hash * 31) + code) & 0x7fffffff;
  }
  return hash;
}

String localNotificationBody({
  required String standardBody,
  required bool privacyMode,
  required AppLocalizations l,
}) => privacyMode ? l.notificationPrivateBody : standardBody;

class NotificationTapDispatcher {
  final List<String> _pendingPayloads = [];
  void Function(String? payload)? _handler;

  set handler(void Function(String? payload)? value) {
    _handler = value;
    if (value == null || _pendingPayloads.isEmpty) return;
    final pending = List<String>.from(_pendingPayloads);
    _pendingPayloads.clear();
    for (final payload in pending) {
      value(payload);
    }
  }

  void dispatch(String? payload) {
    if (payload == null || payload.isEmpty) return;
    final handler = _handler;
    if (handler == null) {
      _pendingPayloads.add(payload);
      return;
    }
    handler(payload);
  }
}

class NotificationService extends ChangeNotifier {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _activeSessionId;
  String? _activeProvider;
  bool _notifyScheduled = false;
  final NotificationTapDispatcher _tapDispatcher = NotificationTapDispatcher();

  String? get activeSessionId => _activeSessionId;
  String? get activeProvider => _activeProvider;

  /// Called when the user taps a notification. A cold-launch tap is retained
  /// until the app router installs this callback.
  set onNotificationTap(void Function(String? payload)? callback) {
    _tapDispatcher.handler = callback;
  }

  Future<void> init() async {
    if (kIsWeb) return;
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('ic_notification');
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
    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open CC Pocket',
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: macosSettings,
      linux: linuxSettings,
    );

    final initialized = await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
    if (initialized == false) return;

    try {
      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp == true) {
        _tapDispatcher.dispatch(launchDetails?.notificationResponse?.payload);
      }
    } catch (error, stackTrace) {
      logger.warning(
        '[notifications] failed to read launch notification',
        error,
        stackTrace,
      );
    }

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
          'CC Pocket sessions',
          description: 'Session updates from CC Pocket',
          importance: Importance.high,
        ),
      );
    }

    _initialized = true;
  }

  void _onNotificationResponse(NotificationResponse response) {
    _tapDispatcher.dispatch(response.payload);
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
      'CC Pocket sessions',
      channelDescription: 'Session updates from CC Pocket',
      icon: 'ic_notification',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const macosDetails = DarwinNotificationDetails();
    const linuxDetails = LinuxNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: macosDetails,
      linux: linuxDetails,
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
    required AppLocalizations l,
    required bool privacyMode,
    int id = 1,
    String? payload,
  }) {
    final copy = ApprovalNotificationCopy.from(permission, l: l);
    return show(
      title: copy.title,
      body: localNotificationBody(
        standardBody: copy.body,
        privacyMode: privacyMode,
        l: l,
      ),
      id: id,
      payload: payload,
    );
  }

  Future<void> showSessionCompleteNotification({
    required AppLocalizations l,
    required bool privacyMode,
    int id = 3,
    String? payload,
  }) {
    return show(
      title: l.sessionCompleteNotificationTitle,
      body: localNotificationBody(
        standardBody: l.sessionCompleteNotificationBody,
        privacyMode: privacyMode,
        l: l,
      ),
      id: id,
      payload: payload,
    );
  }
}

class ApprovalNotificationCopy {
  final String title;
  final String body;

  const ApprovalNotificationCopy({required this.title, required this.body});

  factory ApprovalNotificationCopy.from(
    PermissionRequestMessage message, {
    required AppLocalizations l,
  }) {
    if (message.usesAskUserUi) {
      return ApprovalNotificationCopy(
        title: l.approvalQuestionNotificationTitle,
        body: message.summary,
      );
    }
    if (message.toolName == 'ExitPlanMode') {
      return ApprovalNotificationCopy(
        title: l.approvalRequiredNotificationTitle,
        body: l.exitPlanModeNotificationBody,
      );
    }

    final presentation = message.presentation;
    return ApprovalNotificationCopy(
      title: l.approvalRequiredNotificationTitle,
      body: presentation.summary,
    );
  }
}
