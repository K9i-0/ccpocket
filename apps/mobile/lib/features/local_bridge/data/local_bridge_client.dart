import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'local_bridge_models.dart';

/// Why a request to the Bridge on this machine failed.
enum LocalBridgeFailure {
  /// Nothing answers on the port.
  notRunning,

  /// `~/.ccpocket/pairing-secret-<port>` cannot be read: the Bridge runs as
  /// another user, is too old to write it, or the app may not read the file.
  secretUnavailable,

  /// The Bridge rejected the pairing secret (it restarted meanwhile).
  forbidden,

  /// The Bridge is too old to have this endpoint.
  unsupported,

  /// The Bridge rejected the settings; see [LocalBridgeException.errors].
  invalidSettings,

  /// Restart refused: nothing would start the Bridge again.
  notSupervised,

  /// The action does not apply (for example replacing a key set by env).
  conflict,
  other,
}

class LocalBridgeException implements Exception {
  const LocalBridgeException(
    this.failure, {
    this.detail,
    this.errors = const {},
  });

  final LocalBridgeFailure failure;
  final String? detail;

  /// Setting key -> problem, for [LocalBridgeFailure.invalidSettings].
  final Map<String, String> errors;

  @override
  String toString() =>
      'LocalBridgeException(${failure.name}${detail == null ? '' : ': $detail'})';
}

/// The user's home directory. In the sandboxed macOS app `HOME` points into
/// the app container, which is not where the Bridge keeps `~/.ccpocket`.
String realHomeDirectory([Map<String, String>? environment]) {
  final home = (environment ?? Platform.environment)['HOME'] ?? '';
  final container = home.indexOf('/Library/Containers/');
  return container > 0 ? home.substring(0, container) : home;
}

typedef PairingSecretReader = Future<String?> Function(int port);

Future<String?> readPairingSecretFile(int port) async {
  try {
    final file = File('${realHomeDirectory()}/.ccpocket/pairing-secret-$port');
    final secret = (await file.readAsString()).trim();
    return secret.isEmpty ? null : secret;
  } on FileSystemException {
    return null;
  }
}

/// Client for the Bridge running on this machine.
///
/// Management calls authenticate with the per-start pairing secret that only
/// the Bridge's OS user can read; they never use the API key.
class LocalBridgeClient {
  LocalBridgeClient({
    required this.port,
    http.Client? httpClient,
    PairingSecretReader? readPairingSecret,
    this.timeout = const Duration(seconds: 8),
  }) : _http = httpClient ?? http.Client(),
       _readSecret = readPairingSecret ?? readPairingSecretFile;

  static const pairingSecretHeader = 'x-ccpocket-pairing-secret';

  final int port;
  final Duration timeout;
  final http.Client _http;
  final PairingSecretReader _readSecret;

  Uri _uri(String path, [Map<String, String>? query]) => Uri(
    scheme: 'http',
    host: '127.0.0.1',
    port: port,
    path: path,
    queryParameters: query,
  );

  /// Whether a Bridge answers on the port (no credentials sent).
  Future<bool> isRunning() async {
    try {
      final response = await _http.get(_uri('/health')).timeout(timeout);
      return response.statusCode == 200;
    } on Exception {
      return false;
    }
  }

  Future<LocalBridgeStatus> status() async =>
      LocalBridgeStatus.fromJson(await _admin('GET', '/admin/status'));

  Future<LocalBridgeConfig> config() async =>
      LocalBridgeConfig.fromJson(await _admin('GET', '/admin/config'));

  /// Save [settings]; a null value removes the setting from the file.
  Future<LocalBridgeConfig> saveSettings(Map<String, Object?> settings) async =>
      LocalBridgeConfig.fromJson(
        await _admin('PUT', '/admin/config', body: {'settings': settings}),
      );

  Future<void> restart() => _admin('POST', '/admin/restart');

  Future<void> rotateApiKey() => _admin('POST', '/admin/api-key/rotate');

  Future<List<LocalBridgeLogEntry>> logs({int limit = 500}) async {
    final json = await _admin('GET', '/admin/logs', query: {'limit': '$limit'});
    final entries = json['entries'];
    return [
      if (entries is List)
        for (final entry in entries)
          if (entry is Map)
            LocalBridgeLogEntry.fromJson(entry.cast<String, Object?>()),
    ];
  }

  Future<LocalBridgePairing> pairing() async =>
      LocalBridgePairing.fromJson(await _admin('GET', '/pairing'));

  /// Tools report; needs the API key from [pairing] unless auth is off.
  ///
  /// The Bridge caches the report briefly; [refresh] forces new checks.
  Future<LocalBridgeTools> tools({String? apiKey, bool refresh = false}) async {
    final http.Response response;
    try {
      response = await _http
          .get(
            _uri('/tools', refresh ? const {'refresh': '1'} : null),
            headers: {if (apiKey != null) 'Authorization': 'Bearer $apiKey'},
          )
          // Version and sign-in checks run several CLIs.
          .timeout(const Duration(seconds: 40));
    } on Exception catch (err) {
      throw LocalBridgeException(LocalBridgeFailure.notRunning, detail: '$err');
    }
    return LocalBridgeTools.fromJson(_decode(response));
  }

  Future<Map<String, Object?>> _admin(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    final secret = await _readSecret(port);
    if (secret == null) {
      // Tell "no Bridge" apart from "a Bridge we cannot manage".
      throw LocalBridgeException(
        await isRunning()
            ? LocalBridgeFailure.secretUnavailable
            : LocalBridgeFailure.notRunning,
      );
    }
    final request = http.Request(method, _uri(path, query))
      ..headers[pairingSecretHeader] = secret;
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _http.send(request).timeout(timeout),
      ).timeout(timeout);
    } on Exception catch (err) {
      throw LocalBridgeException(LocalBridgeFailure.notRunning, detail: '$err');
    }
    return _decode(response);
  }

  Map<String, Object?> _decode(http.Response response) {
    Map<String, Object?> json = const {};
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map) json = decoded.cast<String, Object?>();
    } on FormatException {
      // Plain-text bodies ("Forbidden", "Not Found") carry no detail.
    }
    final status = response.statusCode;
    if (status >= 200 && status < 300) return json;

    final error = json['error'];
    final detail = error is String ? error : null;
    throw switch (status) {
      400 when detail == 'invalid_settings' => LocalBridgeException(
        LocalBridgeFailure.invalidSettings,
        errors: {
          if (json['errors'] case final Map errors)
            for (final entry in errors.entries)
              '${entry.key}': '${entry.value}',
        },
      ),
      401 ||
      403 => LocalBridgeException(LocalBridgeFailure.forbidden, detail: detail),
      404 => const LocalBridgeException(LocalBridgeFailure.unsupported),
      409 when detail == 'not_supervised' => const LocalBridgeException(
        LocalBridgeFailure.notSupervised,
      ),
      409 => LocalBridgeException(LocalBridgeFailure.conflict, detail: detail),
      _ => LocalBridgeException(
        LocalBridgeFailure.other,
        detail: detail ?? 'HTTP $status',
      ),
    };
  }

  void close() => _http.close();
}
