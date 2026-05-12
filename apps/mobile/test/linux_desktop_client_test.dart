import 'package:ccpocket/screens/qr_scan_screen.dart';
import 'package:ccpocket/services/fcm_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('FcmService stays unavailable on Linux desktop', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;

    final service = FcmService();

    expect(service.isSupportedPlatform, isFalse);
    expect(await service.init(), isFalse);
    expect(service.isAvailable, isFalse);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('QrScanScreen shows manual URL fallback on desktop', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;

    await tester.pumpWidget(const MaterialApp(home: QrScanScreen()));

    expect(
      find.textContaining('QR camera scan is not available'),
      findsOneWidget,
    );
    expect(find.textContaining('Bridge URL'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
