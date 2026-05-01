import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Fetches the latest published Bridge package version from npm.
class BridgeLatestVersionService {
  static final latestPackageUri = Uri.parse(
    'https://registry.npmjs.org/@ccpocket%2Fbridge/latest',
  );
  static const cacheDuration = Duration(minutes: 15);
  static const requestTimeout = Duration(seconds: 5);

  BridgeLatestVersionService({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client(),
      _ownsClient = httpClient == null;

  final http.Client _httpClient;
  final bool _ownsClient;
  String? _cachedVersion;
  DateTime? _cachedAt;

  Future<String> fetchLatestVersion({bool forceRefresh = false}) async {
    final cachedVersion = _cachedVersion;
    final cachedAt = _cachedAt;
    if (!forceRefresh &&
        cachedVersion != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < cacheDuration) {
      return cachedVersion;
    }

    final response = await _httpClient
        .get(latestPackageUri)
        .timeout(requestTimeout);
    if (response.statusCode != 200) {
      throw StateError('npm registry returned HTTP ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final version = body['version'] as String?;
    if (version == null || version.trim().isEmpty) {
      throw const FormatException('npm registry response has no version');
    }

    _cachedVersion = version.trim();
    _cachedAt = DateTime.now();
    return _cachedVersion!;
  }

  void dispose() {
    if (_ownsClient) {
      _httpClient.close();
    }
  }
}
