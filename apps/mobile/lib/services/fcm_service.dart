import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../core/logger.dart';

class FcmService {
  FcmService({FirebaseMessaging? messaging}) : _messaging = messaging;

  FirebaseMessaging? _messaging;
  Future<bool>? _initInProgress;
  bool _available = false;
  String? _cachedToken;

  bool get isAvailable => _available;

  bool get isSupportedPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
  }

  FirebaseMessaging get _instance => _messaging ??= FirebaseMessaging.instance;

  Stream<String> get onTokenRefresh => _instance.onTokenRefresh;

  String get platform {
    if (kIsWeb) return 'web';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    if (defaultTargetPlatform == TargetPlatform.linux) return 'linux';
    if (defaultTargetPlatform == TargetPlatform.macOS) return 'macos';
    if (defaultTargetPlatform == TargetPlatform.windows) return 'windows';
    return 'unknown';
  }

  Future<bool> init() async {
    if (_available) return true;
    if (!isSupportedPlatform) {
      _available = false;
      return false;
    }

    final initInProgress = _initInProgress;
    if (initInProgress != null) return initInProgress;

    final initialization = _initialize();
    _initInProgress = initialization;
    try {
      return await initialization;
    } finally {
      if (identical(_initInProgress, initialization)) {
        _initInProgress = null;
      }
    }
  }

  Future<bool> _initialize() async {
    try {
      _cachedToken = await initializeMessaging();
      _available = true;
      return true;
    } catch (e, st) {
      logger.error('[fcm] init failed', e, st);
      _available = false;
      return false;
    }
  }

  @visibleForTesting
  @protected
  Future<String?> initializeMessaging() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    await _instance.requestPermission(alert: true, badge: true, sound: true);
    await _instance.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: true,
    );
    return _instance.getToken();
  }

  Future<String?> getToken() async {
    if (!_available) {
      final ready = await init();
      if (!ready) return null;
    }
    _cachedToken ??= await _instance.getToken();
    return _cachedToken;
  }

  String? cacheToken(String token) {
    final previous = _cachedToken;
    _cachedToken = token;
    return previous;
  }
}
