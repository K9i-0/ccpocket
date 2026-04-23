import 'dart:convert';

import 'package:ccpocket/services/app_update_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppUpdateService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    test('prefers native updater results when available', () async {
      final service = AppUpdateService.test(
        gateway: _FakeAppUpdateGateway(
          probeResult: {
            'latestVersion': '1.44.0',
            'currentVersion': '1.42.0',
            'downloadUrl': 'https://example.com/cc-pocket.zip',
            'releaseUrl': 'https://example.com/release-notes',
          },
        ),
        packageInfoLoader: () async => _packageInfo(version: '1.42.0'),
      );

      final update = await service.checkForUpdate(force: true);

      expect(update, isNotNull);
      expect(update!.latestVersion, '1.44.0');
      expect(update.canInstallInApp, isTrue);
    });

    test(
      'uses release asset URL for macOS updates with build metadata fallback',
      () async {
        final client = MockClient((request) async {
          expect(
            request.url.toString(),
            'https://api.github.com/repos/K9i-0/ccpocket/releases?per_page=20',
          );

          return http.Response(jsonEncode(_mockReleases), 200);
        });

        final service = AppUpdateService.test(
          httpClient: client,
          gateway: const _FakeAppUpdateGateway(),
          packageInfoLoader: () async => _packageInfo(version: '1.42.0'),
        );

        final update = await service.checkForUpdate(force: true);

        expect(update, isNotNull);
        expect(update!.latestVersion, '1.44.0');
        expect(update.canInstallInApp, isFalse);
        expect(
          update.downloadUrl,
          'https://github.com/K9i-0/ccpocket/releases/download/macos/v1.44.0%2B74/CC-Pocket-macos-v1.44.0.dmg',
        );
        expect(
          update.releaseUrl,
          'https://github.com/K9i-0/ccpocket/releases/tag/macos/v1.44.0%2B74',
        );
      },
    );

    test('ignores macOS releases without the expected DMG asset', () async {
      final client = MockClient((_) async {
        final releases = [
          {
            'tag_name': 'macos/v1.45.0+75',
            'html_url':
                'https://github.com/K9i-0/ccpocket/releases/tag/macos/v1.45.0%2B75',
            'assets': [
              {
                'name': 'wrong-name.dmg',
                'browser_download_url': 'https://example.com/wrong-name.dmg',
              },
            ],
          },
          _mockReleases[0],
        ];
        return http.Response(jsonEncode(releases), 200);
      });

      final service = AppUpdateService.test(
        httpClient: client,
        gateway: const _FakeAppUpdateGateway(),
        packageInfoLoader: () async => _packageInfo(version: '1.42.0'),
      );

      final update = await service.checkForUpdate(force: true);

      expect(update, isNotNull);
      expect(update!.latestVersion, '1.44.0');
    });
  });
}

class _FakeAppUpdateGateway implements AppUpdateGateway {
  const _FakeAppUpdateGateway({this.probeResult});

  final Map<String, dynamic>? probeResult;

  @override
  Future<void> performUpdate() async {}

  @override
  Future<Map<String, dynamic>?> probeForUpdate() async => probeResult;
}

PackageInfo _packageInfo({required String version}) {
  return PackageInfo(
    appName: 'CC Pocket',
    packageName: 'dev.test.ccpocket',
    version: version,
    buildNumber: '72',
    buildSignature: '',
    installerStore: null,
  );
}

final _mockReleases = [
  {
    'tag_name': 'macos/v1.44.0+74',
    'html_url':
        'https://github.com/K9i-0/ccpocket/releases/tag/macos/v1.44.0%2B74',
    'assets': [
      {
        'name': 'CC-Pocket-macos-v1.44.0.dmg',
        'browser_download_url':
            'https://github.com/K9i-0/ccpocket/releases/download/macos/v1.44.0%2B74/CC-Pocket-macos-v1.44.0.dmg',
      },
    ],
  },
  {
    'tag_name': 'ios/v1.44.0+74',
    'html_url':
        'https://github.com/K9i-0/ccpocket/releases/tag/ios/v1.44.0%2B74',
    'assets': const [],
  },
  {
    'tag_name': 'macos/v1.43.0+73',
    'html_url':
        'https://github.com/K9i-0/ccpocket/releases/tag/macos/v1.43.0%2B73',
    'assets': [
      {
        'name': 'CC-Pocket-macos-v1.43.0.dmg',
        'browser_download_url':
            'https://github.com/K9i-0/ccpocket/releases/download/macos/v1.43.0%2B73/CC-Pocket-macos-v1.43.0.dmg',
      },
    ],
  },
];
