import 'package:ccpocket/services/fcm_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _RetryableFcmService extends FcmService {
  var attempts = 0;

  @override
  bool get isSupportedPlatform => true;

  @override
  Future<String?> initializeMessaging() async {
    attempts++;
    if (attempts == 1) {
      throw StateError('temporary FCM registration failure');
    }
    return 'recovered-token';
  }
}

void main() {
  test(
    'initialization can retry after a transient registration failure',
    () async {
      final service = _RetryableFcmService();

      expect(await service.init(), isFalse);
      expect(service.isAvailable, isFalse);

      expect(await service.init(), isTrue);
      expect(service.isAvailable, isTrue);
      expect(await service.getToken(), 'recovered-token');
      expect(service.attempts, 2);
    },
  );
}
