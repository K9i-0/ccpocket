import 'dart:async';

import 'package:ccpocket/services/fcm_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _ScriptedFcmService extends FcmService {
  _ScriptedFcmService(this.outcomes);

  final List<Object?> outcomes;
  var attempts = 0;

  @override
  bool get isSupportedPlatform => true;

  @override
  Future<String?> initializeMessaging() async {
    final outcome = outcomes[attempts++];
    if (outcome is Error) throw outcome;
    if (outcome is Exception) throw outcome;
    return outcome as String?;
  }
}

class _BlockingFcmService extends FcmService {
  _BlockingFcmService(this.token);

  final Future<String?> token;
  var attempts = 0;

  @override
  bool get isSupportedPlatform => true;

  @override
  Future<String?> initializeMessaging() {
    attempts++;
    return token;
  }
}

void main() {
  group('FcmService initialization', () {
    test('can retry after a transient token failure', () async {
      final service = _ScriptedFcmService([
        StateError('temporary token failure'),
        'recovered-token',
      ]);

      expect(await service.init(), isFalse);
      expect(service.isAvailable, isFalse);

      expect(await service.init(), isTrue);
      expect(service.isAvailable, isTrue);
      expect(await service.getToken(), 'recovered-token');
      expect(service.attempts, 2);
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

    test('does not become available without a usable token', () async {
      final service = _ScriptedFcmService([null, '   ', 'usable-token']);

      expect(await service.init(), isFalse);
      expect(service.isAvailable, isFalse);
      expect(await service.init(), isFalse);
      expect(service.isAvailable, isFalse);
      expect(await service.init(), isTrue);
      expect(await service.getToken(), 'usable-token');
      expect(service.attempts, 3);
    });
  });
}
