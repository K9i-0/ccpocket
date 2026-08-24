import 'dart:async';

import 'package:ccpocket/services/fcm_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _ScriptedFcmService extends FcmService {
  _ScriptedFcmService(this.outcomes);

  final List<Object?> outcomes;
  var attempts = 0;
  var repairAttempts = 0;
  var preparationAttempts = 0;

  @override
  bool get isSupportedPlatform => true;

  @override
  String get platform => 'android';

  @override
  Future<void> prepareMessaging() async {
    preparationAttempts++;
  }

  @override
  Future<String?> requestToken() async {
    final outcome = outcomes[attempts++];
    if (outcome is Error) throw outcome;
    if (outcome is Exception) throw outcome;
    return outcome as String?;
  }

  @override
  Future<void> waitBeforeTokenRetry(Duration delay) async {}

  @override
  Future<void> repairInvalidInstallation() async {
    repairAttempts++;
  }
}

void main() {
  test('retries a transient registration exception in one init', () async {
    final service = _ScriptedFcmService([
      StateError('temporary FCM registration failure'),
      'recovered-token',
    ]);

    expect(await service.init(), isTrue);
    expect(service.isAvailable, isTrue);
    expect(await service.getToken(), 'recovered-token');
    expect(service.attempts, 2);
    expect(service.preparationAttempts, 1);
    expect(service.repairAttempts, 0);
  });

  test(
    'retries a null token and only marks FCM available with a token',
    () async {
      final service = _ScriptedFcmService([null, 'token-after-null']);

      expect(await service.init(), isTrue);
      expect(service.isAvailable, isTrue);
      expect(await service.getToken(), 'token-after-null');
      expect(service.attempts, 2);
    },
  );

  test('remains retryable after all registration attempts fail', () async {
    final service = _ScriptedFcmService([
      StateError('failure 1'),
      StateError('failure 2'),
      StateError('failure 3'),
      'later-token',
    ]);

    expect(await service.init(), isFalse);
    expect(service.isAvailable, isFalse);
    expect(service.attempts, 3);

    expect(await service.init(), isTrue);
    expect(await service.getToken(), 'later-token');
    expect(service.attempts, 4);
    expect(service.preparationAttempts, 2);
  });

  test('does not report availability after repeated null tokens', () async {
    final service = _ScriptedFcmService([null, null, null, 'later-token']);

    expect(await service.init(), isFalse);
    expect(service.isAvailable, isFalse);
    expect(await service.init(), isTrue);
    expect(await service.getToken(), 'later-token');
  });

  test('repairs an explicitly invalid installation before retrying', () async {
    final service = _ScriptedFcmService([
      StateError('Invalid argument for the given fid'),
      'repaired-token',
    ]);

    expect(await service.init(), isTrue);
    expect(await service.getToken(), 'repaired-token');
    expect(service.repairAttempts, 1);
    expect(service.attempts, 2);
  });

  test('does not rotate installation identity for a generic failure', () async {
    final service = _ScriptedFcmService([
      StateError('FCM Registration failed!'),
      'recovered-token',
    ]);

    expect(await service.init(), isTrue);
    expect(service.repairAttempts, 0);
  });

  test('coalesces concurrent initialization attempts', () async {
    final token = Completer<String?>();
    final service = _BlockingFcmService(token.future);

    final first = service.init();
    final second = service.init();
    await Future<void>.delayed(Duration.zero);
    expect(service.attempts, 1);

    token.complete('shared-token');
    expect(await first, isTrue);
    expect(await second, isTrue);
    expect(service.attempts, 1);
  });
}

class _BlockingFcmService extends FcmService {
  _BlockingFcmService(this.token);

  final Future<String?> token;
  var attempts = 0;

  @override
  bool get isSupportedPlatform => true;

  @override
  Future<void> prepareMessaging() async {}

  @override
  Future<String?> requestToken() {
    attempts++;
    return token;
  }
}
