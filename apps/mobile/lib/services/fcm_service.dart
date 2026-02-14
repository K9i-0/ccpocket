import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class FcmService {
  FcmService({FirebaseMessaging? messaging}) : _messaging = messaging;

  FirebaseMessaging? _messaging;
  bool _initAttempted = false;
  bool _available = false;
  String? _cachedToken;

  bool get isAvailable => _available;

  FirebaseMessaging get _instance => _messaging ??= FirebaseMessaging.instance;

  Stream<String> get onTokenRefresh => _instance.onTokenRefresh;

  String get platform {
    if (kIsWeb) return 'web';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    return 'web';
  }

  Future<bool> init() async {
    if (_initAttempted) return _available;
    _initAttempted = true;
    if (kIsWeb) {
      _available = false;
      return false;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      await _instance.requestPermission(alert: true, badge: true, sound: true);
      await _instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
      _cachedToken = await _instance.getToken();
      _available = true;
      return true;
    } catch (e, st) {
      debugPrint('[fcm] init failed: $e');
      debugPrint('[fcm] stack: $st');
      _available = false;
      return false;
    }
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
