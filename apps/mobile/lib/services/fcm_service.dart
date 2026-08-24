import 'package:firebase_app_installations/firebase_app_installations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../core/logger.dart';

class FcmService {
  FcmService();

  static const _tokenRetryDelays = <Duration>[
    Duration.zero,
    Duration(milliseconds: 350),
    Duration(seconds: 1),
  ];

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
      final token = (await initializeMessaging())?.trim();
      if (token == null || token.isEmpty) {
        logger.warning('[fcm] registration returned no token');
        _cachedToken = null;
        _available = false;
        return false;
      }
      _cachedToken = token;
      _available = true;
      return true;
    } catch (e, st) {
      logger.error('[fcm] init failed', e, st);
      _cachedToken = null;
      _available = false;
      return false;
    }
  }

  @visibleForTesting
  @protected
  Future<String?> initializeMessaging() async {
    await prepareMessaging();
    return _requestTokenWithRecovery();
  }

  @visibleForTesting
  @protected
  Future<void> prepareMessaging() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    await _instance.requestPermission(alert: true, badge: true, sound: true);
    await _instance.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: true,
    );
  }

  @visibleForTesting
  @protected
  Future<String?> requestToken() => _instance.getToken();

  @visibleForTesting
  @protected
  Future<void> waitBeforeTokenRetry(Duration delay) => Future.delayed(delay);

  @visibleForTesting
  @protected
  Future<void> repairInvalidInstallation() async {
    try {
      await _instance.deleteToken();
    } catch (e, st) {
      logger.warning('[fcm] failed to clear stale messaging token', e, st);
    }
    await FirebaseInstallations.instance.delete();
  }

  Future<String?> _requestTokenWithRecovery() async {
    var repairedInstallation = false;

    for (var attempt = 0; attempt < _tokenRetryDelays.length; attempt++) {
      final delay = _tokenRetryDelays[attempt];
      if (delay > Duration.zero) {
        await waitBeforeTokenRetry(delay);
      }

      try {
        final token = (await requestToken())?.trim();
        if (token != null && token.isNotEmpty) return token;
        if (attempt < _tokenRetryDelays.length - 1) {
          logger.warning(
            '[fcm] registration returned no token; retrying '
            '(${attempt + 1}/${_tokenRetryDelays.length})',
          );
        }
      } catch (e, st) {
        if (!repairedInstallation &&
            platform == 'android' &&
            _isInvalidInstallationError(e)) {
          repairedInstallation = true;
          try {
            await repairInvalidInstallation();
            logger.info('[fcm] repaired invalid Firebase installation');
          } catch (repairError, repairStack) {
            logger.warning(
              '[fcm] failed to repair invalid Firebase installation',
              repairError,
              repairStack,
            );
          }
        }

        if (attempt == _tokenRetryDelays.length - 1) {
          Error.throwWithStackTrace(e, st);
        }
        logger.warning(
          '[fcm] registration failed; retrying '
          '(${attempt + 1}/${_tokenRetryDelays.length})',
          e,
          st,
        );
      }
    }
    return null;
  }

  bool _isInvalidInstallationError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('fid_already_used') ||
        message.contains('fid already used') ||
        message.contains('invalid argument for the given fid') ||
        message.contains('invalid argument for given fid');
  }

  Future<String?> getToken() async {
    final cachedToken = _cachedToken;
    if (_available && cachedToken != null && cachedToken.isNotEmpty) {
      return cachedToken;
    }
    final ready = await init();
    return ready ? _cachedToken : null;
  }

  String? cacheToken(String token) {
    final previous = _cachedToken;
    _cachedToken = token;
    return previous;
  }
}
